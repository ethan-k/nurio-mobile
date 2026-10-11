package com.nurio.study.android.aitutor

import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiTutorCallEngineTest {
    private val direct = Executor { it.run() }
    private val transport = FakeTransport()
    private val clock = FakeClock()
    private val rooms = mutableListOf<FakeRoom>()
    private val finished = mutableListOf<String>()
    private val engine = AiTutorCallEngine(
        api = fakeApi(transport, clock),
        roomFactory = { FakeRoom().also { rooms += it } },
        backgroundExecutor = direct,
        mainExecutor = direct,
        clock = { clock.now }
    ).apply {
        listener = object : AiTutorCallEngine.Listener {
            override fun onSnapshot(snapshot: AiTutorCallSnapshot) = Unit
            override fun onFinished(reviewUrl: String) {
                finished += reviewUrl
            }
        }
    }

    private val deadline = AiTutorCallApi.parseTimestamp("2026-10-11T12:30:00Z")!!
    private val readyBody = """
        {"status":"connecting","deadline_at":"2026-10-11T12:30:00Z",
         "livekit":{"url":"wss://lk.example","participant_token":"tok"}}
    """.trimIndent()

    private fun startConnected(tutorPresent: Boolean = true): FakeRoom {
        transport.respond(200, readyBody)
        assertTrue(engine.start(callRequest()))
        val room = rooms.single()
        if (tutorPresent) room.events!!.onTutorPresent()
        room.completion!!(null)
        return room
    }

    @Test
    fun `duplicate start while a call is active is ignored`() {
        transport.respond(202, """{"status":"provisioning"}""")
        transport.respond(200, readyBody)
        assertTrue(engine.start(callRequest()))

        assertFalse(engine.start(callRequest()))

        assertEquals(2, transport.posts.size)
        assertEquals(1, rooms.size)
    }

    @Test
    fun `ready join connects the room and goes live when the tutor is present`() {
        val room = startConnected()

        assertEquals("wss://lk.example", room.connectedUrl)
        assertEquals("tok", room.connectedToken)
        assertEquals(AiTutorCallStatus.LIVE, engine.snapshot.status)
        assertEquals(deadline, engine.snapshot.deadlineAtMillis)
        assertEquals("Ordering coffee", engine.snapshot.topic)
    }

    @Test
    fun `status waits for the tutor and reflects reconnecting`() {
        val room = startConnected(tutorPresent = false)
        assertEquals(AiTutorCallStatus.TUTOR_JOINING, engine.snapshot.status)

        room.events!!.onTutorPresent()
        assertEquals(AiTutorCallStatus.LIVE, engine.snapshot.status)

        room.events!!.onReconnecting()
        assertEquals(AiTutorCallStatus.RECONNECTING, engine.snapshot.status)

        room.events!!.onReconnected()
        assertEquals(AiTutorCallStatus.LIVE, engine.snapshot.status)
    }

    @Test
    fun `410 on join goes straight to the review without calling end`() {
        transport.respond(410, """{"status":"ended","review_url":"/practice/7/review"}""")

        engine.start(callRequest())

        assertEquals(listOf("$BASE_URL/practice/7/review"), finished)
        assertEquals(1, transport.posts.size)
        assertTrue(rooms.isEmpty())
        assertFalse(engine.isActive)
    }

    @Test
    fun `end stops the microphone, disconnects, posts end and reports the review URL`() {
        val room = startConnected()
        transport.respond(200, """{"review_url":"/practice/7/review"}""")

        engine.end()

        assertEquals(listOf(false), room.microphoneStates)
        assertTrue(room.disconnected)
        assertEquals("$BASE_URL/practice/7/tutor_end", transport.posts.last().url)
        assertEquals(listOf("$BASE_URL/practice/7/review"), finished)
        assertEquals(AiTutorCallStatus.ENDED, engine.snapshot.status)
        assertFalse(engine.isActive)
    }

    @Test
    fun `unexpected disconnect ends the session`() {
        val room = startConnected()
        transport.respond(200, """{"review_url":"/practice/7/review"}""")

        room.events!!.onDisconnected()

        assertEquals("$BASE_URL/practice/7/tutor_end", transport.posts.last().url)
        assertEquals(1, finished.size)
    }

    @Test
    fun `room connection failure ends the session`() {
        transport.respond(200, readyBody)
        engine.start(callRequest())
        transport.respond(200, """{"review_url":"/practice/7/review"}""")

        rooms.single().completion!!(IllegalStateException("mic"))

        assertEquals(1, finished.size)
        assertTrue(rooms.single().disconnected)
    }

    @Test
    fun `reaching the deadline ends the call`() {
        startConnected()
        transport.respond(200, """{"review_url":"/practice/7/review"}""")

        clock.now = deadline - 1
        engine.tick()
        assertTrue(finished.isEmpty())

        clock.now = deadline
        engine.tick()
        assertEquals(1, finished.size)
    }

    @Test
    fun `mute toggles the published microphone`() {
        val room = startConnected()

        engine.toggleMute()
        assertTrue(engine.snapshot.muted)
        engine.toggleMute()

        assertEquals(listOf(false, true), room.microphoneStates)
        assertFalse(engine.snapshot.muted)
    }

    @Test
    fun `a failed join can be retried`() {
        transport.respond(500)
        engine.start(callRequest())
        assertEquals(AiTutorCallStatus.FAILED, engine.snapshot.status)

        transport.respond(200, readyBody)
        engine.retry()

        assertEquals(AiTutorCallStatus.CONNECTING, engine.snapshot.status)
        assertEquals(1, rooms.size)
    }

    @Test
    fun `ending without a call posts end and opens the review`() {
        transport.respond(200, """{"review_url":"/practice/7/review"}""")

        assertTrue(engine.endWithoutCall(callRequest()))

        assertEquals(listOf("$BASE_URL/practice/7/tutor_end"), transport.posts.map { it.url })
        assertEquals(listOf("$BASE_URL/practice/7/review"), finished)
    }

    @Test
    fun `a new call can start after the previous one finished`() {
        startConnected()
        transport.respond(200, """{"review_url":"/practice/7/review"}""")
        engine.end()

        transport.respond(200, readyBody)

        assertTrue(engine.start(callRequest()))
        assertEquals(2, rooms.size)
    }
}
