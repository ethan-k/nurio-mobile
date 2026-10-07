package com.nurio.studyleaders.android.notifications

interface NotificationPermissionHost {
    fun requestNotificationPermission(callback: (Boolean) -> Unit)
    fun notificationPermissionStatus(): NotificationPermissionStatus
    fun openNotificationSettings()
}
