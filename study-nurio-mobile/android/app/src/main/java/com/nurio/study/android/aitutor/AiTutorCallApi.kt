package com.nurio.study.android.aitutor

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.time.OffsetDateTime
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject

data class AiTutorHttpResponse(
    val status: Int,
    val body: String,
    val setCookies: List<String> = emptyList()
)

fun interface AiTutorHttpTransport {
    @Throws(IOException::class)
    fun post(url: String, headers: Map<String, String>, body: String): AiTutorHttpResponse
}

/** The session cookies shared with the WebView. */
interface AiTutorCookieStore {
    fun cookieHeader(url: String): String?
    fun save(url: String, setCookies: List<String>)
}

sealed interface AiTutorJoinOutcome {
    data class Ready(
        val livekitUrl: String,
        val participantToken: String,
        val deadlineAtMillis: Long?
    ) : AiTutorJoinOutcome

    data class Ended(val reviewUrl: String) : AiTutorJoinOutcome
}

class AiTutorCallException(message: String) : IOException(message)

class AiTutorJoinCancelledException : IOException("Join cancelled")

/**
 * Blocking client for the Rails class-review call endpoints. Call it off the main thread.
 *
 * - `POST joinUrl` answers 202 while the room/agent is provisioning (poll), 200 with LiveKit
 *   credentials when ready, or 410 with a `review_url` when the session already ended.
 * - `POST endUrl` answers 200 with a `review_url`; it is retried because an unended session keeps
 *   consuming the learner's practice allowance.
 */
class AiTutorCallApi(
    private val transport: AiTutorHttpTransport,
    private val cookieStore: AiTutorCookieStore,
    private val baseUrl: String,
    private val clock: () -> Long = System::currentTimeMillis,
    private val sleeper: (Long) -> Unit = Thread::sleep,
    private val pollIntervalMillis: Long = POLL_INTERVAL_MILLIS,
    private val provisionTimeoutMillis: Long = PROVISION_TIMEOUT_MILLIS,
    private val endAttempts: Int = END_ATTEMPTS,
    private val endRetryDelayMillis: Long = END_RETRY_DELAY_MILLIS
) {
    fun join(
        request: AiTutorCallRequest,
        isCancelled: () -> Boolean = { false },
        onDeadline: (Long) -> Unit = {}
    ): AiTutorJoinOutcome {
        val startedAt = clock()

        while (true) {
            if (isCancelled()) throw AiTutorJoinCancelledException()

            val response = post(request.joinUrl, request.csrfToken)
            val body = parseObject(response.body)

            if (response.status == HTTP_GONE) {
                return AiTutorJoinOutcome.Ended(reviewUrl(body, request))
            }
            if (response.status !in 200..299) {
                throw AiTutorCallException("Join rejected with HTTP ${response.status}")
            }

            val deadline = body?.string("deadline_at")?.let(::parseTimestamp)
            deadline?.let(onDeadline)

            val livekit = body?.get("livekit") as? JsonObject
            val livekitUrl = livekit?.string("url")
            val token = livekit?.string("participant_token")
            if (!livekitUrl.isNullOrBlank() && !token.isNullOrBlank()) {
                return AiTutorJoinOutcome.Ready(livekitUrl, token, deadline)
            }

            if (clock() - startedAt > provisionTimeoutMillis) {
                throw AiTutorCallException("Provisioning timed out")
            }
            sleeper(pollIntervalMillis)
        }
    }

    /** Ends the session server-side and returns where the learner should land. Never throws. */
    fun end(request: AiTutorCallRequest): String {
        repeat(endAttempts) { attempt ->
            val response = runCatching { post(request.endUrl, request.csrfToken) }.getOrNull()
            if (response != null && response.status in 200..299) {
                return reviewUrl(parseObject(response.body), request)
            }
            if (attempt < endAttempts - 1) runCatching { sleeper(endRetryDelayMillis) }
        }
        return request.reviewUrl
    }

    private fun post(url: String, csrfToken: String): AiTutorHttpResponse {
        val headers = linkedMapOf(
            "Accept" to JSON_CONTENT_TYPE,
            "Content-Type" to JSON_CONTENT_TYPE
        )
        if (csrfToken.isNotBlank()) headers["X-CSRF-Token"] = csrfToken
        cookieStore.cookieHeader(url)?.takeIf { it.isNotBlank() }?.let { headers["Cookie"] = it }

        val response = transport.post(url, headers, EMPTY_JSON_BODY)
        if (response.setCookies.isNotEmpty()) cookieStore.save(url, response.setCookies)
        return response
    }

    private fun reviewUrl(body: JsonObject?, request: AiTutorCallRequest): String {
        return AiTutorUrls.resolveSameOrigin(body?.string("review_url"), baseUrl)
            ?: request.reviewUrl
    }

    private fun parseObject(body: String): JsonObject? =
        runCatching { json.parseToJsonElement(body).jsonObject }.getOrNull()

    private fun JsonObject.string(key: String): String? =
        (get(key) as? JsonPrimitive)?.takeIf { it.isString }?.content

    companion object {
        const val POLL_INTERVAL_MILLIS = 1_500L
        const val PROVISION_TIMEOUT_MILLIS = 30_000L
        const val END_ATTEMPTS = 3
        const val END_RETRY_DELAY_MILLIS = 500L
        private const val HTTP_GONE = 410
        private const val JSON_CONTENT_TYPE = "application/json"
        private const val EMPTY_JSON_BODY = "{}"
        private val json = Json { ignoreUnknownKeys = true }

        fun parseTimestamp(value: String): Long? =
            runCatching { OffsetDateTime.parse(value).toInstant().toEpochMilli() }.getOrNull()
    }
}

class HttpUrlConnectionTransport(
    private val connectionFactory: (URL) -> HttpURLConnection = { url ->
        url.openConnection() as HttpURLConnection
    }
) : AiTutorHttpTransport {
    override fun post(url: String, headers: Map<String, String>, body: String): AiTutorHttpResponse {
        val connection = connectionFactory(URL(url))
        try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.useCaches = false
            connection.instanceFollowRedirects = false
            connection.connectTimeout = CONNECT_TIMEOUT_MILLIS
            connection.readTimeout = READ_TIMEOUT_MILLIS
            headers.forEach { (name, value) -> connection.setRequestProperty(name, value) }

            connection.outputStream.use { output ->
                output.write(body.toByteArray(StandardCharsets.UTF_8))
            }

            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val responseBody = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
            val setCookies = connection.headerFields.orEmpty()
                .filterKeys { key -> key != null && key.equals("Set-Cookie", ignoreCase = true) }
                .values
                .flatten()

            return AiTutorHttpResponse(status, responseBody, setCookies)
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val CONNECT_TIMEOUT_MILLIS = 10_000
        const val READ_TIMEOUT_MILLIS = 15_000
    }
}
