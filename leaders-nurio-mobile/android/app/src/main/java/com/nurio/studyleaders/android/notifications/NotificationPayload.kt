package com.nurio.studyleaders.android.notifications

object NotificationPayload {
    fun destination(data: Map<String, String>, baseUrl: String): String =
        NotificationDestination.resolve(data["path"], data["url"], baseUrl)
}
