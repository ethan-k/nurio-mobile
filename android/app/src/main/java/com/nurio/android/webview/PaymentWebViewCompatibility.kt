package com.nurio.android.webview

import android.webkit.WebView
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature

object PaymentWebViewCompatibility {
    private val inicisOrigins = setOf(
        "https://inicis.com",
        "https://*.inicis.com"
    )

    // KG Inicis' nProtect script still calls this obsolete Netscape API path.
    private const val INICIS_CRYPTO_RANDOM_SHIM = """
        (function() {
          if (!window.crypto ||
              typeof window.crypto.random === "function" ||
              typeof window.crypto.getRandomValues !== "function") {
            return;
          }

          var random = function(length) {
            var size = Number(length) || 0;
            if (size < 0) size = 0;

            var bytes = new Uint8Array(size);
            window.crypto.getRandomValues(bytes);

            var result = "";
            for (var index = 0; index < bytes.length; index += 1) {
              result += String.fromCharCode(bytes[index]);
            }
            return result;
          };

          try {
            Object.defineProperty(window.crypto, "random", {
              configurable: true,
              enumerable: false,
              writable: true,
              value: random
            });
          } catch (_) {
            window.crypto.random = random;
          }
        })();
    """

    fun configure(webView: WebView) {
        webView.settings.javaScriptCanOpenWindowsAutomatically = true
        webView.settings.setSupportMultipleWindows(true)

        if (!WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) return

        WebViewCompat.addDocumentStartJavaScript(
            webView,
            INICIS_CRYPTO_RANDOM_SHIM,
            inicisOrigins
        )
    }

    fun injectRuntimeFallback(webView: WebView, url: String?) {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) return
        if (!PaymentNavigation.isPaymentContext(url)) return

        webView.evaluateJavascript(INICIS_CRYPTO_RANDOM_SHIM, null)
    }
}
