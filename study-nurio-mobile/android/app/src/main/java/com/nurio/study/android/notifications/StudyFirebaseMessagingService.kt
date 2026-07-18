package com.nurio.study.android.notifications

import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.nurio.study.android.BuildConfig
import com.nurio.study.android.MainActivity
import com.nurio.study.android.R

class StudyFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.notification?.title
            ?: message.data["title"]
            ?: getString(R.string.app_name)
        val body = message.notification?.body
            ?: message.data["body"]
            ?: return
        val destination = NotificationPayload.destination(message.data, BuildConfig.BASE_URL)
        val tag = message.data["tag"]?.takeIf(String::isNotBlank) ?: destination

        showNotification(title, body, destination, tag)
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "Study FCM token refreshed")
    }

    private fun showNotification(title: String, body: String, destination: String, tag: String) {
        NotificationChannels.ensureCreated(this)
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.NOTIFICATION_DESTINATION_EXTRA, destination)
        }
        val notificationId = tag.hashCode() and Int.MAX_VALUE
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
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
            NotificationManagerCompat.from(this).notify(tag, notificationId, notification)
        } catch (_: SecurityException) {
            Log.w(TAG, "Study notification permission is unavailable")
        }
    }

    companion object {
        private const val TAG = "StudyFCM"
    }
}
