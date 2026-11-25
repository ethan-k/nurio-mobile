package com.nurio.android

import com.nurio.android.notifications.NotificationRoute
import com.nurio.android.routing.CustomerScopePolicy
import com.nurio.android.webview.PaymentRoutePolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class LocalePathTest {
    @Test
    fun `only the first supported locale segment is stripped`() {
        val cases = listOf(
            "/ko/events" to "/events",
            "/en" to "/",
            "/ko/" to "/",
            "/KO/events" to "/events",
            "/korean-program" to "/korean-program",
            "/kor/x" to "/kor/x",
            "/english" to "/english",
            "/events/ko" to "/events/ko",
            "/ko-kr/x" to "/ko-kr/x",
            "/Ko/x" to "/Ko/x",
            "/ko/en/x" to "/en/x",
            "/en?next=/ko#top" to "/?next=/ko#top",
            "/KO/events?lang=en#top" to "/events?lang=en#top",
            "/ko//x" to "/x",
            "/ko///x?next=//y#//top" to "/x?next=//y#//top",
            "//admin" to "//admin",
            "/events" to "/events",
            "" to "",
        )
        for ((path, expected) in cases) {
            assertEquals(path, expected, LocalePath.strip(path))
        }
    }

    @Test
    fun `scope and push matching preserve localized customer routes`() {
        val baseUrl = "https://nurio.kr"
        for (path in listOf("/ko/admin", "/ko//admin", "/en/admin/x", "/ko/tutoring")) {
            assertTrue(CustomerScopePolicy.isBlockedPath(path))
            assertNull(NotificationRoute.destination(path, baseUrl))
        }
        assertFalse(CustomerScopePolicy.isBlockedPath("/ko/events"))
        val push = "/ko/events/12/chat?lang=ko#latest"
        assertEquals("$baseUrl$push", NotificationRoute.destination(push, baseUrl))
        assertTrue(NotificationRoute.isShowing(push, "$baseUrl/events/12/chat", baseUrl))
    }

    @Test
    fun `checkout entry and completion accept localized paths`() {
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/ko/orders/new"))
        assertTrue(PaymentRoutePolicy.isCheckoutEntryPath("/en/events/12"))
        assertTrue(PaymentRoutePolicy.isPaymentCompletionPath("/ko/payments/portone/complete"))
        assertFalse(PaymentRoutePolicy.isCheckoutEntryPath("/ko/en/orders/new"))
    }
}
