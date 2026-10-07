package com.nurio.study.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationPermissionStatusTest {
    @Test
    fun `enabled notifications are granted`() {
        assertEquals(
            NotificationPermissionStatus.GRANTED,
            NotificationPermissionStatus.resolve(notificationsEnabled = true, sdkInt = 34, hasRequested = false)
        )
    }

    @Test
    fun `disabled notifications before Android 13 are denied`() {
        assertEquals(
            NotificationPermissionStatus.DENIED,
            NotificationPermissionStatus.resolve(notificationsEnabled = false, sdkInt = 32, hasRequested = false)
        )
    }

    @Test
    fun `disabled notifications never requested on Android 13 are not determined`() {
        assertEquals(
            NotificationPermissionStatus.NOT_DETERMINED,
            NotificationPermissionStatus.resolve(notificationsEnabled = false, sdkInt = 33, hasRequested = false)
        )
    }

    @Test
    fun `disabled notifications after a request on Android 13 are denied`() {
        assertEquals(
            NotificationPermissionStatus.DENIED,
            NotificationPermissionStatus.resolve(notificationsEnabled = false, sdkInt = 33, hasRequested = true)
        )
    }

    @Test
    fun `serializes the wire status`() {
        assertEquals("{\"status\":\"not_determined\"}", NotificationPermissionStatus.NOT_DETERMINED.json)
        assertEquals("{\"status\":\"granted\"}", NotificationPermissionStatus.GRANTED.json)
        assertEquals("{\"status\":\"denied\"}", NotificationPermissionStatus.DENIED.json)
    }
}
