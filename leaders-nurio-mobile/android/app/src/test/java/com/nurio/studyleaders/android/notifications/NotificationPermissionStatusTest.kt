package com.nurio.studyleaders.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationPermissionStatusTest {
    @Test
    fun enabledNotificationsAreGranted() {
        assertEquals(
            NotificationPermissionStatus.GRANTED,
            NotificationPermissionStatus.resolve(notificationsEnabled = true, sdkInt = 34, hasRequested = false)
        )
    }

    @Test
    fun disabledBeforeAndroid13IsDenied() {
        assertEquals(
            NotificationPermissionStatus.DENIED,
            NotificationPermissionStatus.resolve(notificationsEnabled = false, sdkInt = 32, hasRequested = false)
        )
    }

    @Test
    fun disabledOnAndroid13WithoutPriorRequestIsNotDetermined() {
        assertEquals(
            NotificationPermissionStatus.NOT_DETERMINED,
            NotificationPermissionStatus.resolve(notificationsEnabled = false, sdkInt = 33, hasRequested = false)
        )
    }

    @Test
    fun disabledOnAndroid13AfterRequestIsDenied() {
        assertEquals(
            NotificationPermissionStatus.DENIED,
            NotificationPermissionStatus.resolve(notificationsEnabled = false, sdkInt = 34, hasRequested = true)
        )
    }

    @Test
    fun jsonUsesWireValues() {
        assertEquals("""{"status":"not_determined"}""", NotificationPermissionStatus.NOT_DETERMINED.json)
        assertEquals("""{"status":"granted"}""", NotificationPermissionStatus.GRANTED.json)
        assertEquals("""{"status":"denied"}""", NotificationPermissionStatus.DENIED.json)
    }
}
