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
    fun `treats explicit default HTTPS ports as the configured origin`() {
        assertEquals(
            SocialAuthRoute(
                SocialAuthProvider.KAKAO,
                "https://study.nurio.kr:443/auth/kakao?platform=native"
            ),
            SocialAuthRoute.resolve(
                "https://study.nurio.kr:443/auth/kakao?platform=native",
                baseUrl
            )
        )
        assertEquals(
            SocialAuthRoute(
                SocialAuthProvider.NAVER,
                "https://study.nurio.kr/auth/naver"
            ),
            SocialAuthRoute.resolve(
                "https://study.nurio.kr/auth/naver",
                "https://study.nurio.kr:443"
            )
        )
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

    @Test
    fun `rejects routes outside the configured origin or literal provider paths`() {
        val rejectedRoutes = listOf(
            "http://study.nurio.kr/auth/kakao" to baseUrl,
            "https://study.nurio.kr:8443/auth/kakao" to baseUrl,
            "https://attacker@study.nurio.kr/auth/kakao" to baseUrl,
            "https://study.nurio.kr/%61uth/kakao" to baseUrl,
            "/auth/kakao" to "https://attacker@study.nurio.kr"
        )

        rejectedRoutes.forEach { (startPath, configuredBaseUrl) ->
            assertNull(
                "$startPath must be rejected for $configuredBaseUrl",
                SocialAuthRoute.resolve(startPath, configuredBaseUrl)
            )
        }
    }

    @Test
    fun `rejects invalid configured base origins`() {
        val invalidBaseUrls = listOf(
            "ftp://study.nurio.kr",
            "https:///missing-host",
            "mailto:study.nurio.kr"
        )

        invalidBaseUrls.forEach { invalidBaseUrl ->
            assertNull(
                invalidBaseUrl,
                SocialAuthRoute.resolve("/auth/kakao", invalidBaseUrl)
            )
        }
    }
}
