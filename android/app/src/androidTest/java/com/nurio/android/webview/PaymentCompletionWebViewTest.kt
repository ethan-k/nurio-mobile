package com.nurio.android.webview

import android.graphics.Bitmap
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ActivityScenario
import androidx.lifecycle.Lifecycle
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

    @Test
    fun returningFromPaymentAppPreservesGatewayUntilItsDelayedCallback() =
        exerciseReturn("nurio://payment-complete", resumeBeforeCallback = true)

    @Test
    fun externalCallbackIntentRestoresStoppedActivity() =
        exerciseReturn("nurio://payment-complete", callbackIntentWhileStopped = true)

    @Test
    fun userCanCheckStatusWhenTheProviderDoesNotReturnAResult() =
        exerciseReturn("nurio://payment-complete", resumeBeforeCallback = true, manualStatusCheck = true)

    @Test
    fun kakaoPayBridgeStaysInThePaymentWebView() =
        exerciseReturn("nurio://payment-complete", providerBridge = true)

    private fun exerciseReturn(
        callbackBase: String,
        resumeBeforeCallback: Boolean = false,
        callbackIntentWhileStopped: Boolean = false,
        manualStatusCheck: Boolean = false,
        providerBridge: Boolean = false,
    ) {
        val query = "?paymentId=completion-test&redirect_uri=%2Fevents%2F77"
        val destinationQuery = if (manualStatusCheck)
            "?paymentId=completion-test&native_recovery=1&redirect_uri=%2Fevents%2F77" else query
        val destination = "${BuildConfig.BASE_URL}/payments/portone/complete$destinationQuery"
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var activity: MainActivity
            lateinit var launchIntent: Intent
            scenario.onActivity { activity = it; launchIntent = it.intent }
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
                        val html = if (request.url.host in setOf("sandbox.inicis.com", "online-payment.kakaopay.com")) {
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

            val bridgeUrl = "https://online-payment.kakaopay.com/bridge/mobile-web/regression"
            if (providerBridge) {
                instrumentation.runOnMainSync {
                    session.webView.evaluateJavascript("window.location.href='$bridgeUrl'", null)
                }
                await("Provider bridge escaped the payment WebView") { session.webView.url == bridgeUrl }
            }

            if (resumeBeforeCallback || callbackIntentWhileStopped) {
                PaymentRecovery.markExternalAppHandoff()
                scenario.moveToState(Lifecycle.State.CREATED)
                if (callbackIntentWhileStopped) {
                    instrumentation.context.startActivity(
                        Intent(activity, MainActivity::class.java)
                            .setAction(Intent.ACTION_VIEW)
                            .setData(Uri.parse("$callbackBase$query"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    await("Callback did not resume the stopped activity") {
                        activity.lifecycle.currentState == Lifecycle.State.RESUMED
                    }
                } else {
                    scenario.moveToState(Lifecycle.State.RESUMED)
                }
            }
            if (resumeBeforeCallback) {
                // Authentication returning to the app is not payment completion.
                // The gateway may need longer than the old two-second recovery timer.
                SystemClock.sleep(3_000)
                instrumentation.runOnMainSync {
                    assertEquals("Recovery must not replace a gateway still confirming payment",
                        "https://sandbox.inicis.com/payment", session.webView.url)
                    assertTrue(PaymentRecovery.hasPendingExternalAppHandoff())
                }
            }
            instrumentation.runOnMainSync {
                if (manualStatusCheck) {
                    val action = activity.findViewById<View>(com.google.android.material.R.id.snackbar_action)
                    assertTrue("A delayed result must offer an explicit status check", action?.isShown == true)
                    action.performClick()
                } else if (!callbackIntentWhileStopped) {
                    assertTrue("Reproduce a warm session whose gateway document lacks Turbo", session.isReady)
                    session.webView.evaluateJavascript("window.location.href='$callbackBase$query'", null)
                }
            }
            await("Completion never loaded after the gateway POST") {
                session.webView.title == "payment-verified" && requests.contains("GET:$destination")
            }
            val progressId = activity.resources.getIdentifier(
                "hotwire_progress_container", "id", BuildConfig.APPLICATION_ID)
            await("Native loading overlay still covers the payment result") {
                activity.findViewById<View>(progressId)?.visibility == View.GONE
            }
            assertEquals(
                "Only the merchant completion may be loaded again; never replay the gateway POST as GET",
                buildList {
                    add("POST:https://sandbox.inicis.com/payment")
                    if (providerBridge) add("GET:$bridgeUrl")
                    add("GET:$destination")
                },
                requests.toList(),
            )
            if (callbackIntentWhileStopped) {
                // onNewIntent replaces Activity.intent. ActivityScenario matches
                // its launch intent when tracking lifecycle events for teardown.
                instrumentation.runOnMainSync {
                    activity.intent = launchIntent
                    activity.finish()
                }
                await("Returned activity did not finish") { activity.isDestroyed }
            }
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
        window.turboNative = { visitRenderedForColdBoot: function(identifier) {
            TurboSession.visitRendered(identifier);
            TurboSession.visitCompleted(identifier, 'payment-result');
        } };
        TurboSession.turboIsReady(true);
    </script>"""
}
