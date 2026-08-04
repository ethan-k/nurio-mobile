package com.nurio.studyleaders.android.auth

import org.junit.Assert.assertEquals
import org.junit.Test

class KakaoLoginFlowTest {
    @Test
    fun `KakaoTalk failure falls back once to Kakao Account`() {
        val sdk = KakaoLoginSdkFake(talkAvailable = true)
        val tokens = mutableListOf<String>()
        var failureCount = 0
        val flow = KakaoLoginFlow(
            sdk = sdk,
            onAccessToken = tokens::add,
            onCancelled = {},
            onFailure = { failureCount += 1 }
        )

        flow.start()
        sdk.completeTalk(KakaoLoginResult.Failed)
        sdk.completeAccount(KakaoLoginResult.Success("leader-kakao-token"))

        assertEquals(1, sdk.talkStartCount)
        assertEquals(1, sdk.accountStartCount)
        assertEquals(listOf("leader-kakao-token"), tokens)
        assertEquals(0, failureCount)
    }

    @Test
    fun `cancellation stays silent and never falls back`() {
        val sdk = KakaoLoginSdkFake(talkAvailable = true)
        var cancellationCount = 0
        var failureCount = 0
        val flow = KakaoLoginFlow(
            sdk = sdk,
            onAccessToken = {},
            onCancelled = { cancellationCount += 1 },
            onFailure = { failureCount += 1 }
        )

        flow.start()
        sdk.completeTalk(KakaoLoginResult.Cancelled)

        assertEquals(1, cancellationCount)
        assertEquals(0, failureCount)
        assertEquals(0, sdk.accountStartCount)
    }
}

private class KakaoLoginSdkFake(
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
