package com.nurio.android.notifications

interface NotificationPermissionRequester {
    fun requestNotificationPermission(onResolved: () -> Unit)
}
