package com.nurio.study.android.aitutor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AiTutorCallApiTest {
    private val readyBody = """
        {"status":"connecting","deadline_at":"2026-10-11T12:30:00.000Z",
         "livekit":{"url":"wss://lk.example","room":"r1","participant_token":"tok"}}
    """.trimIndent()

    @Test
    fun `join polls every 1_5s while provisioning and returns LiveKit credentials when ready`() {
        val transport = FakeTransport().apply {
            respond(202, """{"status":"provisioning","deadline_at":"2026-10-11T12:30:00Z"}""")
            respond(202, """{"status":"provisioning"}""")
            respond(200, readyBody)
        }
        val clock = FakeClock()
        val deadlines = mutableListOf<Long>()

        val outcome = fakeApi(transport, clock).join(callRequest(), onDeadline = { deadlines += it })

        val expectedDeadline = AiTutorCallApi.parseTimestamp("2026-10-11T12:30:00Z")
        assertEquals(AiTutorJoinOutcome.Ready("wss://lk.example", "tok", expectedDeadline), outcome)
        assertEquals(3, transport.posts.size)
        assertEquals(listOf(1_500L, 1_500L), clock.sleeps)
        assertEquals(listOf(expectedDeadline, expectedDeadline), deadlines)
    }

    @Test
    fun `join returns the review URL when the session already ended`() {
        val transport = FakeTransport().apply {
            respond(410, """{"status":"ended","review_url":"/practice/7/review?done=1"}""")
        }

        val outcome = fakeApi(transport).join(callRequest())

        assertEquals(AiTutorJoinOutcome.Ended("$BASE_URL/practice/7/review?done=1"), outcome)
    }

    @Test
    fun `join gives up after 30 seconds of provisioning`() {
        val transport = FakeTransport().apply { repeat(40) { respond(202, """{"status":"provisioning"}""") } }
        val clock = FakeClock()

        assertThrows(AiTutorCallException::class.java) { fakeApi(transport, clock).join(callRequest()) }
        assertTrue(clock.sleeps.sum() in 30_000L..31_500L)
    }

    @Test
    fun `join fails on an error status`() {
        val transport = FakeTransport().apply { respond(422, """{"error":"no_allowance"}""") }

        assertThrows(AiTutorCallException::class.java) { fakeApi(transport).join(callRequest()) }
    }

    @Test
    fun `join stops polling once cancelled`() {
        val transport = FakeTransport().apply { respond(202, """{"status":"provisioning"}""") }
        var cancelled = false
        val clock = FakeClock()
        val api = AiTutorCallApi(
            transport = transport,
            cookieStore = FakeCookieStore(),
            baseUrl = BASE_URL,
            clock = { clock.now },
            sleeper = { cancelled = true }
        )

        assertThrows(AiTutorJoinCancelledException::class.java) {
            api.join(callRequest(), isCancelled = { cancelled })
        }
        assertEquals(1, transport.posts.size)
    }

    @Test
    fun `requests carry CSRF token, session cookie and JSON headers with an empty JSON body`() {
        val transport = FakeTransport().apply { respond(200, readyBody) }

        fakeApi(transport).join(callRequest())

        val post = transport.posts.single()
        assertEquals("$BASE_URL/practice/7/tutor_join", post.url)
        assertEquals("csrf-123", post.headers["X-CSRF-Token"])
        assertEquals("_nurio_session=abc", post.headers["Cookie"])
        assertEquals("application/json", post.headers["Accept"])
        assertEquals("application/json", post.headers["Content-Type"])
        assertEquals("{}", post.body)
    }

    @Test
    fun `rotated session cookies are written back to the shared cookie store`() {
        val transport = FakeTransport().apply {
            respond(200, readyBody, setCookies = listOf("_nurio_session=rotated; path=/; secure"))
        }
        val cookies = FakeCookieStore()
        val api = AiTutorCallApi(transport, cookies, BASE_URL, sleeper = {})

        api.join(callRequest())

        assertEquals(
            listOf("$BASE_URL/practice/7/tutor_join" to listOf("_nurio_session=rotated; path=/; secure")),
            cookies.saved
        )
    }

    @Test
    fun `missing cookies and CSRF token are omitted rather than sent blank`() {
        val transport = FakeTransport().apply { respond(200, readyBody) }
        val api = AiTutorCallApi(transport, FakeCookieStore(header = null), BASE_URL, sleeper = {})

        api.join(callRequest().copy(csrfToken = ""))

        val headers = transport.posts.single().headers
        assertNull(headers["Cookie"])
        assertNull(headers["X-CSRF-Token"])
    }

    @Test
    fun `end retries failures and returns the server review URL`() {
        val transport = FakeTransport().apply {
            respond(500)
            fail()
            respond(200, """{"review_url":"/practice/7/review?from=end"}""")
        }

        val reviewUrl = fakeApi(transport).end(callRequest())

        assertEquals("$BASE_URL/practice/7/review?from=end", reviewUrl)
        assertEquals(3, transport.posts.size)
        assertTrue(transport.posts.all { it.url == "$BASE_URL/practice/7/tutor_end" })
        assertTrue(transport.posts.all { it.headers["X-CSRF-Token"] == "csrf-123" })
    }

    @Test
    fun `end gives up after three attempts and falls back to the page review URL`() {
        val transport = FakeTransport().apply { repeat(5) { respond(503) } }

        val reviewUrl = fakeApi(transport).end(callRequest())

        assertEquals("$BASE_URL/practice/7/review", reviewUrl)
        assertEquals(3, transport.posts.size)
    }

    @Test
    fun `a review URL on another origin is ignored`() {
        val transport = FakeTransport().apply {
            respond(200, """{"review_url":"https://evil.example/phish"}""")
        }

        assertEquals("$BASE_URL/practice/7/review", fakeApi(transport).end(callRequest()))
    }
}
