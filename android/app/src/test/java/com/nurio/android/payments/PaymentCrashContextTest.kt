package com.nurio.android.payments

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentCrashContextTest {
    @Test
    fun `tracks allowlisted state and hashes the payment reference`() {
        val reporter = FakeReporter()
        val context = PaymentCrashContext(reporter, appSurface = "nurio")

        context.track(
            stageValue = "payment_requested",
            orderKindValue = "study_group",
            paymentReference = "payment-123",
            handoffValue = "webview",
            failureKindValue = "none",
            reportNonfatal = false,
        )

        assertEquals(true, reporter.values["payment_flow_active"])
        assertEquals("payment_requested", reporter.values["payment_stage"])
        assertEquals("study_group", reporter.values["payment_order_kind"])
        assertEquals("0220adf67b8fcdc0", reporter.values["payment_reference"])
        assertFalse(reporter.values.values.contains("payment-123"))
        assertTrue(reporter.exceptions.isEmpty())
    }

    @Test
    fun `reports a classified technical failure without raw exception data`() {
        val reporter = FakeReporter()
        val context = PaymentCrashContext(reporter, appSurface = "nurio")

        context.track(
            stageValue = "gateway_handoff",
            orderKindValue = "ticket",
            paymentReference = "secret-reference",
            handoffValue = "webview",
            failureKindValue = "sdk_request",
            reportNonfatal = true,
        )

        assertEquals("sdk_request", reporter.values["payment_failure_kind"])
        assertEquals("payment_failure:sdk_request", reporter.exceptions.single().message)
        assertFalse(reporter.exceptions.single().message.orEmpty().contains("secret-reference"))
    }

    @Test
    fun `flow finish clears all persistent payment keys`() {
        val reporter = FakeReporter()
        val context = PaymentCrashContext(reporter, appSurface = "nurio")
        context.markCallbackReceived("payment-123")

        context.track("flow_finished", null, null, null, null, false)

        assertEquals(false, reporter.values["payment_flow_active"])
        assertEquals("none", reporter.values["payment_stage"])
        assertEquals("none", reporter.values["payment_reference"])
        assertEquals("none", reporter.values["payment_provider"])
        assertEquals("none", reporter.values["payment_failure_kind"])
    }

    @Test
    fun `reporter failures never escape into the payment caller`() {
        val context = PaymentCrashContext(ThrowingReporter(), appSurface = "nurio")

        context.reset()
        context.track("payment_requested", "ticket", "payment-123", "webview", "none", false)
        context.reportTechnicalFailure(PaymentFailureKind.SDK_REQUEST)

        assertTrue(context.isActive())
    }

    private class FakeReporter : PaymentCrashReporter {
        val values = mutableMapOf<String, Any>()
        val logs = mutableListOf<String>()
        val exceptions = mutableListOf<Throwable>()

        override fun setBoolean(key: String, value: Boolean) {
            values[key] = value
        }

        override fun setString(key: String, value: String) {
            values[key] = value
        }

        override fun log(message: String) {
            logs += message
        }

        override fun record(exception: Throwable) {
            exceptions += exception
        }
    }

    private class ThrowingReporter : PaymentCrashReporter {
        override fun setBoolean(key: String, value: Boolean) = throw IllegalStateException("offline")
        override fun setString(key: String, value: String) = throw IllegalStateException("offline")
        override fun log(message: String) = throw IllegalStateException("offline")
        override fun record(exception: Throwable) = throw IllegalStateException("offline")
    }
}
