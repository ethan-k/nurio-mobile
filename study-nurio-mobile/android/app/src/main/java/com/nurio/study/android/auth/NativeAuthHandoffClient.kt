package com.nurio.study.android.auth

import com.nurio.study.android.BuildConfig
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executor
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class NativeAuthHandoffPayload(
    val token: String,
    val state: String
)

@Serializable
private data class NativeKakaoHandoffRequest(
    @SerialName("access_token") val accessToken: String
)

class NativeAuthHandoffClient(
    private val baseUrl: String = BuildConfig.BASE_URL,
    private val backgroundExecutor: Executor = oneShotBackgroundExecutor,
    private val connectionFactory: (URL) -> HttpURLConnection = { url ->
        url.openConnection() as HttpURLConnection
    }
) {
    fun exchangeKakao(
        accessToken: String,
        callback: (Result<String>) -> Unit
    ) {
        backgroundExecutor.execute {
            val result = runCatching {
                require(accessToken.isNotBlank()) { "Kakao access token must not be blank" }
                callbackUrl(exchangeKakaoBlocking(accessToken))
            }

            callback(result)
        }
    }

    private fun exchangeKakaoBlocking(accessToken: String): String {
        val endpoint = URL("${baseUrl.trimEnd('/')}/auth/kakao/native")
        val connection = connectionFactory(endpoint)

        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", JSON_CONTENT_TYPE)
            connection.setRequestProperty("Accept", JSON_CONTENT_TYPE)
            connection.doOutput = true
            connection.connectTimeout = CONNECT_TIMEOUT_MILLIS
            connection.readTimeout = READ_TIMEOUT_MILLIS
            connection.instanceFollowRedirects = false

            val requestBody = json.encodeToString(NativeKakaoHandoffRequest(accessToken))
            connection.outputStream.use { outputStream ->
                outputStream.write(requestBody.toByteArray(StandardCharsets.UTF_8))
            }

            val statusCode = connection.responseCode
            if (statusCode !in 200..299) {
                throw IOException("Native auth handoff rejected with HTTP $statusCode")
            }

            return connection.inputStream.bufferedReader(StandardCharsets.UTF_8).use { reader ->
                reader.readText()
            }
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private const val JSON_CONTENT_TYPE = "application/json"
        private const val CONNECT_TIMEOUT_MILLIS = 10_000
        private const val READ_TIMEOUT_MILLIS = 10_000
        private val json = Json { ignoreUnknownKeys = true }
        private val oneShotBackgroundExecutor = Executor { command ->
            Thread(command, "nurio-study-native-auth").apply {
                isDaemon = true
                start()
            }
        }

        fun callbackUrl(responseBody: String): String {
            val payload = try {
                json.decodeFromString<NativeAuthHandoffPayload>(responseBody)
            } catch (error: Exception) {
                throw IllegalArgumentException("Invalid native auth handoff payload", error)
            }

            require(payload.token.isNotBlank()) { "Native auth token must not be blank" }
            require(payload.state.isNotBlank()) { "Native auth state must not be blank" }

            val encodedToken = URLEncoder.encode(
                payload.token,
                StandardCharsets.UTF_8.name()
            )
            val encodedState = URLEncoder.encode(
                payload.state,
                StandardCharsets.UTF_8.name()
            )

            return "nuriostudy://auth-callback?token=$encodedToken&state=$encodedState"
        }
    }
}
