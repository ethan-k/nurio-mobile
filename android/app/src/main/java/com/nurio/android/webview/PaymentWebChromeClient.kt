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
            webViewClient = PaymentPopupWebViewClient(webView)
        }

        transport.webView = popup
        resultMsg.sendToTarget()
        return true
    }
}

private class PaymentPopupWebViewClient(
    private val parentWebView: WebView
) : WebViewClient() {
    private var routed = false

    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        routePopupLocation(view, request.url.toString())
        return true
    }

    @Deprecated("Deprecated in Java")
    override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
        routePopupLocation(view, url)
        return true
    }

    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
        PaymentWebViewCompatibility.injectRuntimeFallback(view, url)
        routePopupLocation(view, url)
    }

    private fun routePopupLocation(popupWebView: WebView, location: String) {
        if (routed) return

        val uri = location.toUri()

        if (PaymentNavigation.isIgnoredUrl(uri)) return

        if (PaymentNavigation.shouldStayInWebView(uri, parentWebView.url)) {
            routed = true
            parentWebView.loadUrl(location)
            popupWebView.destroy()
            return
        }

        if (PaymentRoutePolicy.shouldKeepPaymentPopupWebUrl(uri.scheme, PaymentRecovery.hasActiveAttempt())) {
            routed = true
            parentWebView.loadUrl(location)
            popupWebView.destroy()
            return
        }

        val externalOutcome = PaymentNavigation.openExternalPaymentApp(parentWebView.context, uri)
        if (externalOutcome.consumed) {
            routed = true
            if (externalOutcome.webFallbackUrl != null) {
                parentWebView.loadUrl(externalOutcome.webFallbackUrl)
            } else if (!externalOutcome.launched) {
                parentWebView.context.findPaymentRecoveryHost()?.onExternalPaymentLaunchFailed()
            }
            popupWebView.destroy()
            return
        }

        if (PaymentNavigation.openExternalWebUrl(parentWebView.context, uri)) {
            routed = true
            popupWebView.destroy()
        }
    }
}
