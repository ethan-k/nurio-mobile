package com.nurio.android.bridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log
import com.nurio.android.notifications.NotificationPermissionRequester
import com.nurio.android.notifications.NotificationPermissionState
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

class NotificationPermissionComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {
    companion object {
        private const val TAG = "NotificationPermission"
    }

    override fun onReceive(message: Message) {
        when (message.event) {
            "status" -> replyWithCurrentStatus(message)
            "request" -> handleRequest(message)
            "open_settings" -> handleOpenSettings(message)
            else -> Log.w(TAG, "Unknown event: ${message.event}")
        }
    }

    private fun handleRequest(message: Message) {
        val activity = bridgeDelegate.destination.fragment.activity
        if (activity == null) {
            replyWithCurrentStatus(message)
            return
        }
        if (NotificationPermissionState.current(activity) != NotificationPermissionState.NOT_DETERMINED) {
            replyWithCurrentStatus(message)
            return
        }
        val requester = activity as? NotificationPermissionRequester
        if (requester == null) {
            replyWithCurrentStatus(message)
            return
        }
        requester.requestNotificationPermission { replyWithCurrentStatus(message) }
    }

    private fun handleOpenSettings(message: Message) {
        val context = bridgeDelegate.destination.fragment.context
        if (context != null) {
            openSettings(context)
        }
        replyWithCurrentStatus(message)
    }

    private fun openSettings(context: Context) {
        val notificationSettings = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(notificationSettings)
        } catch (e: Exception) {
            Log.w(TAG, "Notification settings unavailable, falling back to app details", e)
            val appDetails = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", context.packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(appDetails)
            } catch (fallback: Exception) {
                Log.w(TAG, "Unable to open app settings", fallback)
            }
        }
    }

    private fun replyWithCurrentStatus(message: Message) {
        val context = bridgeDelegate.destination.fragment.context
        val status = if (context != null) {
            NotificationPermissionState.current(context)
        } else {
            NotificationPermissionState.DENIED
        }
        replyWith(
            message.replacing(
                jsonData = Json.encodeToString(StatusData.serializer(), StatusData(status))
            )
        )
    }

    @Serializable
    data class StatusData(
        @SerialName("status") val status: String
    )
}
