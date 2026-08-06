package com.nurio.studyleaders.android.notifications

interface NotificationPermissionHost {
    fun requestNotificationPermission(callback: (Boolean) -> Unit)
}
