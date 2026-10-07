package com.nurio.study.android.notifications

enum class NotificationPermissionStatus(val wireValue: String) {
    GRANTED("granted"),
    DENIED("denied"),
    NOT_DETERMINED("not_determined");

    val json: String
        get() = "{\"status\":\"$wireValue\"}"

    companion object {
        private const val POST_NOTIFICATIONS_MIN_SDK = 33

        fun resolve(notificationsEnabled: Boolean, sdkInt: Int, hasRequested: Boolean): NotificationPermissionStatus =
            when {
                notificationsEnabled -> GRANTED
                sdkInt < POST_NOTIFICATIONS_MIN_SDK -> DENIED
                !hasRequested -> NOT_DETERMINED
                else -> DENIED
            }
    }
}
