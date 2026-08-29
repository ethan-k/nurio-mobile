package com.nurio.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationRouteTest {
    @Test
    fun `routes a push path to the dedicated feedback page`() {
        assertEquals(
            "https://nurio.kr/events/42/feedback/new?t=signed-token&src=push",
            NotificationRoute.destination(
                "/events/42/feedback/new?t=signed-token&src=push",
                "https://nurio.kr",
            ),
        )
    }

    @Test
    fun `normalizes the customer www host`() {
        assertEquals(
            "https://nurio.kr/events/42",
            NotificationRoute.destination(
                "https://www.nurio.kr/events/42",
                "https://nurio.kr",
            ),
        )
    }

    @Test
    fun `rejects external and blocked destinations`() {
        assertNull(NotificationRoute.destination("https://example.com/events/42", "https://nurio.kr"))
        assertNull(NotificationRoute.destination("/admin/events", "https://nurio.kr"))
    }
}
