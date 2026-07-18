package com.nurio.study.android.auth

import com.nurio.study.android.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class SocialAuthCoordinatorTest {
    @Test
    fun `Hotwire framework debug logging stays disabled for auth navigation`() {
        assertFalse(BuildConfig.DEBUG_LOGGING)
    }

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
    fun `Apple opens only system auth with the exact URL`() {
        var kakaoStartCount = 0
        val openedUrls = mutableListOf<String>()
        val coordinator = SocialAuthCoordinator(
            startKakao = { kakaoStartCount += 1 },
            openSystemAuth = openedUrls::add
        )
        val appleUrl = "https://study.nurio.kr/auth/apple?platform=native"

        coordinator.start(
            SocialAuthRoute(SocialAuthProvider.APPLE, appleUrl)
        )

        assertEquals(0, kakaoStartCount)
        assertEquals(listOf(appleUrl), openedUrls)
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
            "nuriostudy://auth-callback:123?token=token&state=state",
            "nuriostudy://auth-callback/extra?token=token&state=state",
            "nuriostudy://auth-callback?token=token&state=state#fragment",
            "nuriostudy://auth-callback?state=state",
            "nuriostudy://auth-callback?token=token",
            "nuriostudy://auth-callback?token=one&token=two&state=state",
            "nuriostudy://auth-callback?token=token&state=one&state=two",
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
    fun `valid callback source is consumed before it can replay after recreation`() {
        val source = FakeNativeAuthCallbackSource(
            "nuriostudy://auth-callback?token=signed%20token&state=one%2Ftime"
        )

        val firstAuthUrl = NativeAuthCallbackConsumer.consume(
            source = source,
            baseUrl = "https://study.nurio.kr"
        )
        val replayedAuthUrl = NativeAuthCallbackConsumer.consume(
            source = source,
            baseUrl = "https://study.nurio.kr"
        )

        assertEquals(
            "https://study.nurio.kr/auth/native/token_auth" +
                "?token=signed+token&state=one%2Ftime",
            firstAuthUrl
        )
        assertNull(replayedAuthUrl)
        assertNull(source.callbackUrl)
        assertEquals(1, source.clearCount)
    }

    @Test
    fun `invalid callback source remains available to normal intent handling`() {
        val unrelatedUrl = "https://study.nurio.kr/events"
        val source = FakeNativeAuthCallbackSource(unrelatedUrl)

        val authUrl = NativeAuthCallbackConsumer.consume(
            source = source,
            baseUrl = "https://study.nurio.kr"
        )

        assertNull(authUrl)
        assertEquals(unrelatedUrl, source.callbackUrl)
        assertEquals(0, source.clearCount)
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

    @Test
    fun `cancel during provider login ignores late callback and allows restart`() {
        val sdk = FakeKakaoLoginSdk(talkAvailable = true)
        val handoff = FakeKakaoHandoffExchanger()
        val host = FakeKakaoAuthHost()
        val coordinator = NativeKakaoSignInCoordinator(
            host = host,
            loginSdk = sdk,
            handoffExchanger = handoff,
            isConfigured = { true }
        )

        coordinator.start()
        coordinator.cancel()
        sdk.completeTalk(
            KakaoLoginResult.Success("stale access token"),
            callbackIndex = 0
        )

        assertEquals(0, sdk.accountStartCount)
        assertEquals(emptyList<String>(), handoff.accessTokens)
        assertEquals(emptyList<String>(), host.callbackUrls)
        assertEquals(0, host.errorCount)

        coordinator.start()
        sdk.completeTalk(
            KakaoLoginResult.Success("fresh access token"),
            callbackIndex = 1
        )
        handoff.complete(
            callbackIndex = 0,
            result = Result.success(
                "nuriostudy://auth-callback?token=fresh&state=fresh"
            )
        )

        assertEquals(2, sdk.talkStartCount)
        assertEquals(listOf("fresh access token"), handoff.accessTokens)
        assertEquals(
            listOf("nuriostudy://auth-callback?token=fresh&state=fresh"),
            host.callbackUrls
        )
        assertEquals(0, host.errorCount)
    }

    @Test
    fun `invalidation during handoff ignores late route and error delivery`() {
        val sdk = FakeKakaoLoginSdk(talkAvailable = true)
        val handoff = FakeKakaoHandoffExchanger()
        val host = FakeKakaoAuthHost()
        val coordinator = NativeKakaoSignInCoordinator(
            host = host,
            loginSdk = sdk,
            handoffExchanger = handoff,
            isConfigured = { true }
        )

        coordinator.start()
        sdk.completeTalk(KakaoLoginResult.Success("access token"))
        coordinator.invalidate()
        handoff.complete(
            callbackIndex = 0,
            result = Result.success(
                "nuriostudy://auth-callback?token=stale&state=stale"
            )
        )
        handoff.complete(
            callbackIndex = 0,
            result = Result.failure(IllegalStateException("handoff failed"))
        )
        coordinator.start()

        assertEquals(1, sdk.talkStartCount)
        assertEquals(listOf("access token"), handoff.accessTokens)
        assertEquals(emptyList<String>(), host.callbackUrls)
        assertEquals(0, host.errorCount)
        assertEquals(1, host.invalidationCount)
    }

    private class FakeKakaoLoginSdk(
        private val talkAvailable: Boolean
    ) : KakaoLoginSdk {
        var talkStartCount = 0
            private set
        var accountStartCount = 0
            private set
        private val talkCallbacks = mutableListOf<(KakaoLoginResult) -> Unit>()
        private val accountCallbacks = mutableListOf<(KakaoLoginResult) -> Unit>()

        override fun isKakaoTalkLoginAvailable(): Boolean = talkAvailable

        override fun loginWithKakaoTalk(callback: (KakaoLoginResult) -> Unit) {
            talkStartCount += 1
            talkCallbacks += callback
        }

        override fun loginWithKakaoAccount(callback: (KakaoLoginResult) -> Unit) {
            accountStartCount += 1
            accountCallbacks += callback
        }

        fun completeTalk(
            result: KakaoLoginResult,
            callbackIndex: Int = talkCallbacks.lastIndex
        ) {
            talkCallbacks[callbackIndex](result)
        }

        fun completeAccount(
            result: KakaoLoginResult,
            callbackIndex: Int = accountCallbacks.lastIndex
        ) {
            accountCallbacks[callbackIndex](result)
        }
    }

    private class FakeKakaoHandoffExchanger : KakaoHandoffExchanger {
        val accessTokens = mutableListOf<String>()
        private val callbacks = mutableListOf<(Result<String>) -> Unit>()

        override fun exchange(
            accessToken: String,
            callback: (Result<String>) -> Unit
        ) {
            accessTokens += accessToken
            callbacks += callback
        }

        fun complete(callbackIndex: Int, result: Result<String>) {
            callbacks[callbackIndex](result)
        }
    }

    private class FakeKakaoAuthHost : KakaoAuthHost {
        val callbackUrls = mutableListOf<String>()
        var errorCount = 0
            private set
        var invalidationCount = 0
            private set

        override fun routeNativeAuthCallback(callbackUrl: String) {
            callbackUrls += callbackUrl
        }

        override fun showSocialAuthError() {
            errorCount += 1
        }

        override fun invalidate() {
            invalidationCount += 1
        }
    }

    private class FakeNativeAuthCallbackSource(callbackUrl: String?) :
        NativeAuthCallbackSource {
        var clearCount = 0
            private set

        override var callbackUrl: String? = callbackUrl
            set(value) {
                if (value == null) clearCount += 1
                field = value
            }
    }
}
