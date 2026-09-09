package com.nurio.android.webview.images

import okhttp3.Authenticator
import okhttp3.Call
import okhttp3.CookieJar
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.URI
import java.util.concurrent.TimeUnit

class HttpsImageFetcher(
    private val calls: Call.Factory = imageClient()
) : ImageFetcher {
    override fun fetch(url: String, maxBytes: Int): CachedImage {
        var current = url
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(30)
        repeat(6) { hop ->
            if (!NativeImageUrl.isAllowedHttps(current)) throw IOException("Unsupported image destination")
            val remaining = deadline - System.nanoTime()
            if (remaining <= 0) throw IOException("Image download timed out")
            val request = Request.Builder().url(current)
                .header("Accept", "image/avif,image/webp,image/*;q=0.8")
                .header("User-Agent", "NurioImageCache/1 Android")
                .get().build()
            val call = calls.newCall(request)
            call.timeout().timeout(remaining, TimeUnit.NANOSECONDS)
            call.execute().use { response ->
                if (response.code in REDIRECT_CODES) {
                    if (hop == 5) throw IOException("Too many image redirects")
                    val destination = response.header("Location") ?: throw IOException("Missing image redirect")
                    current = URI(current).resolve(destination).toString()
                } else {
                    if (!response.isSuccessful || response.code == 206 || response.header("Content-Range") != null) {
                        throw IOException("Image HTTP request failed")
                    }
                    val mime = response.header("Content-Type")?.substringBefore(';')?.trim()?.lowercase()
                    if (mime == null || !mime.startsWith("image/")) throw IOException("Not an image response")
                    val body = response.body ?: throw IOException("Empty image response")
                    val length = body.contentLength()
                    if (length == 0L || length > maxBytes) throw IOException("Image size out of bounds")
                    val bytes = ByteArrayOutputStream().use { output ->
                        body.byteStream().use { input ->
                            val buffer = ByteArray(16 * 1024)
                            while (true) {
                                if (System.nanoTime() > deadline) throw IOException("Image download timed out")
                                val read = input.read(buffer)
                                if (read == -1) break
                                if (output.size().toLong() + read > maxBytes) throw IOException("Image too large")
                                output.write(buffer, 0, read)
                            }
                        }
                        output.toByteArray()
                    }
                    if (bytes.isEmpty() || (length >= 0 && bytes.size.toLong() != length)) {
                        throw IOException("Incomplete image response")
                    }
                    return CachedImage(bytes, mime)
                }
            }
        }
        throw IOException("Too many image redirects")
    }

    companion object {
        private val REDIRECT_CODES = setOf(301, 302, 303, 307, 308)

        // This client is deliberately separate from Hotwire's authenticated page client.
        // It never reads WebView cookies or copies page request headers to image origins.
        internal fun imageClient(): OkHttpClient = OkHttpClient.Builder()
            .cookieJar(CookieJar.NO_COOKIES)
            .authenticator(Authenticator.NONE)
            .proxyAuthenticator(Authenticator.NONE)
            .followRedirects(false)
            .followSslRedirects(false)
            .retryOnConnectionFailure(false)
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .callTimeout(30, TimeUnit.SECONDS)
            .build()
    }
}
