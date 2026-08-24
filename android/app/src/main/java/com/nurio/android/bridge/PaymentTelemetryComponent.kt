package com.nurio.android.bridge

import android.util.Log
import com.nurio.android.payments.PaymentCrashTelemetry
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class PaymentTelemetryComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>,
) : BridgeComponent<HotwireDestination>(name, delegate) {
    override fun onReceive(message: Message) {
        if (message.event != "track") return

        try {
            val data = message.data<TrackData>() ?: return
            PaymentCrashTelemetry.track(
                stage = data.stage,
                orderKind = data.orderKind,
                paymentReference = data.paymentReference,
                handoff = data.handoff,
                failureKind = data.failureKind,
                reportNonfatal = data.reportNonfatal,
            )
        } catch (_: Exception) {
            Log.w(TAG, "Payment telemetry ignored")
        }
    }

    @Serializable
    data class TrackData(
        @SerialName("stage") val stage: String? = null,
        @SerialName("orderKind") val orderKind: String? = null,
        @SerialName("paymentReference") val paymentReference: String? = null,
        @SerialName("handoff") val handoff: String? = null,
        @SerialName("failureKind") val failureKind: String? = null,
        @SerialName("reportNonfatal") val reportNonfatal: Boolean = false,
    )

    private companion object {
        const val TAG = "PaymentTelemetry"
    }
}
