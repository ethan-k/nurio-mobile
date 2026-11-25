package com.nurio.studyleaders.android

import com.nurio.studyleaders.android.auth.SocialAuthRoute
import com.nurio.studyleaders.android.notifications.NotificationDestination
import com.nurio.studyleaders.android.routing.LeaderScopePolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
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
    fun `locale prefixed notification preserves the destination and scope`() {
        val baseUrl = "https://studyleaders.nurio.kr"
        val path = "/ko/events?lang=ko"
        assertEquals("$baseUrl$path", NotificationDestination.resolve(path, null, baseUrl))
        assertEquals("$baseUrl$path", NotificationDestination.resolve(null, "$baseUrl$path", baseUrl))
        for (path in listOf("/ko/admin", "/ko//admin", "/en/admin/x", "/ko/tutoring")) {
            assertEquals(baseUrl, NotificationDestination.resolve(path, null, baseUrl))
        }
    }

    @Test
    fun `locale prefixed OAuth route selects the same provider`() {
        val baseUrl = "https://studyleaders.nurio.kr"
        val plain = SocialAuthRoute.resolve("/auth/kakao", baseUrl)
        val localized = SocialAuthRoute.resolve("/KO/auth/kakao", baseUrl)
        assertNotNull(plain)
        assertEquals(plain?.provider, localized?.provider)
    }

    @Test
    fun `scope blocks localized admin pages on the leader host`() {
        val baseUrl = "https://studyleaders.nurio.kr"
        assertTrue(LeaderScopePolicy.shouldOpenExternally("/ko/admin", baseUrl))
        assertTrue(LeaderScopePolicy.shouldOpenExternally("/ko//admin", baseUrl))
        assertTrue(LeaderScopePolicy.shouldOpenExternally("/en/admin/x", baseUrl))
        assertFalse(LeaderScopePolicy.shouldOpenExternally("/ko/events", baseUrl))
    }
}
