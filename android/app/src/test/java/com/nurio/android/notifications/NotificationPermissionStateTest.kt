package com.nurio.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationPermissionStateTest {
    @Test
    fun enabledNotificationsAreGrantedOnAnySdk() {
        assertEquals("granted", NotificationPermissionState.resolve(enabled = true, sdkInt = 33, hasRequested = false))
        assertEquals("granted", NotificationPermissionState.resolve(enabled = true, sdkInt = 28, hasRequested = false))
    }

    @Test
    fun disabledBelowTiramisuIsDenied() {
        assertEquals("denied", NotificationPermissionState.resolve(enabled = false, sdkInt = 32, hasRequested = false))
    }

    @Test
    fun disabledOnTiramisuBeforeAnyRequestIsNotDetermined() {
        assertEquals("not_determined", NotificationPermissionState.resolve(enabled = false, sdkInt = 33, hasRequested = false))
    }

    @Test
    fun disabledOnTiramisuAfterRequestIsDenied() {
        assertEquals("denied", NotificationPermissionState.resolve(enabled = false, sdkInt = 34, hasRequested = true))
    }
}
