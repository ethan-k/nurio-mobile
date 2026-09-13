package com.nurio.android.webview

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.os.Message
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.net.toUri
import com.nurio.android.payments.PaymentRecovery
import com.nurio.android.payments.findPaymentRecoveryHost
import dev.hotwire.core.turbo.session.Session
import dev.hotwire.core.turbo.webview.HotwireWebChromeClient

class PaymentWebChromeClient(session: Session) : HotwireWebChromeClient(session) {
    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreateWindow(
        webView: WebView,
        isDialog: Boolean,
        isUserGesture: Boolean,
        resultMsg: Message?
    ): Boolean {
        val transport = resultMsg?.obj as? WebView.WebViewTransport
            ?: return super.onCreateWindow(webView, isDialog, isUserGesture, resultMsg)

        val popup = WebView(webView.context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.userAgentString = webView.settings.userAgentString
            PaymentWebViewCompatibility.configure(this)
        }
        val window = PaymentPopupWindow(webView, popup)
        popup.webViewClient = PaymentPopupWebViewClient(webView, window)
        popup.webChromeClient = object : HotwireWebChromeClient(session) {
            override fun onCloseWindow(windowToClose: WebView) {
                window.close()
            }

            override fun onCreateWindow(webView: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message?): Boolean {
                return this@PaymentWebChromeClient.onCreateWindow(webView, isDialog, isUserGesture, resultMsg)
            }
        }

        // Some providers write their payment UI into about:blank instead of
        // navigating the child. Those windows must also be visible.
        if (PaymentNavigation.isPaymentContext(webView.url) || PaymentRecovery.hasActiveAttempt()) {
            window.show(webView.url?.toUri()?.host.orEmpty())
        }

        transport.webView = popup
        resultMsg.sendToTarget()
        return true
    }
}

private class PaymentPopupWebViewClient(
    private val parentWebView: WebView,
    private val window: PaymentPopupWindow,
) : WebViewClient() {
    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        if (!request.isForMainFrame) return false
        return routePopupLocation(view, request.url.toString())
    }

    @Deprecated("Deprecated in Java")
    override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
        return routePopupLocation(view, url)
    }

    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
        PaymentWebViewCompatibility.injectRuntimeFallback(view, url)
        // POST navigations skip shouldOverrideUrlLoading. Display the original
        // child WebView here; loading this URL in the parent would lose the body
        // and sever window.opener / postMessage / window.close.
        routePopupLocation(view, url)
    }

    private fun routePopupLocation(popupWebView: WebView, location: String): Boolean {
        val uri = location.toUri()
        if (PaymentNavigation.isIgnoredUrl(uri)) return false

        if (PaymentNavigation.shouldStayInWebView(uri, parentWebView.url) ||
            PaymentRoutePolicy.shouldKeepPaymentPopupWebUrl(uri.scheme, PaymentRecovery.hasActiveAttempt())) {
            window.show(uri.host.orEmpty())
            return false
        }

        val externalOutcome = PaymentNavigation.openExternalPaymentApp(parentWebView.context, uri)
        if (externalOutcome.consumed) {
            if (externalOutcome.webFallbackUrl != null) {
                popupWebView.loadUrl(externalOutcome.webFallbackUrl)
            } else if (!externalOutcome.launched) {
                window.close()
                parentWebView.context.findPaymentRecoveryHost()?.onExternalPaymentLaunchFailed()
            }
            // Keep the child alive while the bank app is open so it can resume
            // its own session and communicate with the checkout opener.
            return true
        }

        if (PaymentNavigation.openExternalWebUrl(parentWebView.context, uri)) {
            window.close()
            return true
        }
        return false
    }
}
