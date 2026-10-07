package com.nurio.study.android.bridge

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.nurio.study.android.notifications.NotificationPermissionHost
import com.nurio.study.android.notifications.NotificationPermissionStatus
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination

class NotificationPermissionComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {
    override fun onReceive(message: Message) {
        val host = delegate.destination.fragment.activity as? NotificationPermissionHost
        if (host == null) {
            Log.w(TAG, "Notification permission host unavailable")
            return
        }

        when (message.event) {
            "status" -> reply(message, host.notificationPermissionStatus())
            "request" -> request(message, host)
            "open_settings" -> {
                openSettings()
                reply(message, host.notificationPermissionStatus())
            }
            else -> Log.w(TAG, "Ignoring unknown notification permission bridge event")
        }
    }

    private fun request(message: Message, host: NotificationPermissionHost) {
        if (host.notificationPermissionStatus() != NotificationPermissionStatus.NOT_DETERMINED) {
            reply(message, host.notificationPermissionStatus())
            return
        }

        host.requestNotificationPermission {
            reply(message, host.notificationPermissionStatus())
        }
    }

    private fun openSettings() {
        val activity = delegate.destination.fragment.activity ?: return
        val packageName = activity.packageName
        val notificationSettings = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val detailsSettings = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        runCatching { activity.startActivity(notificationSettings) }
            .recoverCatching { activity.startActivity(detailsSettings) }
            .onFailure { Log.w(TAG, "Unable to open notification settings") }
    }

    private fun reply(message: Message, status: NotificationPermissionStatus) {
        replyWith(message.replacing(jsonData = status.json))
    }

    companion object {
        private const val TAG = "StudyNotificationBridge"
    }
}
