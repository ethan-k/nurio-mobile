package com.nurio.study.android.payments

import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.nurio.study.android.BuildConfig
import java.security.MessageDigest

internal interface PaymentCrashReporter {
    fun setBoolean(key: String, value: Boolean)
    fun setString(key: String, value: String)
    fun log(message: String)
    fun record(exception: Throwable)
}

private class FirebasePaymentCrashReporter(
    private val crashlytics: FirebaseCrashlytics = FirebaseCrashlytics.getInstance(),
) : PaymentCrashReporter {
    override fun setBoolean(key: String, value: Boolean) = crashlytics.setCustomKey(key, value)
    override fun setString(key: String, value: String) = crashlytics.setCustomKey(key, value)
    override fun log(message: String) = crashlytics.log(message)
    override fun record(exception: Throwable) = crashlytics.recordException(exception)
}

internal class PaymentCrashContext(
    private val reporter: PaymentCrashReporter,
) {
    private var active = false
    private var stage = "none"
    private var orderKind = "unknown"
    private var reference = "none"
    private var handoff = "none"
    private var failureKind = "none"

    fun reset() {
        active = false
        stage = "none"
        orderKind = "unknown"
        reference = "none"
        handoff = "none"
        failureKind = "none"
        applyKeys()
    }

    fun track(
        stageValue: String?,
        orderKindValue: String?,
        paymentReference: String?,
        handoffValue: String?,
        failureKindValue: String?,
        reportNonfatal: Boolean,
    ) {
        val nextStage = stageValue?.takeIf(ALLOWED_STAGES::contains) ?: return
        if (nextStage == "flow_finished") {
            safeLog("payment:flow_finished")
            reset()
            return
        }

        active = true
        stage = nextStage
        orderKind = orderKindValue?.takeIf(ALLOWED_ORDER_KINDS::contains) ?: "unknown"
        paymentReference?.takeIf(String::isNotBlank)?.let { reference = hashReference(it) }
        handoff = handoffValue?.takeIf(ALLOWED_HANDOFFS::contains) ?: "none"
        failureKind = failureKindValue?.takeIf(ALLOWED_FAILURE_KINDS::contains) ?: "none"
        applyKeys()
        safeLog("payment:$nextStage")

        if (reportNonfatal && failureKind != "none") {
            safeRecord(failureKind)
        }
    }

    fun reportNativeRequestFailure() {
        if (!active) return
        failureKind = "native_request"
        applyKeys()
        safeLog("payment_failure:native_request")
        safeRecord(failureKind)
    }

    fun isActive(): Boolean = active

    internal fun hashReference(value: String): String {
        return try {
            MessageDigest.getInstance("SHA-256")
                .digest(value.toByteArray(Charsets.UTF_8))
                .joinToString(separator = "") { byte -> "%02x".format(byte) }
                .take(16)
        } catch (_: Exception) {
            "unavailable"
        }
    }

    private fun applyKeys() {
        safeSetString("app_surface", "nurio_study")
        safeSetString("native_platform", "android")
        safeSetBoolean("payment_flow_active", active)
        safeSetString("payment_stage", stage)
        safeSetString("payment_order_kind", orderKind)
        safeSetString("payment_reference", reference)
        safeSetString("payment_provider", if (active) "portone_inicis" else "none")
        safeSetString("payment_handoff", handoff)
        safeSetString("payment_failure_kind", failureKind)
    }

    private fun safeSetBoolean(key: String, value: Boolean) = bestEffort {
        reporter.setBoolean(key, value)
    }
    private fun safeSetString(key: String, value: String) = bestEffort {
        reporter.setString(key, value)
    }
    private fun safeLog(message: String) = bestEffort { reporter.log(message) }
    private fun safeRecord(failure: String) = bestEffort {
        reporter.record(RuntimeException("payment_failure:$failure"))
    }

    private inline fun bestEffort(action: () -> Unit) {
        try {
            action()
        } catch (_: Exception) {
            // Crash reporting is optional and must never affect payment behavior.
        }
    }

    private companion object {
        val ALLOWED_STAGES = setOf(
            "checkout_presented",
            "sdk_ready",
            "payment_requested",
            "attempt_refreshed",
            "gateway_handoff",
            "external_app_handoff",
            "callback_received",
            "completion_verifying",
            "retry_cold_boot",
            "flow_finished",
        )
        val ALLOWED_ORDER_KINDS = setOf(
            "ticket",
            "pass_package",
            "deposit",
            "study_group",
            "event_add_on",
            "unknown",
        )
        val ALLOWED_HANDOFFS = setOf("webview", "external_app", "native_callback", "none")
        val ALLOWED_FAILURE_KINDS = setOf(
            "none",
            "configuration",
            "sdk_load",
            "sdk_request",
            "attempt_refresh",
            "native_request",
        )
    }
}

internal object PaymentCrashTelemetry {
    private val context by lazy {
        if (BuildConfig.FIREBASE_CONFIGURED) {
            PaymentCrashContext(FirebasePaymentCrashReporter())
        } else {
            null
        }
    }

    fun reset() = bestEffort { context?.reset() }
    fun track(
        stage: String?,
        orderKind: String?,
        paymentReference: String?,
        handoff: String?,
        failureKind: String?,
        reportNonfatal: Boolean,
    ) = bestEffort {
        context?.track(stage, orderKind, paymentReference, handoff, failureKind, reportNonfatal)
    }
    fun reportNativeRequestFailure() = bestEffort { context?.reportNativeRequestFailure() }
    fun isActive(): Boolean = bestEffort(default = false) { context?.isActive() ?: false }

    private inline fun bestEffort(action: () -> Unit) {
        try {
            action()
        } catch (_: Exception) {
            // Firebase initialization/reporting must never affect the app flow.
        }
    }

    private inline fun <T> bestEffort(default: T, action: () -> T): T {
        return try {
            action()
        } catch (_: Exception) {
            default
        }
    }
}
