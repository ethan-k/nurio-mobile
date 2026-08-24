package com.nurio.study.android.payments

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentCrashContextTest {
    @Test
    fun `hashes references and clears persistent payment state`() {
        val reporter = FakeReporter()
        val context = PaymentCrashContext(reporter)

        context.track("payment_requested", "study_group", "payment-123", "webview", "none", false)

        assertEquals("0220adf67b8fcdc0", reporter.values["payment_reference"])
        assertFalse(reporter.values.values.contains("payment-123"))

        context.track("flow_finished", null, null, null, null, false)
        assertEquals(false, reporter.values["payment_flow_active"])
        assertEquals("none", reporter.values["payment_reference"])
    }

    @Test
    fun `reporter failures cannot escape into checkout`() {
        val context = PaymentCrashContext(ThrowingReporter())

        context.reset()
        context.track("gateway_handoff", "study_group", "payment-123", "webview", "sdk_request", true)

        assertTrue(context.isActive())
    }

    private class FakeReporter : PaymentCrashReporter {
        val values = mutableMapOf<String, Any>()
        override fun setBoolean(key: String, value: Boolean) { values[key] = value }
        override fun setString(key: String, value: String) { values[key] = value }
        override fun log(message: String) = Unit
        override fun record(exception: Throwable) = Unit
    }

    private class ThrowingReporter : PaymentCrashReporter {
        override fun setBoolean(key: String, value: Boolean) = throw IllegalStateException("offline")
        override fun setString(key: String, value: String) = throw IllegalStateException("offline")
        override fun log(message: String) = throw IllegalStateException("offline")
        override fun record(exception: Throwable) = throw IllegalStateException("offline")
    }
}
