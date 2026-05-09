package com.nurio.android.bridge

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

class RegisterDeviceTokenComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {
    companion object {
        private const val TAG = "DeviceTokenBridge"
    }

    override fun onReceive(message: Message) {
        when (message.event) {
            "connect" -> handleConnect(message)
            else -> Log.w(TAG, "Unknown event: ${message.event}")
        }
    }

    private fun handleConnect(message: Message) {
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    val error = task.exception?.message ?: "FCM token request failed"
                    Log.w(TAG, error, task.exception)
                    reply(message, TokenData(error = error))
                    return@addOnCompleteListener
                }

                val token = task.result
                if (token.isNullOrBlank()) {
                    reply(message, TokenData(error = "FCM token was blank"))
                    return@addOnCompleteListener
                }

                reply(message, TokenData(token = token))
            }
        } catch (e: IllegalStateException) {
            val error = e.message ?: "Firebase is not initialized"
            Log.w(TAG, error, e)
            reply(message, TokenData(error = error))
        }
    }

    private fun reply(message: Message, data: TokenData) {
        replyWith(message.replacing(jsonData = Json.encodeToString(TokenData.serializer(), data)))
    }

    @Serializable
    data class TokenData(
        @SerialName("token") val token: String? = null,
        @SerialName("platform") val platform: String = "android",
        @SerialName("error") val error: String? = null
    )
}
