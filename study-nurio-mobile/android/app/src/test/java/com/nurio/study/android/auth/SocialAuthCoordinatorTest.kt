package com.nurio.study.android.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SocialAuthCoordinatorTest {
    @Test
    fun `Kakao starts native auth exactly once and never opens system auth`() {
        var kakaoStartCount = 0
        val openedUrls = mutableListOf<String>()
        val coordinator = SocialAuthCoordinator(
            startKakao = { kakaoStartCount += 1 },
            openSystemAuth = openedUrls::add
        )

        coordinator.start(
            SocialAuthRoute(
                provider = SocialAuthProvider.KAKAO,
                url = "https://study.nurio.kr/auth/kakao"
            )
        )

        assertEquals(1, kakaoStartCount)
        assertEquals(emptyList<String>(), openedUrls)
    }

    @Test
    fun `Google then Naver open only system auth with exact URLs in order`() {
        var kakaoStartCount = 0
        val openedUrls = mutableListOf<String>()
        val coordinator = SocialAuthCoordinator(
            startKakao = { kakaoStartCount += 1 },
            openSystemAuth = openedUrls::add
        )
        val googleUrl =
            "https://study.nurio.kr/auth/google_oauth2?platform=native"
        val naverUrl =
            "https://study.nurio.kr/auth/naver?return_to=%2Fevents"

        coordinator.start(
            SocialAuthRoute(SocialAuthProvider.GOOGLE, googleUrl)
        )
        coordinator.start(
            SocialAuthRoute(SocialAuthProvider.NAVER, naverUrl)
        )

        assertEquals(0, kakaoStartCount)
        assertEquals(listOf(googleUrl, naverUrl), openedUrls)
    }

    @Test
    fun `valid callback builds Study token auth URL with encoded values`() {
        val tokenAuthUrl = NativeAuthCallback.toTokenAuthUrl(
            callbackUrl =
                "nuriostudy://auth-callback?token=signed%20token%26role%3Duser&state=one%2Ftime",
            baseUrl = "https://study.nurio.kr"
        )

        assertEquals(
            "https://study.nurio.kr/auth/native/token_auth" +
                "?token=signed+token%26role%3Duser&state=one%2Ftime",
            tokenAuthUrl
        )
    }

    @Test
    fun `callback rejects wrong scheme host userinfo and missing values`() {
        val invalidCallbacks = listOf(
            "nurio://auth-callback?token=token&state=state",
            "nuriostudy://other-host?token=token&state=state",
            "nuriostudy://attacker@auth-callback?token=token&state=state",
            "nuriostudy://auth-callback?state=state",
            "nuriostudy://auth-callback?token=token",
            "nuriostudy://auth-callback?token=%20%20&state=state",
            "nuriostudy://auth-callback?token=token&state=%20%20"
        )

        invalidCallbacks.forEach { callbackUrl ->
            assertNull(
                callbackUrl,
                NativeAuthCallback.toTokenAuthUrl(
                    callbackUrl = callbackUrl,
                    baseUrl = "https://study.nurio.kr"
                )
            )
        }
    }
}
