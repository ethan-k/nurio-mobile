package com.nurio.android.webview.images

import android.graphics.Bitmap
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.nurio.android.webview.NurioHotwireWebView
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

@RunWith(AndroidJUnit4::class)
class NativeImageWebViewTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val cacheField = NativeImageRequests::class.java.getDeclaredField("cache").apply { isAccessible = true }
    private var previousCache: Any? = null
    private lateinit var directory: File
    private lateinit var image: CachedImage
    private val source = "nurio-image://images.example.com/event.png?revision=42"

    @Before
    fun setUp() {
        previousCache = cacheField.get(null)
        directory = File(context.noBackupFilesDir, "image-test-${UUID.randomUUID()}")
        val bitmap = Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888)
        val png = ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            it.toByteArray()
        }
        bitmap.recycle()
        image = CachedImage(png, "image/png")
    }

    @After
    fun tearDown() {
        cacheField.set(null, previousCache)
        directory.deleteRecursively()
    }

    @Test
    fun imageRendersFromDeviceAfterRecreatingBothWebViewAndCacheOffline() {
        val networkRequests = AtomicInteger()
        installCache(ImageFetcher { _, _ -> networkRequests.incrementAndGet(); image })
        assertEquals("loaded:4", render(source))
        assertEquals(1, networkRequests.get())

        installCache(ImageFetcher { _, _ -> networkRequests.incrementAndGet(); throw IOException("Offline") })
        assertEquals("loaded:4", render(source))
        assertEquals("Reopening an image must perform zero new downloads", 1, networkRequests.get())
    }

    @Test
    fun unsuccessfulFirstImageRaisesErrorAndCanDownloadOnNextVisit() {
        val requests = AtomicInteger()
        installCache(ImageFetcher { _, _ ->
            if (requests.incrementAndGet() == 1) throw IOException("First download failed")
            image
        })
        assertEquals("failed", render(source))
        assertEquals("loaded:4", render(source))
        assertEquals(2, requests.get())
    }

    @Test
    fun platformDecoderRejectsTruncatedAndNonimageBytes() {
        val validator = AndroidImageValidator()
        assertEquals("image/png", validator.validatedMimeType(image))
        assertNull(validator.validatedMimeType(image.copy(bytes = image.bytes.copyOf(image.bytes.size / 2))))
        assertNull(validator.validatedMimeType(CachedImage("not an image".toByteArray(), "image/png")))
        assertEquals("image/svg+xml", validator.validatedMimeType(CachedImage("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".toByteArray(), "image/svg+xml")))
        assertNull(validator.validatedMimeType(CachedImage("<svg><path/>".toByteArray(), "image/svg+xml")))
        assertEquals("image/svg+xml", validator.validatedMimeType(CachedImage("<svg><style>path { fill: url('#gradient'); }</style></svg>".toByteArray(), "image/svg+xml")))
        listOf(
            "<svg><style>@import 'https://example.com/style.css';</style></svg>",
            "<svg><path style=\"fill: url(https://example.com/a.svg#paint)\"/></svg>",
            "<?xml-stylesheet href=\"https://example.com/style.css\"?><svg/>"
        ).forEach {
            assertNull(validator.validatedMimeType(CachedImage(it.toByteArray(), "image/svg+xml")))
        }
    }

    private fun installCache(fetcher: ImageFetcher) {
        cacheField.set(null, PersistentImageCache(directory, fetcher, AndroidImageValidator()))
    }

    private fun render(url: String): String? {
        val completed = CountDownLatch(1)
        var title: String? = null
        lateinit var webView: NurioHotwireWebView
        instrumentation.runOnMainSync {
            webView = NurioHotwireWebView(context).apply {
                settings.javaScriptEnabled = true
                settings.blockNetworkLoads = true
                webViewClient = WebViewClient()
                webChromeClient = object : WebChromeClient() {
                    override fun onReceivedTitle(view: WebView, value: String) {
                        if (value == "failed" || value.startsWith("loaded:")) {
                            title = value
                            completed.countDown()
                        }
                    }
                }
                loadDataWithBaseURL(
                    "https://nurio.kr/events/42",
                    "<html><head><title>waiting</title></head><body><img src=\"$url\" onload=\"document.title='loaded:'+this.naturalWidth\" onerror=\"document.title='failed'\"></body></html>",
                    "text/html", "UTF-8", null
                )
            }
        }
        try {
            assertTrue("WebView image did not settle", completed.await(15, TimeUnit.SECONDS))
            return title
        } finally {
            instrumentation.runOnMainSync { webView.destroy() }
        }
    }
}
