package com.nurio.studyleaders.android.notifications

enum class NotificationPermissionStatus(val wireValue: String) {
    GRANTED("granted"),
    DENIED("denied"),
    NOT_DETERMINED("not_determined");

    val json: String
        get() = """{"status":"$wireValue"}"""

    companion object {
        private const val ANDROID_13 = 33

        fun resolve(
            notificationsEnabled: Boolean,
            sdkInt: Int,
            hasRequested: Boolean
        ): NotificationPermissionStatus = when {
            notificationsEnabled -> GRANTED
            sdkInt < ANDROID_13 -> DENIED
            !hasRequested -> NOT_DETERMINED
            else -> DENIED
        }
    }
}
