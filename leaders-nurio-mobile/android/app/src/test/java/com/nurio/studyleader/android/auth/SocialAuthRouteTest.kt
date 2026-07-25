package com.nurio.studyleader.android.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SocialAuthRouteTest {
    private val baseUrl = "https://studyleaders.nurio.kr"

    @Test
    fun resolvesAllowlistedProviderPathsOnTheConfiguredOrigin() {
        val cases = listOf(
            "/auth/google_oauth2?platform=native" to SocialAuthProvider.GOOGLE,
            "/auth/kakao?platform=native" to SocialAuthProvider.KAKAO,
            "/auth/naver?platform=native" to SocialAuthProvider.NAVER,
            "/auth/apple?platform=native" to SocialAuthProvider.APPLE
        )

        cases.forEach { (path, provider) ->
            val route = SocialAuthRoute.resolve(path, baseUrl)
            assertEquals(provider, route?.provider)
            assertEquals("https://studyleaders.nurio.kr$path", route?.url)
        }
    }

    @Test
    fun rejectsForeignOriginsPortsCredentialsAndUnknownPaths() {
        listOf(
            "https://example.com/auth/google_oauth2",
            "https://studyleaders.nurio.kr:444/auth/kakao",
            "https://attacker@studyleaders.nurio.kr/auth/naver",
            "/admin/events",
            "/auth/google_oauth2/extra"
        ).forEach { startPath ->
            assertNull(SocialAuthRoute.resolve(startPath, baseUrl))
        }
    }
}
