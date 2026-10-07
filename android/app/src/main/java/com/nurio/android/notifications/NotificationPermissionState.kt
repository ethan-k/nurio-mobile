package com.nurio.android.notifications

import android.content.Context
import androidx.core.app.NotificationManagerCompat

object NotificationPermissionState {
    const val GRANTED = "granted"
    const val DENIED = "denied"
    const val NOT_DETERMINED = "not_determined"

    private const val PREFS_NAME = "notification_permission"
    private const val KEY_HAS_REQUESTED = "has_requested_post_notifications"
    private const val TIRAMISU = 33

    fun resolve(enabled: Boolean, sdkInt: Int, hasRequested: Boolean): String = when {
        enabled -> GRANTED
        sdkInt < TIRAMISU -> DENIED
        !hasRequested -> NOT_DETERMINED
        else -> DENIED
    }

    fun current(context: Context): String = resolve(
        enabled = NotificationManagerCompat.from(context).areNotificationsEnabled(),
        sdkInt = android.os.Build.VERSION.SDK_INT,
        hasRequested = hasRequested(context),
    )

    fun markRequested(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_HAS_REQUESTED, true)
            .apply()
    }

    private fun hasRequested(context: Context): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_HAS_REQUESTED, false)
}
