package com.nurio.android.webview.images

import okhttp3.CookieJar
import okhttp3.Interceptor
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import okio.BufferedSource
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.IOException

class HttpsImageFetcherTest {
    private val url = "https://images.example.com/image.png?version=1"

    @Test
    fun `image transport has no cookie jar or automatic redirect handling`() {
        val client = HttpsImageFetcher.imageClient()
        assertSame(CookieJar.NO_COOKIES, client.cookieJar)
        assertFalse(client.followRedirects)
        assertFalse(client.followSslRedirects)
        assertNull(client.cache)
    }

    @Test
    fun `valid HTTPS redirects load image bytes without page headers`() {
        val requests = mutableListOf<String>()
        val fetcher = fetcher { chain ->
            val request = chain.request()
            requests.add(request.url.toString())
            assertNull(request.header("Cookie"))
            assertNull(request.header("Authorization"))
            assertNull(request.header("Referer"))
            assertEquals("GET", request.method)
            if (requests.size == 1) {
                response(chain, 302, "").newBuilder().header("Location", "https://cdn.example.com/full.png").build()
            } else response(chain, 200, "image bytes")
        }
        assertArrayEquals("image bytes".toByteArray(), fetcher.fetch(url, 100).bytes)
        assertEquals(listOf(url, "https://cdn.example.com/full.png"), requests)
    }

    @Test
    fun `unsafe redirect never reaches the destination and redirect loops stop at five hops`() {
        listOf("http://cdn.example.com/a.png", "https://127.0.0.1/a.png", "https://user:password@cdn.example.com/a.png").forEach { target ->
            var calls = 0
            val fetcher = fetcher { chain ->
                calls++
                response(chain, 302, "").newBuilder().header("Location", target).build()
            }
            assertThrows(Exception::class.java) { fetcher.fetch(url, 100) }
            assertEquals(1, calls)
        }
        var calls = 0
        val loop = fetcher { chain ->
            calls++
            response(chain, 302, "").newBuilder().header("Location", "/loop.png").build()
        }
        assertThrows(IOException::class.java) { loop.fetch(url, 100) }
        assertEquals(6, calls)
    }

    @Test
    fun `HTTP failures partial responses and nonimage responses cannot become cached images`() {
        listOf(404, 500, 206).forEach { code ->
            assertThrows(IOException::class.java) { fetcher { response(it, code, "bad") }.fetch(url, 100) }
        }
        assertThrows(IOException::class.java) {
            fetcher { response(it, 200, "<html>Error</html>").newBuilder().header("Content-Type", "text/html").build() }.fetch(url, 100)
        }
    }

    @Test
    fun `declared and streamed size limits and truncated bodies are enforced`() {
        assertThrows(IOException::class.java) { fetcher { response(it, 200, "too big") }.fetch(url, 2) }
        assertThrows(IOException::class.java) {
            fetcher { response(it, 200, "").newBuilder().body(body("streamed-too-big", -1)).build() }.fetch(url, 4)
        }
        assertThrows(IOException::class.java) {
            fetcher { response(it, 200, "").newBuilder().body(body("short", 10)).build() }.fetch(url, 100)
        }
    }

    private fun fetcher(interceptor: (Interceptor.Chain) -> Response) = HttpsImageFetcher(
        HttpsImageFetcher.imageClient().newBuilder().addInterceptor(interceptor).build()
    )

    private fun response(chain: Interceptor.Chain, code: Int, body: String) = Response.Builder()
        .request(chain.request()).protocol(Protocol.HTTP_1_1).code(code).message("fixture")
        .header("Content-Type", "image/png").body(body.toResponseBody()).build()

    private fun body(value: String, length: Long) = object : ResponseBody() {
        override fun contentType() = null
        override fun contentLength() = length
        override fun source(): BufferedSource = Buffer().writeUtf8(value)
    }
}
