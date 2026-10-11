package com.nurio.study.android.aitutor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.nurio.study.android.R

/**
 * Keeps the process (and microphone access) alive while a class-review call is backgrounded.
 * The call itself lives in [AiTutorCallController]; this service only holds the ongoing
 * notification for its duration.
 */
class AiTutorCallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val promoted = runCatching {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                buildNotification(),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                } else {
                    0
                }
            )
        }.onFailure { Log.w(TAG, "Could not keep the class review call in the foreground", it) }

        if (promoted.isFailure || !AiTutorCallController.isActive) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        ensureChannel(this)
        val openCall = PendingIntent.getActivity(
            this,
            0,
            AiTutorCallActivity.intent(this).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(getString(R.string.ai_tutor_call_notification_title))
            .setContentText(getString(R.string.ai_tutor_call_notification_text))
            .setContentIntent(openCall)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    companion object {
        private const val TAG = "AiTutorCallService"
        private const val CHANNEL_ID = "nurio_study_ai_tutor_call"
        private const val NOTIFICATION_ID = 4_201

        fun start(context: Context) {
            runCatching {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, AiTutorCallService::class.java)
                )
            }.onFailure { Log.w(TAG, "Could not start the class review call service", it) }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AiTutorCallService::class.java))
        }

        private fun ensureChannel(context: Context) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.ai_tutor_call_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = context.getString(R.string.ai_tutor_call_notification_channel_description)
                setShowBadge(false)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
