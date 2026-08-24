package com.nurio.android.payments

import com.google.firebase.crashlytics.FirebaseCrashlytics
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

internal enum class PaymentStage(val wireValue: String) {
    CHECKOUT_PRESENTED("checkout_presented"),
    SDK_READY("sdk_ready"),
    PAYMENT_REQUESTED("payment_requested"),
    ATTEMPT_REFRESHED("attempt_refreshed"),
    GATEWAY_HANDOFF("gateway_handoff"),
    EXTERNAL_APP_HANDOFF("external_app_handoff"),
    CALLBACK_RECEIVED("callback_received"),
    COMPLETION_VERIFYING("completion_verifying"),
    RETRY_COLD_BOOT("retry_cold_boot"),
    FLOW_FINISHED("flow_finished");

    companion object {
        fun fromWireValue(value: String?): PaymentStage? = entries.firstOrNull { it.wireValue == value }
    }
}

internal enum class PaymentFailureKind(val wireValue: String, val code: Int) {
    NONE("none", 0),
    CONFIGURATION("configuration", 1),
    SDK_LOAD("sdk_load", 2),
    SDK_REQUEST("sdk_request", 3),
    ATTEMPT_REFRESH("attempt_refresh", 4),
    NATIVE_REQUEST("native_request", 5),
    MALFORMED_INTENT("malformed_intent", 6),
    EXTERNAL_APP_UNAVAILABLE("external_app_unavailable", 7),
    EXTERNAL_APP_SECURITY("external_app_security", 8),
    MALFORMED_CALLBACK("malformed_callback", 9),
    RENDERER_TERMINATED("renderer_terminated", 10);

    companion object {
        fun fromWireValue(value: String?): PaymentFailureKind =
            entries.firstOrNull { it.wireValue == value } ?: NONE
    }
}

internal class PaymentTechnicalException(failure: PaymentFailureKind) :
    RuntimeException("payment_failure:${failure.wireValue}")

internal class PaymentCrashContext(
    private val reporter: PaymentCrashReporter,
    private val appSurface: String,
) {
    private var active = false
    private var stage = "none"
    private var orderKind = "unknown"
    private var reference = "none"
    private var handoff = "none"
    private var failureKind = PaymentFailureKind.NONE

    fun reset() {
        active = false
        stage = "none"
        orderKind = "unknown"
        reference = "none"
        handoff = "none"
        failureKind = PaymentFailureKind.NONE
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
        val nextStage = PaymentStage.fromWireValue(stageValue) ?: return
        if (nextStage == PaymentStage.FLOW_FINISHED) {
            safeLog("payment:flow_finished")
            reset()
            return
        }

        active = true
        stage = nextStage.wireValue
        orderKind = sanitizeOrderKind(orderKindValue)
        paymentReference?.takeIf(String::isNotBlank)?.let { reference = hashReference(it) }
        handoff = sanitizeHandoff(handoffValue)
        failureKind = PaymentFailureKind.fromWireValue(failureKindValue)
        applyKeys()
        safeLog("payment:${nextStage.wireValue}")

        if (reportNonfatal && failureKind != PaymentFailureKind.NONE) {
            safeRecord(failureKind)
        }
    }

    fun markExternalAppHandoff() {
        track(
            stageValue = PaymentStage.EXTERNAL_APP_HANDOFF.wireValue,
            orderKindValue = orderKind,
            paymentReference = null,
            handoffValue = "external_app",
            failureKindValue = PaymentFailureKind.NONE.wireValue,
            reportNonfatal = false,
        )
    }

    fun markCallbackReceived(paymentReference: String?) {
        track(
            stageValue = PaymentStage.CALLBACK_RECEIVED.wireValue,
            orderKindValue = orderKind,
            paymentReference = paymentReference,
            handoffValue = "native_callback",
            failureKindValue = PaymentFailureKind.NONE.wireValue,
            reportNonfatal = false,
        )
    }

    fun logRetryColdBoot() {
        if (active) safeLog("payment:${PaymentStage.RETRY_COLD_BOOT.wireValue}")
    }

    fun reportTechnicalFailure(failure: PaymentFailureKind) {
        active = true
        failureKind = failure
        applyKeys()
        safeLog("payment_failure:${failure.wireValue}")
        safeRecord(failure)
    }

    fun reportRendererTermination() {
        if (active) reportTechnicalFailure(PaymentFailureKind.RENDERER_TERMINATED)
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
        safeSetString("app_surface", appSurface)
        safeSetString("native_platform", "android")
        safeSetBoolean("payment_flow_active", active)
        safeSetString("payment_stage", stage)
        safeSetString("payment_order_kind", orderKind)
        safeSetString("payment_reference", reference)
        safeSetString("payment_provider", if (active) "portone_inicis" else "none")
        safeSetString("payment_handoff", handoff)
        safeSetString("payment_failure_kind", failureKind.wireValue)
    }

    private fun safeSetBoolean(key: String, value: Boolean) = bestEffort {
        reporter.setBoolean(key, value)
    }

    private fun safeSetString(key: String, value: String) = bestEffort {
        reporter.setString(key, value)
    }

    private fun safeLog(message: String) = bestEffort { reporter.log(message) }

    private fun safeRecord(failure: PaymentFailureKind) = bestEffort {
        reporter.record(PaymentTechnicalException(failure))
    }

    private inline fun bestEffort(action: () -> Unit) {
        try {
            action()
        } catch (_: Exception) {
            // Crash reporting is optional and must never affect payment behavior.
        }
    }

    private fun sanitizeOrderKind(value: String?): String = when (value) {
        "ticket", "pass_package", "deposit", "study_group", "event_add_on" -> value
        else -> "unknown"
    }

    private fun sanitizeHandoff(value: String?): String = when (value) {
        "webview", "external_app", "native_callback", "none" -> value
        else -> "none"
    }
}

internal object PaymentCrashTelemetry {
    private val context by lazy {
        PaymentCrashContext(
            reporter = FirebasePaymentCrashReporter(),
            appSurface = "nurio",
        )
    }

    fun reset() = bestEffort { context.reset() }

    fun track(
        stage: String?,
        orderKind: String?,
        paymentReference: String?,
        handoff: String?,
        failureKind: String?,
        reportNonfatal: Boolean,
    ) = bestEffort {
        context.track(stage, orderKind, paymentReference, handoff, failureKind, reportNonfatal)
    }

    fun markExternalAppHandoff() = bestEffort { context.markExternalAppHandoff() }
    fun markCallbackReceived(paymentReference: String?) = bestEffort {
        context.markCallbackReceived(paymentReference)
    }
    fun logRetryColdBoot() = bestEffort { context.logRetryColdBoot() }
    fun reportTechnicalFailure(failure: PaymentFailureKind) = bestEffort {
        context.reportTechnicalFailure(failure)
    }
    fun reportRendererTermination() = bestEffort { context.reportRendererTermination() }
    fun isActive(): Boolean = bestEffort(default = false) { context.isActive() }

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
