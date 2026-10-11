package com.nurio.study.android.aitutor

import java.io.IOException

internal const val BASE_URL = "https://study.nurio.kr"

internal fun callRequest() = AiTutorCallRequest(
    joinUrl = "$BASE_URL/practice/7/tutor_join",
    endUrl = "$BASE_URL/practice/7/tutor_end",
    reviewUrl = "$BASE_URL/practice/7/review",
    topic = "Ordering coffee",
    csrfToken = "csrf-123"
)

internal class RecordedPost(val url: String, val headers: Map<String, String>, val body: String)

internal class FakeTransport : AiTutorHttpTransport {
    val posts = mutableListOf<RecordedPost>()
    private val responses = ArrayDeque<() -> AiTutorHttpResponse>()

    fun respond(status: Int, body: String = "{}", setCookies: List<String> = emptyList()) {
        responses += { AiTutorHttpResponse(status, body, setCookies) }
    }

    fun fail() {
        responses += { throw IOException("offline") }
    }

    override fun post(url: String, headers: Map<String, String>, body: String): AiTutorHttpResponse {
        posts += RecordedPost(url, headers, body)
        val next = responses.removeFirstOrNull() ?: throw IOException("unexpected request to $url")
        return next()
    }
}

internal class FakeCookieStore(private val header: String? = "_nurio_session=abc") : AiTutorCookieStore {
    val saved = mutableListOf<Pair<String, List<String>>>()

    override fun cookieHeader(url: String): String? = header

    override fun save(url: String, setCookies: List<String>) {
        saved += url to setCookies
    }
}

internal class FakeClock(var now: Long = 1_000_000L) {
    val sleeps = mutableListOf<Long>()

    fun sleep(millis: Long) {
        sleeps += millis
        now += millis
    }
}

internal fun fakeApi(transport: FakeTransport, clock: FakeClock = FakeClock()) = AiTutorCallApi(
    transport = transport,
    cookieStore = FakeCookieStore(),
    baseUrl = BASE_URL,
    clock = { clock.now },
    sleeper = clock::sleep
)

internal class FakeRoom : AiTutorRoom {
    var connectedUrl: String? = null
    var connectedToken: String? = null
    var events: AiTutorRoomEvents? = null
    var completion: ((Throwable?) -> Unit)? = null
    val microphoneStates = mutableListOf<Boolean>()
    var disconnected = false

    override fun connect(
        url: String,
        token: String,
        events: AiTutorRoomEvents,
        completion: (Throwable?) -> Unit
    ) {
        connectedUrl = url
        connectedToken = token
        this.events = events
        this.completion = completion
    }

    override fun setMicrophoneEnabled(enabled: Boolean) {
        microphoneStates += enabled
    }

    override fun refreshAudioRouting() = Unit

    override fun disconnect() {
        disconnected = true
    }
}
