package com.nurio.android.webview

import android.graphics.Bitmap
import android.os.Build
import android.os.SystemClock
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.nurio.android.BuildConfig
import com.nurio.android.MainActivity
import com.nurio.android.payments.PaymentRecovery
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.session.Session
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CopyOnWriteArrayList

@RunWith(AndroidJUnit4::class)
class PaymentCompletionWebViewTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val originalFactory = Hotwire.config.makeCustomWebView
    private val requests = CopyOnWriteArrayList<String>()

    @Before
    fun setUp() {
        Hotwire.config.makeCustomWebView = { context ->
            originalFactory(context).apply { settings.blockNetworkLoads = true }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            instrumentation.uiAutomation.grantRuntimePermission(
                BuildConfig.APPLICATION_ID, android.Manifest.permission.POST_NOTIFICATIONS
            )
        }
    }

    @After
    fun tearDown() {
        Hotwire.config.makeCustomWebView = originalFactory
        PaymentRecovery.clear()
    }

    @Test
    fun customCallbackLoadsMerchantCompletionAfterGatewayPost() = exerciseReturn("nurio://payment-complete")

    @Test
    fun webCallbackLoadsMerchantCompletionAfterGatewayPost() =
        exerciseReturn("${BuildConfig.BASE_URL}/payments/portone/complete")

    private fun exerciseReturn(callbackBase: String) {
        val query = "?paymentId=completion-test&redirect_uri=%2Fevents%2F77"
        val destination = "${BuildConfig.BASE_URL}/payments/portone/complete$query"
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var activity: MainActivity
            scenario.onActivity { activity = it }
            await("Navigator did not start") {
                activity.delegate.currentNavigator?.session?.currentVisit != null &&
                    activity.delegate.currentNavigator?.session?.webView?.progress == 100
            }
            lateinit var session: Session
            scenario.onActivity {
                session = it.delegate.currentNavigator!!.session
                val view = session.webView
                val delegate = view.webViewClient
                view.webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) =
                        delegate.shouldOverrideUrlLoading(view, request)

                    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) =
                        delegate.onPageStarted(view, url, favicon)

                    override fun onPageFinished(view: WebView, url: String) = delegate.onPageFinished(view, url)

                    override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                        if (request.isForMainFrame && request.url.scheme in setOf("http", "https")) {
                            requests.add("${request.method}:${request.url}")
                        }
                        val html = if (request.url.host == "sandbox.inicis.com") {
                            // The real gateway replaces the document and has no Turbo runtime.
                            "<title>gateway-ready</title><h1>Test payment provider</h1>"
                        } else {
                            "<title>payment-verified</title>$readyBridge"
                        }
                        return WebResourceResponse("text/html", "UTF-8", html.byteInputStream())
                    }
                }
                PaymentRecovery.track("gateway_handoff", "completion-test", "${BuildConfig.BASE_URL}/events/77")
                view.loadDataWithBaseURL(
                    "${BuildConfig.BASE_URL}/events/77",
                    """<title>checkout-ready</title>$readyBridge
                    <form id="payment" method="post" action="https://sandbox.inicis.com/payment">
                      <input name="paymentId" value="local-regression-only">
                    </form>""",
                    "text/html", "UTF-8", null
                )
            }
            await("Checkout did not initialize") { session.isReady && session.webView.title == "checkout-ready" }
            instrumentation.runOnMainSync {
                session.webView.evaluateJavascript("document.getElementById('payment').submit()", null)
            }
            await("Gateway POST did not load") { session.webView.title == "gateway-ready" }
            instrumentation.runOnMainSync {
                assertTrue("Reproduce a warm session whose gateway document lacks Turbo", session.isReady)
                session.webView.evaluateJavascript("window.location.href='$callbackBase$query'", null)
            }
            await("Completion never loaded after the gateway POST") {
                session.webView.title == "payment-verified" && requests.contains("GET:$destination")
            }
            assertEquals(
                "Only the merchant completion may be loaded again; never replay the gateway POST as GET",
                listOf("POST:https://sandbox.inicis.com/payment", "GET:$destination"),
                requests.toList(),
            )
        }
    }

    private fun await(message: String, condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 10_000
        while (SystemClock.uptimeMillis() < deadline) {
            var passed = false
            instrumentation.runOnMainSync { passed = condition() }
            if (passed) return
            SystemClock.sleep(50)
        }
        assertTrue("$message; requests=$requests", false)
    }

    private val readyBridge = """<script>
        window.turboNative = { visitRenderedForColdBoot: function() {} };
        TurboSession.turboIsReady(true);
    </script>"""
}
