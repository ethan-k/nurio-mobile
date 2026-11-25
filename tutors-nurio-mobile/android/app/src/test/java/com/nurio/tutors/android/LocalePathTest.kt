package com.nurio.tutors.android

import com.nurio.tutors.android.routing.OAuthRouteDecisionHandler
import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
    fun `OAuth routing matches locale prefixed Kakao on the configured host`() {
        val location = URI("https://tutors.nurio.kr/ko/auth/kakao")
        val handler = OAuthRouteDecisionHandler()
        assertTrue(handler.matchesRoute(location.host, location.scheme, location.path, startHost = "tutors.nurio.kr"))
        assertFalse(handler.matchesRoute(location.host, location.scheme, location.path, startHost = "nurio.kr"))
    }
}
