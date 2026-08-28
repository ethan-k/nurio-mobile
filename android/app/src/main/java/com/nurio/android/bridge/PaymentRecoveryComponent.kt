package com.nurio.android.bridge

import android.util.Log
import com.nurio.android.payments.PaymentRecovery
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class PaymentRecoveryComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>,
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {
    override fun onReceive(message: Message) {
        if (message.event != "track") return

        try {
            val data = message.data<TrackData>() ?: return
            PaymentRecovery.track(
                stage = data.stage,
                paymentReference = data.paymentReference,
                sourceLocation = bridgeDelegate.location,
            )
        } catch (_: Exception) {
            Log.w(TAG, "Payment recovery event ignored")
        }
    }

    @Serializable
    data class TrackData(
        @SerialName("stage") val stage: String? = null,
        @SerialName("paymentReference") val paymentReference: String? = null,
    )

    private companion object {
        const val TAG = "PaymentRecovery"
    }
}
