package com.nurio.android.notifications

import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.nurio.android.MainActivity
import com.nurio.android.R
import kotlin.math.absoluteValue

class NurioFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.notification?.title
            ?: message.data["title"]
            ?: getString(R.string.app_name)
        val body = message.notification?.body
            ?: message.data["body"]
            ?: return
        val path = message.data["path"] ?: "/"
        val tag = message.data["tag"] ?: path

        showNotification(title = title, body = body, path = path, tag = tag)
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "FCM token refreshed")
    }

    private fun showNotification(title: String, body: String, path: String, tag: String) {
        NotificationChannels.ensureCreated(this)

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("path", path)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            tag.hashCode().absoluteValue,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NotificationChannels.DEFAULT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(tag, tag.hashCode().absoluteValue, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification permission was not granted", e)
        }
    }

    companion object {
        private const val TAG = "NurioFCM"
    }
}
