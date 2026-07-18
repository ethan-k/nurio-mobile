package com.nurio.study.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PendingNotificationRouteTest {
    @Test
    fun `keeps the newest route and consumes it once`() {
        val pendingRoute = PendingNotificationRoute()

        pendingRoute.accept("https://study.nurio.kr/events/1")
        pendingRoute.accept("https://study.nurio.kr/events/2")

        assertEquals("https://study.nurio.kr/events/2", pendingRoute.consume())
        assertNull(pendingRoute.consume())
    }
}
