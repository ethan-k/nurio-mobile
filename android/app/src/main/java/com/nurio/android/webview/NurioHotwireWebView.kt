package com.nurio.android.webview

import android.content.Context
import android.graphics.Bitmap
import android.net.http.SslError
import android.util.AttributeSet
import android.webkit.HttpAuthHandler
import android.webkit.RenderProcessGoneDetail
import android.webkit.SslErrorHandler
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebResourceErrorCompat
import androidx.webkit.WebViewClientCompat
import dev.hotwire.core.turbo.webview.HotwireWebView

class NurioHotwireWebView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : HotwireWebView(context, attrs) {
    init {
        settings.javaScriptCanOpenWindowsAutomatically = true
    }

    override fun setWebViewClient(client: WebViewClient) {
        if (client is PaymentAwareWebViewClient) {
            super.setWebViewClient(client)
        } else {
            super.setWebViewClient(PaymentAwareWebViewClient(client))
        }
    }
}

@Suppress("DEPRECATION")
private class PaymentAwareWebViewClient(
    private val delegate: WebViewClient
) : WebViewClientCompat() {
    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        if (PaymentNavigation.shouldStayInWebView(request.url, view.url)) return false
        if (PaymentNavigation.openExternalPaymentApp(view.context, request.url)) return true

        return delegate.shouldOverrideUrlLoading(view, request)
    }

    @Deprecated("Deprecated in Java")
    override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
        val uri = android.net.Uri.parse(url)
        if (PaymentNavigation.shouldStayInWebView(uri, view.url)) return false
        if (PaymentNavigation.openExternalPaymentApp(view.context, uri)) return true

        return delegate.shouldOverrideUrlLoading(view, url)
    }

    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
        delegate.onPageStarted(view, url, favicon)
    }

    override fun onPageFinished(view: WebView, url: String) {
        delegate.onPageFinished(view, url)
    }

    override fun onPageCommitVisible(view: WebView, url: String) {
        delegate.onPageCommitVisible(view, url)
    }

    override fun onScaleChanged(view: WebView, oldScale: Float, newScale: Float) {
        delegate.onScaleChanged(view, oldScale, newScale)
    }

    override fun shouldInterceptRequest(
        view: WebView,
        request: WebResourceRequest
    ): WebResourceResponse? {
        return delegate.shouldInterceptRequest(view, request)
    }

    @Deprecated("Deprecated in Java")
    override fun shouldInterceptRequest(view: WebView, url: String): WebResourceResponse? {
        return delegate.shouldInterceptRequest(view, url)
    }

    override fun onReceivedHttpAuthRequest(
        view: WebView,
        handler: HttpAuthHandler,
        host: String,
        realm: String
    ) {
        delegate.onReceivedHttpAuthRequest(view, handler, host, realm)
    }

    @Deprecated("Deprecated in Java")
    override fun onReceivedError(
        view: WebView,
        errorCode: Int,
        description: String,
        failingUrl: String
    ) {
        delegate.onReceivedError(view, errorCode, description, failingUrl)
    }

    override fun onReceivedError(
        view: WebView,
        request: WebResourceRequest,
        error: WebResourceErrorCompat
    ) {
        if (delegate is WebViewClientCompat) {
            delegate.onReceivedError(view, request, error)
        } else {
            super.onReceivedError(view, request, error)
        }
    }

    override fun onReceivedHttpError(
        view: WebView,
        request: WebResourceRequest,
        errorResponse: WebResourceResponse
    ) {
        delegate.onReceivedHttpError(view, request, errorResponse)
    }

    override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
        delegate.onReceivedSslError(view, handler, error)
    }

    override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
        return delegate.onRenderProcessGone(view, detail)
    }
}
