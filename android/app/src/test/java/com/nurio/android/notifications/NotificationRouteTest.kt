package com.nurio.android.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
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

    @Test
    fun `refresh destination preserves existing query parameters`() {
        assertEquals(
            "https://nurio.kr/events/42/chat?from=push&_native_refresh=notification-123",
            NotificationRoute.refreshingDestination(
                "https://nurio.kr/events/42/chat?from=push",
                "notification-123",
            ),
        )
    }

    @Test
    fun `refresh destination replaces an existing refresh token`() {
        assertEquals(
            "https://nurio.kr/events/42/chat?from=push&_native_refresh=notification-456",
            NotificationRoute.refreshingDestination(
                "https://nurio.kr/events/42/chat?_native_refresh=old&from=push",
                "notification-456",
            ),
        )
    }

    @Test
    fun `refresh destination preserves signed query encoding`() {
        assertEquals(
            "https://nurio.kr/events/42/feedback/new?t=a%2Bb%2Fc%3D&_native_refresh=notification-789",
            NotificationRoute.refreshingDestination(
                "https://nurio.kr/events/42/feedback/new?t=a%2Bb%2Fc%3D",
                "notification-789",
            ),
        )
    }

    @Test
    fun `recognizes a push for the screen that is already visible`() {
        assertTrue(NotificationRoute.isShowing("/events/42/chat", "https://nurio.kr/events/42/chat?lang=ko", "https://nurio.kr"))
        assertTrue(NotificationRoute.isShowing("/events/42/chat/", "https://nurio.kr/events/42/chat", "https://nurio.kr"))
        assertTrue(NotificationRoute.isShowing("https://www.nurio.kr/events/42/chat", "https://nurio.kr/events/42/chat", "https://nurio.kr"))
    }

    @Test
    fun `does not treat a different or unknown screen as visible`() {
        assertFalse(NotificationRoute.isShowing("/events/43/chat", "https://nurio.kr/events/42/chat", "https://nurio.kr"))
        assertFalse(NotificationRoute.isShowing("/events/42", "https://nurio.kr/events/42/chat", "https://nurio.kr"))
        assertFalse(NotificationRoute.isShowing("/events/42/chat", null, "https://nurio.kr"))
        assertFalse(NotificationRoute.isShowing(null, "https://nurio.kr/events/42/chat", "https://nurio.kr"))
    }
}
