package com.nurio.study.android.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SocialAuthRouteTest {
    private val baseUrl = "https://study.nurio.kr"

    @Test
    fun `providers expose exact Rails auth paths`() {
        assertEquals("/auth/kakao", SocialAuthProvider.KAKAO.path)
        assertEquals("/auth/google_oauth2", SocialAuthProvider.GOOGLE.path)
        assertEquals("/auth/naver", SocialAuthProvider.NAVER.path)
    }

    @Test
    fun `resolves allowlisted provider paths and preserves queries`() {
        val cases = listOf(
            Triple(
                "/auth/kakao",
                SocialAuthProvider.KAKAO,
                "https://study.nurio.kr/auth/kakao"
            ),
            Triple(
                "/auth/google_oauth2?platform=native",
                SocialAuthProvider.GOOGLE,
                "https://study.nurio.kr/auth/google_oauth2?platform=native"
            ),
            Triple(
                "https://STUDY.NURIO.KR/auth/naver?return_to=%2Fevents",
                SocialAuthProvider.NAVER,
                "https://STUDY.NURIO.KR/auth/naver?return_to=%2Fevents"
            )
        )

        cases.forEach { (startPath, expectedProvider, expectedUrl) ->
            assertEquals(
                SocialAuthRoute(expectedProvider, expectedUrl),
                SocialAuthRoute.resolve(startPath, baseUrl)
            )
        }
    }

    @Test
    fun `rejects foreign hosts non web schemes and unknown paths`() {
        val rejectedPaths = listOf(
            "https://evil.example/auth/kakao",
            "/admin/events",
            "mailto:hello@example.com",
            "javascript:alert(1)",
            "/auth/kakao/extra"
        )

        rejectedPaths.forEach { startPath ->
            assertNull(startPath, SocialAuthRoute.resolve(startPath, baseUrl))
        }
    }
}
