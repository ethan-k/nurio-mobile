package com.nurio.studyleaders.android.auth

import org.junit.Assert.assertEquals
import org.junit.Test

class SocialAuthCoordinatorTest {
    @Test
    fun `Kakao uses native SDK while Google and Naver use system auth`() {
        var kakaoStartCount = 0
        val systemUrls = mutableListOf<String>()
        val coordinator = SocialAuthCoordinator(
            startKakao = { kakaoStartCount += 1 },
            openSystemAuth = systemUrls::add
        )

        coordinator.start(
            SocialAuthRoute(
                provider = SocialAuthProvider.KAKAO,
                url = "https://studyleaders.nurio.kr/auth/kakao"
            )
        )
        coordinator.start(
            SocialAuthRoute(
                provider = SocialAuthProvider.GOOGLE,
                url = "https://studyleaders.nurio.kr/auth/google_oauth2"
            )
        )
        coordinator.start(
            SocialAuthRoute(
                provider = SocialAuthProvider.NAVER,
                url = "https://studyleaders.nurio.kr/auth/naver"
            )
        )

        assertEquals(1, kakaoStartCount)
        assertEquals(
            listOf(
                "https://studyleaders.nurio.kr/auth/google_oauth2",
                "https://studyleaders.nurio.kr/auth/naver"
            ),
            systemUrls
        )
    }
}
