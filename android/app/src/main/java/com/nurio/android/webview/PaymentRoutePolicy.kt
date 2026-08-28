package com.nurio.android.webview

internal object PaymentRoutePolicy {
    fun isCheckoutEntryPath(path: String): Boolean {
        return path == "/orders/new" ||
            path.endsWith("/payment_summary") ||
            path.endsWith("/purchase") ||
            EVENT_DETAIL_PATH.matches(path) ||
            PASS_PACKAGE_PATH.matches(path)
    }

    fun isNativeRecoveryEntry(path: String, recoveryMarker: String?): Boolean {
        return path == "/payments/portone/complete" && recoveryMarker == "1"
    }

    fun shouldKeepPaymentPopupWebUrl(scheme: String?, paymentActive: Boolean): Boolean {
        return paymentActive && scheme?.lowercase() in WEB_SCHEMES
    }

    private val EVENT_DETAIL_PATH = Regex("^/events/[1-9][0-9]*/?$")
    private val PASS_PACKAGE_PATH = Regex("^/pass_packages/?$")
    private val WEB_SCHEMES = setOf("http", "https")
}
