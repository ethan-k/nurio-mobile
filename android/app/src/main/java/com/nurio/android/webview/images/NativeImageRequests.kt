package com.nurio.android.webview.images

import android.content.Context
import android.webkit.WebResourceResponse
import java.io.ByteArrayInputStream
import java.io.File

internal object NativeImageRequests {
    @Volatile private var cache: PersistentImageCache? = null

    fun intercept(context: Context, url: String): WebResourceResponse? {
        if (!NativeImageUrl.isImageRequest(url)) return null
        return try {
            val original = NativeImageUrl.original(url) ?: return failure()
            val image = cache(context).load(original)
            WebResourceResponse(
                image.mimeType,
                null,
                200,
                "OK",
                // Only <img>/CSS image consumption is needed. Do not grant cross-origin fetch access.
                mapOf("Cache-Control" to "no-store", "X-Content-Type-Options" to "nosniff"),
                ByteArrayInputStream(image.bytes)
            )
        } catch (_: Exception) {
            failure()
        }
    }

    private fun cache(context: Context): PersistentImageCache = cache ?: synchronized(this) {
        cache ?: PersistentImageCache(
            File(context.applicationContext.noBackupFilesDir, "event-images-v1"),
            HttpsImageFetcher(),
            AndroidImageValidator()
        ).also { cache = it }
    }

    private fun failure() = WebResourceResponse(
        "text/plain", "UTF-8", 502, "Image unavailable",
        mapOf("Cache-Control" to "no-store"), ByteArrayInputStream(ByteArray(0))
    )
}
