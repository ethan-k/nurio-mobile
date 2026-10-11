package com.nurio.study.android.aitutor

import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicInteger

enum class AiTutorCallStatus {
    PROVISIONING,
    CONNECTING,
    TUTOR_JOINING,
    LIVE,
    RECONNECTING,
    FAILED,
    ENDING,
    ENDED;

    val isConnected: Boolean
        get() = this == TUTOR_JOINING || this == LIVE || this == RECONNECTING
}

data class AiTutorCallSnapshot(
    val status: AiTutorCallStatus,
    val topic: String,
    val deadlineAtMillis: Long?,
    val muted: Boolean
)

/** Media side of a call. Implementations deliver every callback on the engine's main executor. */
interface AiTutorRoom {
    /** Connects, publishes the microphone, then calls [completion] with null or the failure. */
    fun connect(url: String, token: String, events: AiTutorRoomEvents, completion: (Throwable?) -> Unit)
    fun setMicrophoneEnabled(enabled: Boolean)
    fun refreshAudioRouting()
    fun disconnect()
}

interface AiTutorRoomEvents {
    fun onTutorPresent()
    fun onReconnecting()
    fun onReconnected()
    fun onDisconnected()
}

/**
 * Owns one class-review call independent of any view: join polling, room lifecycle, mute,
 * deadline, and ending. Not thread-safe — call it (and deliver room events) on the main executor.
 */
class AiTutorCallEngine(
    private val api: AiTutorCallApi,
    private val roomFactory: () -> AiTutorRoom,
    private val backgroundExecutor: Executor,
    private val mainExecutor: Executor,
    private val clock: () -> Long = System::currentTimeMillis
) {
    interface Listener {
        fun onSnapshot(snapshot: AiTutorCallSnapshot)
        fun onFinished(reviewUrl: String)
    }

    var listener: Listener? = null

    private val attempt = AtomicInteger(0)
    private var request: AiTutorCallRequest? = null
    private var room: AiTutorRoom? = null
    private var status = AiTutorCallStatus.ENDED
    private var deadlineAtMillis: Long? = null
    private var muted = false
    private var tutorPresent = false

    /** True from [start] until the end request has completed. */
    val isActive: Boolean
        get() = request != null && status != AiTutorCallStatus.ENDED

    val snapshot: AiTutorCallSnapshot
        get() = AiTutorCallSnapshot(status, request?.topic.orEmpty(), deadlineAtMillis, muted)

    /** Starts a call. Returns false (and does nothing) while another call is active. */
    fun start(request: AiTutorCallRequest): Boolean {
        if (isActive) return false

        reset(request)
        join()
        return true
    }

    /** Ends a session that never connected (e.g. microphone denied). */
    fun endWithoutCall(request: AiTutorCallRequest): Boolean {
        if (isActive) return false

        reset(request)
        end()
        return true
    }

    fun retry() {
        if (status != AiTutorCallStatus.FAILED) return
        join()
    }

    fun toggleMute() {
        val activeRoom = room ?: return
        if (!status.isConnected) return

        muted = !muted
        activeRoom.setMicrophoneEnabled(!muted)
        publish()
    }

    fun refreshAudioRouting() {
        room?.refreshAudioRouting()
    }

    /** Ends once the server deadline has passed. Call it periodically while active. */
    fun tick() {
        val deadline = deadlineAtMillis ?: return
        if (!isActive || status == AiTutorCallStatus.ENDING) return
        if (clock() >= deadline) end()
    }

    fun end() {
        val currentRequest = request ?: return
        if (status == AiTutorCallStatus.ENDING || status == AiTutorCallStatus.ENDED) return

        attempt.incrementAndGet()
        status = AiTutorCallStatus.ENDING
        publish()
        closeRoom()

        backgroundExecutor.execute {
            val reviewUrl = api.end(currentRequest)
            mainExecutor.execute { finish(currentRequest, reviewUrl) }
        }
    }

    private fun reset(request: AiTutorCallRequest) {
        this.request = request
        status = AiTutorCallStatus.PROVISIONING
        deadlineAtMillis = null
        muted = false
        tutorPresent = false
        room = null
    }

    private fun join() {
        val currentRequest = request ?: return
        val joinAttempt = attempt.incrementAndGet()
        status = AiTutorCallStatus.PROVISIONING
        publish()

        backgroundExecutor.execute {
            val outcome = runCatching {
                api.join(
                    request = currentRequest,
                    isCancelled = { attempt.get() != joinAttempt },
                    onDeadline = { deadline ->
                        mainExecutor.execute {
                            if (attempt.get() == joinAttempt) {
                                deadlineAtMillis = deadline
                                publish()
                            }
                        }
                    }
                )
            }
            mainExecutor.execute {
                if (attempt.get() == joinAttempt) onJoinResult(currentRequest, outcome)
            }
        }
    }

    private fun onJoinResult(currentRequest: AiTutorCallRequest, outcome: Result<AiTutorJoinOutcome>) {
        when (val joined = outcome.getOrNull()) {
            is AiTutorJoinOutcome.Ended -> finish(currentRequest, joined.reviewUrl)
            is AiTutorJoinOutcome.Ready -> connectRoom(joined)
            null -> {
                status = AiTutorCallStatus.FAILED
                publish()
            }
        }
    }

    private fun connectRoom(joined: AiTutorJoinOutcome.Ready) {
        joined.deadlineAtMillis?.let { deadlineAtMillis = it }
        status = AiTutorCallStatus.CONNECTING
        publish()

        val newRoom = roomFactory()
        room = newRoom
        newRoom.connect(joined.livekitUrl, joined.participantToken, RoomEvents(newRoom)) { error ->
            if (room !== newRoom) return@connect
            if (error != null) {
                end()
            } else {
                status = connectedStatus()
                publish()
            }
        }
    }

    private fun connectedStatus(): AiTutorCallStatus =
        if (tutorPresent) AiTutorCallStatus.LIVE else AiTutorCallStatus.TUTOR_JOINING

    private fun closeRoom() {
        val closingRoom = room ?: return
        room = null
        closingRoom.setMicrophoneEnabled(false)
        closingRoom.disconnect()
    }

    private fun finish(finishedRequest: AiTutorCallRequest, reviewUrl: String) {
        if (request !== finishedRequest || status == AiTutorCallStatus.ENDED) return

        attempt.incrementAndGet()
        closeRoom()
        status = AiTutorCallStatus.ENDED
        publish()
        listener?.onFinished(reviewUrl)
    }

    private fun publish() {
        listener?.onSnapshot(snapshot)
    }

    private inner class RoomEvents(private val owner: AiTutorRoom) : AiTutorRoomEvents {
        override fun onTutorPresent() {
            if (room !== owner) return
            tutorPresent = true
            if (status == AiTutorCallStatus.TUTOR_JOINING) {
                status = AiTutorCallStatus.LIVE
                publish()
            }
        }

        override fun onReconnecting() {
            if (room !== owner || !status.isConnected) return
            status = AiTutorCallStatus.RECONNECTING
            publish()
        }

        override fun onReconnected() {
            if (room !== owner || status != AiTutorCallStatus.RECONNECTING) return
            status = connectedStatus()
            publish()
        }

        override fun onDisconnected() {
            if (room !== owner) return
            end()
        }
    }
}
