package com.nurio.studyleaders.android.bridge

import android.util.Log
import com.nurio.studyleaders.android.notifications.NotificationPermissionHost
import com.nurio.studyleaders.android.notifications.NotificationPermissionStatus
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
                host.openNotificationSettings()
                reply(message, host.notificationPermissionStatus())
            }
            else -> Log.w(TAG, "Ignoring unknown notification permission event")
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

    private fun reply(message: Message, status: NotificationPermissionStatus) {
        replyWith(message.replacing(jsonData = status.json))
    }

    companion object {
        private const val TAG = "LeaderNotifPermission"
    }
}
