package com.nurio.android.webview

import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Message
import android.os.SystemClock
import android.view.KeyEvent
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.io.File

@RunWith(AndroidJUnit4::class)
class PaymentPopupWebViewTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val originalFactory = Hotwire.config.makeCustomWebView
    private val requests = CopyOnWriteArrayList<String>()
    private lateinit var parent: NurioHotwireWebView
    private var popup: WebView? = null

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
        PaymentRecovery.track("flow_finished", null, null)
    }

    @Test
    fun ticketPopupPreservesPostAndCheckoutWindow() = exercisePopup("/orders/42/payment_summary")

    @Test
    fun passPopupPreservesPostAndCheckoutWindow() = exercisePopup("/pass_packages/3/payment_summary")

    @Test
    fun ticketCompletionClosesPaymentWindow() = exercisePopup(
        "/orders/42/payment_summary",
        "nurio://payment-complete?paymentId=popup-test&redirect_uri=%2Fevents%2F77",
    )

    @Test
    fun passCompletionClosesPaymentWindow() = exercisePopup(
        "/pass_packages/3/payment_summary",
        "${BuildConfig.BASE_URL}/payments/portone/complete?paymentId=popup-test&redirect_uri=%2Fevents%2F77",
    )

    @Test
    fun appLinkCompletionClosesPaymentWindow() = exercisePopup(
        "/orders/42/payment_summary",
        "${BuildConfig.BASE_URL}/payments/portone/complete?paymentId=popup-test&redirect_uri=%2Fevents%2F77",
        returnViaIntent = true,
    )

    private fun exercisePopup(path: String, completionUrl: String? = null, returnViaIntent: Boolean = false) {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            try {
                scenario.onActivity { activity ->
                    parent = NurioHotwireWebView(activity)
                    val session = Session("payment-popup-test", activity, parent)
                    parent.settings.blockNetworkLoads = true
                    parent.webViewClient = object : WebViewClient() {
                        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                            if (request.isForMainFrame) requests.add("parent:${request.method}")
                            return response("<title>checkout-replaced</title>")
                        }
                    }
                    val client = PaymentWebChromeClient(session)
                    parent.webChromeClient = object : WebChromeClient() {
                        override fun onCreateWindow(view: WebView, dialog: Boolean, gesture: Boolean, message: Message?): Boolean {
                            val handled = client.onCreateWindow(view, dialog, gesture, message)
                            val child = (message?.obj as? WebView.WebViewTransport)?.webView ?: return handled
                            popup = child
                            child.settings.blockNetworkLoads = true
                            val delegate = child.webViewClient
                            child.webViewClient = object : WebViewClient() {
                                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) =
                                    delegate.shouldOverrideUrlLoading(view, request)

                                override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) =
                                    delegate.onPageStarted(view, url, favicon)

                                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                                    if (request.isForMainFrame) requests.add("popup:${request.method}")
                                    return response("<meta name='viewport' content='width=device-width, initial-scale=1'><title>gateway-ready</title><h1>Test payment provider</h1><p>Local popup regression test. No charge is made.</p>")
                                }
                            }
                            return handled
                        }
                    }
                    activity.addContentView(parent, ViewGroup.LayoutParams(-1, -1))
                    PaymentRecovery.track("gateway_handoff", "popup-test", "${BuildConfig.BASE_URL}$path")
                    parent.loadDataWithBaseURL(
                        "${BuildConfig.BASE_URL}$path",
                        """<html><head><title>checkout-ready</title></head><body>
                        <form id="payment" method="post" target="gateway" action="https://sandbox.inicis.com/payment">
                          <input type="hidden" name="paymentId" value="local-regression-only">
                        </form><script>
                          window.addEventListener('message', function(event) { document.title = event.data; });
                          function pay() { window.open('', 'gateway'); document.getElementById('payment').submit(); }
                        </script></body></html>""",
                        "text/html", "UTF-8", null
                    )
                }
                await("Checkout did not load") { parent.title == "checkout-ready" }
                repeat(if (completionUrl == null) 2 else 0) {
                    requests.clear()
                    instrumentation.runOnMainSync { parent.evaluateJavascript("pay()", null) }
                    await("Gateway did not receive the form") { requests.isNotEmpty() }
                    await("Gateway was not presented with its POST response") {
                        popup?.title == "gateway-ready" && popup?.isShown == true
                    }
                    assertEquals(listOf("popup:POST"), requests.toList())
                    if (it == 0) {
                        val painted = CountDownLatch(1)
                        instrumentation.runOnMainSync {
                            popup!!.postVisualStateCallback(1, object : WebView.VisualStateCallback() {
                                override fun onComplete(requestId: Long) { painted.countDown() }
                            })
                        }
                        assertTrue("Provider did not render", painted.await(10, TimeUnit.SECONDS))
                        instrumentation.waitForIdleSync()
                        SystemClock.sleep(250)
                        val screenshot = instrumentation.uiAutomation.takeScreenshot()
                        val name = if (path.startsWith("/orders")) "ticket" else "pass"
                        File(instrumentation.targetContext.cacheDir, "payment-popup-$name.png").outputStream().use {
                            screenshot.compress(Bitmap.CompressFormat.PNG, 100, it)
                        }
                        screenshot.recycle()
                    }
                    instrumentation.runOnMainSync {
                        assertEquals("Checkout must remain the opener", "checkout-ready", parent.title)
                        popup!!.evaluateJavascript("window.opener.postMessage('payment-cancelled', '*'); window.close();", null)
                    }
                    await("Provider close did not return to checkout") {
                        parent.title == "payment-cancelled" && popup?.parent == null
                    }
                    instrumentation.runOnMainSync { parent.evaluateJavascript("document.title='checkout-ready'", null) }
                    await("Checkout did not become ready again") { parent.title == "checkout-ready" }
                }
                // Native dismissal must verify the pending attempt, since a
                // closed window alone does not tell us whether payment succeeded.
                requests.clear()
                instrumentation.runOnMainSync { parent.evaluateJavascript("pay()", null) }
                await("Third payment did not open") { popup?.title == "gateway-ready" && popup?.isShown == true }
                if (completionUrl != null) {
                    if (returnViaIntent) {
                        scenario.onActivity { activity ->
                            val launchIntent = activity.intent
                            instrumentation.callActivityOnNewIntent(
                                activity, Intent(Intent.ACTION_VIEW, Uri.parse(completionUrl))
                            )
                            // ActivityScenario identifies its activity by the original intent.
                            activity.intent = launchIntent
                        }
                    } else {
                        instrumentation.runOnMainSync {
                            popup!!.evaluateJavascript("window.location.href='$completionUrl'", null)
                        }
                    }
                } else if (path.startsWith("/orders")) {
                    instrumentation.runOnMainSync {
                        val container = popup!!.parent as ViewGroup
                        val toolbar = container.getChildAt(0) as ViewGroup
                        (toolbar.getChildAt(1) as Button).performClick()
                    }
                } else {
                    instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_BACK)
                }
                await("Payment return left the provider visible") { popup?.parent == null }
                var recoveryLocation: String? = null
                val deadline = SystemClock.uptimeMillis() + 10_000
                while (SystemClock.uptimeMillis() < deadline) {
                    scenario.onActivity { recoveryLocation = it.delegate.currentNavigator?.location }
                    if (recoveryLocation?.contains("/payments/portone/complete?") == true) break
                    SystemClock.sleep(50)
                }
                assertTrue("Payment return must check the pending payment: $recoveryLocation",
                    recoveryLocation?.contains("/payments/portone/complete?paymentId=popup-test") == true)
                if (completionUrl != null) {
                    assertTrue("Pass/event return context was lost: $recoveryLocation",
                        recoveryLocation?.contains("redirect_uri=%2Fevents%2F77") == true)
                    assertTrue("Completion must not trigger a second recovery: $recoveryLocation",
                        recoveryLocation?.contains("native_recovery") == false)
                    assertEquals("The gateway POST must not be replayed", listOf("popup:POST"), requests.toList())
                } else {
                    assertTrue("Native dismissal must recover: $recoveryLocation",
                        recoveryLocation?.contains("native_recovery=1") == true)
                }
            } finally {
                instrumentation.runOnMainSync {
                    (parent.parent as? ViewGroup)?.removeView(parent)
                    parent.destroy()
                }
            }
        }
    }

    private fun response(html: String) = WebResourceResponse("text/html", "UTF-8", html.byteInputStream())

    private fun await(message: String, condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 10_000
        var passed = false
        while (!passed && SystemClock.uptimeMillis() < deadline) {
            instrumentation.runOnMainSync { passed = condition() }
            if (!passed) SystemClock.sleep(50)
        }
        assertTrue("$message; requests=$requests", passed)
    }
}
