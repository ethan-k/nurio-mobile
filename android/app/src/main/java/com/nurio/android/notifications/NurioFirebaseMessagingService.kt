package com.nurio.android.notifications

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.nurio.android.BuildConfig
import com.nurio.android.MainActivity
import com.nurio.android.R
import kotlin.math.absoluteValue

class NurioFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val chat = ChatPush.from(
            message.data,
            fallbackTitle = getString(R.string.app_name),
            now = System.currentTimeMillis(),
        )
        if (chat != null) {
            showChatNotification(chat, message.messageId ?: "${message.sentTime}:${chat.tag}")
            return
        }

        val title = message.notification?.title
            ?: message.data["title"]
            ?: getString(R.string.app_name)
        val body = message.notification?.body
            ?: message.data["body"]
            ?: return
        val path = message.data["path"] ?: "/"
        val tag = message.data["tag"] ?: path
        val notificationId = message.messageId ?: "${message.sentTime}:$tag"

        showNotification(
            title = title,
            body = body,
            path = path,
            tag = tag,
            notificationId = notificationId,
        )
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "FCM token refreshed")
    }

    /**
     * Every message of a room lands in one MessagingStyle notification keyed by the room
     * tag: the style already on screen is recovered and the new message appended, so a
     * busy room stacks instead of each push replacing the last.
     */
    private fun showChatNotification(chat: ChatPush, notificationId: String) {
        if (NotificationRoute.isShowing(chat.path, VisibleWebLocation.current, BuildConfig.BASE_URL)) return

        NotificationChannels.ensureCreated(this)

        val id = chat.tag.hashCode().absoluteValue
        val style = activeMessagingStyle(chat.tag, id)
            ?: NotificationCompat.MessagingStyle(
                Person.Builder().setName(getString(R.string.chat_notification_self_name)).build()
            )
        style.conversationTitle = chat.title
        style.isGroupConversation = chat.senderName != chat.title
        style.addMessage(chat.body, chat.sentAtMillis, Person.Builder().setName(chat.senderName).build())

        val notification = NotificationCompat.Builder(this, NotificationChannels.DEFAULT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(chat.title)
            .setContentText(chat.body)
            .setStyle(style)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setWhen(chat.sentAtMillis)
            .setShowWhen(true)
            .setContentIntent(contentIntent(chat.path, chat.tag, notificationId))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        post(chat.tag, id, notification)
    }

    private fun activeMessagingStyle(tag: String, id: Int): NotificationCompat.MessagingStyle? {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return null
        val active = manager.activeNotifications.firstOrNull { it.tag == tag && it.id == id } ?: return null
        return NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(active.notification)
    }

    private fun contentIntent(path: String, tag: String, notificationId: String): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("path", path)
            putExtra(MainActivity.EXTRA_NOTIFICATION_ID, notificationId)
        }

        return PendingIntent.getActivity(
            this,
            tag.hashCode().absoluteValue,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun post(tag: String, id: Int, notification: Notification) {
        try {
            NotificationManagerCompat.from(this).notify(tag, id, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification permission was not granted", e)
        }
    }

    private fun showNotification(
        title: String,
        body: String,
        path: String,
        tag: String,
        notificationId: String,
    ) {
        NotificationChannels.ensureCreated(this)

        val pendingIntent = contentIntent(path, tag, notificationId)

        val notification = NotificationCompat.Builder(this, NotificationChannels.DEFAULT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        post(tag, tag.hashCode().absoluteValue, notification)
    }

    companion object {
        private const val TAG = "NurioFCM"
    }
}
