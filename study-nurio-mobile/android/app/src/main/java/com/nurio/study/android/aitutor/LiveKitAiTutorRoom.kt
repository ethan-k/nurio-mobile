package com.nurio.study.android.aitutor

import android.content.Context
import android.media.AudioManager
import android.util.Log
import com.twilio.audioswitch.AudioDevice
import io.livekit.android.AudioOptions
import io.livekit.android.AudioType
import io.livekit.android.LiveKit
import io.livekit.android.LiveKitOverrides
import io.livekit.android.RoomOptions
import io.livekit.android.audio.AudioSwitchHandler
import io.livekit.android.events.RoomEvent
import io.livekit.android.events.collect
import io.livekit.android.room.Room
import io.livekit.android.room.participant.Participant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * LiveKit audio-only room: publishes the microphone, plays the tutor's audio, and routes it
 * as a voice call (communication mode; Bluetooth headset > wired headset > speaker > earpiece,
 * so speakerphone is the default when no headset is connected).
 *
 * Must be used from the main thread; events are delivered on the main thread.
 */
internal class LiveKitAiTutorRoom(context: Context) : AiTutorRoom {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val audioHandler = AudioSwitchHandler(appContext).apply {
        audioMode = AudioManager.MODE_IN_COMMUNICATION
        preferredDeviceList = listOf(
            AudioDevice.BluetoothHeadset::class.java,
            AudioDevice.WiredHeadset::class.java,
            AudioDevice.Speakerphone::class.java,
            AudioDevice.Earpiece::class.java
        )
    }
    private var room: Room? = null

    override fun connect(
        url: String,
        token: String,
        events: AiTutorRoomEvents,
        completion: (Throwable?) -> Unit
    ) {
        val newRoom = LiveKit.create(
            appContext,
            RoomOptions(adaptiveStream = false, dynacast = false),
            LiveKitOverrides(
                audioOptions = AudioOptions(
                    audioOutputType = AudioType.CallAudioType(),
                    audioHandler = audioHandler
                )
            )
        )
        room = newRoom

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            newRoom.events.collect { event -> dispatch(event, events) }
        }
        scope.launch {
            val error = try {
                newRoom.connect(url, token)
                if (!newRoom.localParticipant.setMicrophoneEnabled(true)) {
                    throw IllegalStateException("Microphone could not be published")
                }
                if (newRoom.remoteParticipants.values.any { it.kind == Participant.Kind.AGENT }) {
                    events.onTutorPresent()
                }
                null
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                Log.w(TAG, "Class review room connection failed", failure)
                failure
            }
            completion(error)
        }
    }

    override fun setMicrophoneEnabled(enabled: Boolean) {
        val activeRoom = room ?: return
        scope.launch {
            runCatching { activeRoom.localParticipant.setMicrophoneEnabled(enabled) }
                .onFailure { Log.w(TAG, "Microphone toggle failed", it) }
        }
    }

    /** Re-scans audio devices, e.g. after the Bluetooth permission was granted mid-call. */
    override fun refreshAudioRouting() {
        if (room == null) return
        audioHandler.stop()
        audioHandler.start()
    }

    override fun disconnect() {
        val closingRoom = room
        room = null
        closingRoom?.disconnect()
        closingRoom?.release()
        scope.cancel()
    }

    private fun dispatch(event: RoomEvent, events: AiTutorRoomEvents) {
        when (event) {
            is RoomEvent.ParticipantConnected ->
                if (event.participant.kind == Participant.Kind.AGENT) events.onTutorPresent()
            is RoomEvent.Reconnecting -> events.onReconnecting()
            is RoomEvent.Reconnected -> events.onReconnected()
            is RoomEvent.Disconnected -> events.onDisconnected()
            else -> Unit
        }
    }

    private companion object {
        const val TAG = "AiTutorCallRoom"
    }
}
