package com.nurio.study.android.bridge

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import com.nurio.study.android.BuildConfig
import com.nurio.study.android.notifications.NotificationPermissionHost
import com.nurio.study.android.notifications.PushRegistrationError
import com.nurio.study.android.notifications.PushRegistrationResult
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination

class RegisterDeviceTokenComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {
    override fun onReceive(message: Message) {
        if (message.event != "connect") {
            Log.w(TAG, "Ignoring unknown push bridge event")
            return
        }

        if (!BuildConfig.FIREBASE_CONFIGURED) {
            reply(message, PushRegistrationResult.failure(PushRegistrationError.FIREBASE_NOT_CONFIGURED))
            return
        }

        val permissionHost = delegate.destination.fragment.activity as? NotificationPermissionHost
        if (permissionHost == null) {
            reply(message, PushRegistrationResult.failure(PushRegistrationError.NOTIFICATION_PERMISSION_FAILED))
            return
        }

        permissionHost.requestNotificationPermission { granted ->
            if (!granted) {
                reply(message, PushRegistrationResult.failure(PushRegistrationError.NOTIFICATION_PERMISSION_DENIED))
                return@requestNotificationPermission
            }

            requestToken(message)
        }
    }

    private fun requestToken(message: Message) {
        runCatching { FirebaseMessaging.getInstance().token }
            .onFailure {
                Log.w(TAG, "FCM token request could not start")
                reply(message, PushRegistrationResult.failure(PushRegistrationError.TOKEN_UNAVAILABLE))
            }
            .onSuccess { tokenTask ->
                tokenTask.addOnCompleteListener { task ->
                    if (!task.isSuccessful) {
                        Log.w(TAG, "FCM token request failed")
                        reply(message, PushRegistrationResult.failure(PushRegistrationError.TOKEN_UNAVAILABLE))
                        return@addOnCompleteListener
                    }

                    reply(message, PushRegistrationResult.fromToken(task.result))
                }
            }
    }

    private fun reply(message: Message, result: PushRegistrationResult) {
        replyWith(message.replacing(jsonData = result.json))
    }

    companion object {
        private const val TAG = "StudyPushBridge"
    }
}
