package com.nurio.study.android.notifications

interface NotificationPermissionHost {
    fun requestNotificationPermission(callback: (Boolean) -> Unit)
}
