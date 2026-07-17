package com.nurio.study.android.auth

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Assert.fail
import org.junit.Test

class NativeAuthHandoffClientTest {
    private val directExecutor = Executor { command -> command.run() }

    @Test
    fun `callback URL encodes decoded payload values`() {
        val callbackUrl = NativeAuthHandoffClient.callbackUrl(
            """{"token":"signed token","state":"one/time"}"""
        )

        assertEquals(
            "nuriostudy://auth-callback?token=signed+token&state=one%2Ftime",
            callbackUrl
        )
    }

    @Test
    fun `callback URL rejects missing or blank token and state`() {
        val invalidPayloads = listOf(
            """{"state":"one/time"}""",
            """{"token":"signed token"}""",
            """{"token":"","state":"one/time"}""",
            """{"token":"signed token","state":"   "}"""
        )

        invalidPayloads.forEach { payload ->
            try {
                NativeAuthHandoffClient.callbackUrl(payload)
                fail("Expected invalid handoff payload to fail")
            } catch (_: IllegalArgumentException) {
                // Expected.
            }
        }
    }

    @Test
    fun `malformed payload errors never expose token or state values`() {
        val tokenSentinel = "SENTINEL_TOKEN_91"
        val stateSentinel = "SENTINEL_STATE_73"
        val malformedPayload =
            """{"token":"$tokenSentinel","state":"$stateSentinel","broken":}"""

        val error = assertThrows(IllegalArgumentException::class.java) {
            NativeAuthHandoffClient.callbackUrl(malformedPayload)
        }

        var currentError: Throwable? = error
        while (currentError != null) {
            val message = currentError.message.orEmpty()
            assertFalse("Token leaked through exception message", message.contains(tokenSentinel))
            assertFalse("State leaked through exception message", message.contains(stateSentinel))
            currentError = currentError.cause
        }
    }

    @Test
    fun `exchange posts JSON with redirect protection and returns callback URL`() {
        val connection = FakeHttpURLConnection(
            url = URL("https://study.nurio.kr/auth/kakao/native"),
            statusCode = 200,
            responseBody = """{"token":"signed token","state":"one/time"}"""
        )
        var openedUrl: URL? = null
        val client = NativeAuthHandoffClient(
            baseUrl = "https://study.nurio.kr/",
            backgroundExecutor = directExecutor,
            connectionFactory = { url ->
                openedUrl = url
                connection
            }
        )
        var callbackResult: Result<String>? = null

        client.exchangeKakao("kakao access token") { callbackResult = it }

        assertEquals(URL("https://study.nurio.kr/auth/kakao/native"), openedUrl)
        assertEquals("POST", connection.requestMethod)
        assertEquals("application/json", connection.getRequestProperty("Content-Type"))
        assertEquals("application/json", connection.getRequestProperty("Accept"))
        assertTrue(connection.doOutput)
        assertFalse(connection.instanceFollowRedirects)
        assertEquals(10_000, connection.connectTimeout)
        assertEquals(10_000, connection.readTimeout)
        assertEquals(
            """{"access_token":"kakao access token"}""",
            connection.requestBody.toString(StandardCharsets.UTF_8.name())
        )
        assertEquals(
            "nuriostudy://auth-callback?token=signed+token&state=one%2Ftime",
            callbackResult?.getOrThrow()
        )
        assertTrue(connection.disconnected)
    }

    @Test
    fun `exchange rejects redirects and other non success responses`() {
        listOf(307, 401).forEach { statusCode ->
            val connection = FakeHttpURLConnection(
                url = URL("https://study.nurio.kr/auth/kakao/native"),
                statusCode = statusCode,
                responseBody = """{"token":"ignored","state":"ignored"}"""
            )
            val client = NativeAuthHandoffClient(
                baseUrl = "https://study.nurio.kr",
                backgroundExecutor = directExecutor,
                connectionFactory = { connection }
            )
            var callbackResult: Result<String>? = null

            client.exchangeKakao("kakao access token") { callbackResult = it }

            assertTrue("HTTP $statusCode must fail", callbackResult?.isFailure == true)
            assertFalse(connection.inputStreamRead)
            assertTrue(connection.disconnected)
        }
    }

    @Test
    fun `blank access token fails before opening a connection`() {
        var connectionOpened = false
        val client = NativeAuthHandoffClient(
            baseUrl = "https://study.nurio.kr",
            backgroundExecutor = directExecutor,
            connectionFactory = {
                connectionOpened = true
                FakeHttpURLConnection(it, 200, "{}")
            }
        )
        var callbackResult: Result<String>? = null

        client.exchangeKakao("   ") { callbackResult = it }

        assertTrue(callbackResult?.isFailure == true)
        assertFalse(connectionOpened)
    }

    @Test
    fun `default executor runs exchange off caller thread without lingering`() {
        val callerThread = Thread.currentThread()
        val connection = FakeHttpURLConnection(
            url = URL("https://study.nurio.kr/auth/kakao/native"),
            statusCode = 200,
            responseBody = """{"token":"token","state":"state"}"""
        )
        val client = NativeAuthHandoffClient(
            baseUrl = "https://study.nurio.kr",
            connectionFactory = { connection }
        )
        val callbackReceived = CountDownLatch(1)
        var callbackThread: Thread? = null
        var callbackResult: Result<String>? = null

        client.exchangeKakao("kakao access token") { result ->
            callbackThread = Thread.currentThread()
            callbackResult = result
            callbackReceived.countDown()
        }

        assertTrue(callbackReceived.await(2, TimeUnit.SECONDS))
        callbackThread?.join(1_000)
        assertTrue(callbackResult?.isSuccess == true)
        assertNotSame(callerThread, callbackThread)
        assertFalse(callbackThread?.isAlive ?: true)
    }

    private class FakeHttpURLConnection(
        url: URL,
        private val statusCode: Int,
        responseBody: String
    ) : HttpURLConnection(url) {
        val requestBody = ByteArrayOutputStream()
        private val responseBytes = responseBody.toByteArray(StandardCharsets.UTF_8)
        var disconnected = false
        var inputStreamRead = false

        override fun connect() = Unit

        override fun disconnect() {
            disconnected = true
        }

        override fun usingProxy(): Boolean = false

        override fun getOutputStream() = requestBody

        override fun getResponseCode(): Int = statusCode

        override fun getInputStream(): ByteArrayInputStream {
            inputStreamRead = true
            return ByteArrayInputStream(responseBytes)
        }
    }
}
