package com.nurio.android.webview

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentRoutePolicyTest {
    @Test
    fun `recognizes direct event detail checkout without matching event list`() {
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/events/42"))
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/events/42/"))
        assertFalse(PaymentRoutePolicy.isCheckoutEntryPath("/events"))
        assertFalse(PaymentRoutePolicy.isCheckoutEntryPath("/events/new"))
    }

    @Test
    fun `recognizes pass package pages used by direct checkout`() {
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/pass_packages"))
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/pass_packages/"))
        assertFalse(PaymentRoutePolicy.isCheckoutEntryPath("/pass_packages/3"))
        assertFalse(PaymentRoutePolicy.isCheckoutEntryPath("/pass_packages/history"))
    }

    @Test
    fun `preserves existing checkout entry paths`() {
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/orders/new"))
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/orders/1/payment_summary"))
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/pass_packages/1/purchase"))
        assertFalse(PaymentRoutePolicy.isCheckoutEntryPath("/orders/1"))
    }

    @Test
    fun `only explicitly marked completion is a native recovery entry`() {
        assertTrue(
            PaymentRoutePolicy.isNativeRecoveryEntry(
                path = "/payments/portone/complete",
                recoveryMarker = "1",
            )
        )
        assertFalse(
            PaymentRoutePolicy.isNativeRecoveryEntry(
                path = "/payments/portone/complete",
                recoveryMarker = null,
            )
        )
        assertFalse(
            PaymentRoutePolicy.isNativeRecoveryEntry(
                path = "/events/42",
                recoveryMarker = "1",
            )
        )
    }

    @Test
    fun `web intermediaries stay in the popup only during an active payment`() {
        assertTrue(PaymentRoutePolicy.shouldKeepPaymentPopupWebUrl("https", paymentActive = true))
        assertTrue(PaymentRoutePolicy.shouldKeepPaymentPopupWebUrl("http", paymentActive = true))
        assertFalse(PaymentRoutePolicy.shouldKeepPaymentPopupWebUrl("https", paymentActive = false))
        assertFalse(PaymentRoutePolicy.shouldKeepPaymentPopupWebUrl("intent", paymentActive = true))
    }
}
