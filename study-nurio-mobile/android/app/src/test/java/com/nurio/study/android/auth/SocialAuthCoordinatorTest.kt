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

    @Test
    fun `non cancellation Talk failure starts account login exactly once`() {
        val sdk = FakeKakaoLoginSdk(talkAvailable = true)
        val accessTokens = mutableListOf<String>()
        var cancellationCount = 0
        var failureCount = 0
        val flow = KakaoLoginFlow(
            sdk = sdk,
            onAccessToken = accessTokens::add,
            onCancelled = { cancellationCount += 1 },
            onFailure = { failureCount += 1 }
        )

        flow.start()
        sdk.completeTalk(KakaoLoginResult.Failed)
        sdk.completeTalk(KakaoLoginResult.Failed)
        sdk.completeAccount(KakaoLoginResult.Success("account access token"))

        assertEquals(1, sdk.talkStartCount)
        assertEquals(1, sdk.accountStartCount)
        assertEquals(listOf("account access token"), accessTokens)
        assertEquals(0, cancellationCount)
        assertEquals(0, failureCount)
    }

    @Test
    fun `Talk cancellation never starts account login and finishes silently`() {
        val sdk = FakeKakaoLoginSdk(talkAvailable = true)
        val accessTokens = mutableListOf<String>()
        var cancellationCount = 0
        var failureCount = 0
        val flow = KakaoLoginFlow(
            sdk = sdk,
            onAccessToken = accessTokens::add,
            onCancelled = { cancellationCount += 1 },
            onFailure = { failureCount += 1 }
        )

        flow.start()
        sdk.completeTalk(KakaoLoginResult.Cancelled)

        assertEquals(1, sdk.talkStartCount)
        assertEquals(0, sdk.accountStartCount)
        assertEquals(emptyList<String>(), accessTokens)
        assertEquals(1, cancellationCount)
        assertEquals(0, failureCount)
    }

    @Test
    fun `Talk success never starts account login`() {
        val sdk = FakeKakaoLoginSdk(talkAvailable = true)
        val accessTokens = mutableListOf<String>()
        var cancellationCount = 0
        var failureCount = 0
        val flow = KakaoLoginFlow(
            sdk = sdk,
            onAccessToken = accessTokens::add,
            onCancelled = { cancellationCount += 1 },
            onFailure = { failureCount += 1 }
        )

        flow.start()
        sdk.completeTalk(KakaoLoginResult.Success("talk access token"))

        assertEquals(1, sdk.talkStartCount)
        assertEquals(0, sdk.accountStartCount)
        assertEquals(listOf("talk access token"), accessTokens)
        assertEquals(0, cancellationCount)
        assertEquals(0, failureCount)
    }

    private class FakeKakaoLoginSdk(
        private val talkAvailable: Boolean
    ) : KakaoLoginSdk {
        var talkStartCount = 0
            private set
        var accountStartCount = 0
            private set
        private var talkCallback: ((KakaoLoginResult) -> Unit)? = null
        private var accountCallback: ((KakaoLoginResult) -> Unit)? = null

        override fun isKakaoTalkLoginAvailable(): Boolean = talkAvailable

        override fun loginWithKakaoTalk(callback: (KakaoLoginResult) -> Unit) {
            talkStartCount += 1
            talkCallback = callback
        }

        override fun loginWithKakaoAccount(callback: (KakaoLoginResult) -> Unit) {
            accountStartCount += 1
            accountCallback = callback
        }

        fun completeTalk(result: KakaoLoginResult) {
            talkCallback?.invoke(result)
        }

        fun completeAccount(result: KakaoLoginResult) {
            accountCallback?.invoke(result)
        }
    }
}
