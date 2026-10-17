package com.nurio.android.notifications

/**
 * The location of the web screen the member is looking at, or null while the app is
 * not in the foreground. Written on the main thread by MainActivity, read by the FCM
 * service thread to drop chat pushes for the room already on screen.
 */
internal object VisibleWebLocation {
    @Volatile
    var current: String? = null
}
