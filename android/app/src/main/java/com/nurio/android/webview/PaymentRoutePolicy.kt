package com.nurio.android.webview

import com.nurio.android.LocalePath
internal object PaymentRoutePolicy {
    fun isCheckoutEntryPath(path: String): Boolean {
        val normalized = LocalePath.strip(path)
        return normalized == "/orders/new" ||
            normalized.endsWith("/payment_summary") ||
            normalized.endsWith("/purchase") ||
            EVENT_DETAIL_PATH.matches(normalized) ||
            PASS_PACKAGE_PATH.matches(normalized)
    }

    fun isPaymentCompletionPath(path: String): Boolean = LocalePath.strip(path) == "/payments/portone/complete"

    fun shouldKeepPaymentPopupWebUrl(scheme: String?, paymentActive: Boolean): Boolean {
        return paymentActive && scheme?.lowercase() in WEB_SCHEMES
    }

    private val EVENT_DETAIL_PATH = Regex("^/events/[1-9][0-9]*/?$")
    private val PASS_PACKAGE_PATH = Regex("^/pass_packages/?$")
    private val WEB_SCHEMES = setOf("http", "https")
}
