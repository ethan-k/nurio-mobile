package com.nurio.study.android.auth

import com.kakao.sdk.auth.model.OAuthToken
import com.kakao.sdk.common.model.ClientError
import com.kakao.sdk.common.model.ClientErrorCause
import com.kakao.sdk.user.UserApiClient
import com.nurio.study.android.BuildConfig
import com.nurio.study.android.MainActivity
import java.util.concurrent.atomic.AtomicBoolean

internal sealed interface KakaoLoginResult {
    data class Success(val accessToken: String) : KakaoLoginResult
    data object Cancelled : KakaoLoginResult
    data object Failed : KakaoLoginResult
}

internal interface KakaoLoginSdk {
    fun isKakaoTalkLoginAvailable(): Boolean
    fun loginWithKakaoTalk(callback: (KakaoLoginResult) -> Unit)
    fun loginWithKakaoAccount(callback: (KakaoLoginResult) -> Unit)
}

internal class KakaoLoginFlow(
    private val sdk: KakaoLoginSdk,
    private val onAccessToken: (String) -> Unit,
    private val onCancelled: () -> Unit,
    private val onFailure: () -> Unit
) {
    private val started = AtomicBoolean(false)
    private val accountStarted = AtomicBoolean(false)
    private val terminal = AtomicBoolean(false)

    fun start() {
        if (!started.compareAndSet(false, true)) return

        val talkAvailable = try {
            sdk.isKakaoTalkLoginAvailable()
        } catch (_: Exception) {
            false
        }

        if (talkAvailable) {
            startTalkLogin()
        } else {
            startAccountLogin()
        }
    }

    private fun startTalkLogin() {
        try {
            sdk.loginWithKakaoTalk(::handleTalkResult)
        } catch (_: Exception) {
            startAccountLogin()
        }
    }

    private fun handleTalkResult(result: KakaoLoginResult) {
        if (terminal.get() || accountStarted.get()) return

        when (result) {
            is KakaoLoginResult.Success -> {
                if (result.accessToken.isBlank()) {
                    startAccountLogin()
                } else {
                    finish { onAccessToken(result.accessToken) }
                }
            }
            KakaoLoginResult.Cancelled -> finish(onCancelled)
            KakaoLoginResult.Failed -> startAccountLogin()
        }
    }

    private fun startAccountLogin() {
        if (terminal.get() || !accountStarted.compareAndSet(false, true)) return

        try {
            sdk.loginWithKakaoAccount(::handleAccountResult)
        } catch (_: Exception) {
            finish(onFailure)
        }
    }

    private fun handleAccountResult(result: KakaoLoginResult) {
        if (terminal.get()) return

        when (result) {
            is KakaoLoginResult.Success -> {
                if (result.accessToken.isBlank()) {
                    finish(onFailure)
                } else {
                    finish { onAccessToken(result.accessToken) }
                }
            }
            KakaoLoginResult.Cancelled -> finish(onCancelled)
            KakaoLoginResult.Failed -> finish(onFailure)
        }
    }

    private fun finish(action: () -> Unit) {
        if (terminal.compareAndSet(false, true)) {
            action()
        }
    }
}

internal class NativeKakaoSignInCoordinator(
    private val activity: MainActivity,
    private val handoffClient: NativeAuthHandoffClient
) {
    private val inFlight = AtomicBoolean(false)
    private val loginSdk: KakaoLoginSdk = AndroidKakaoLoginSdk(activity)

    fun start() {
        if (!inFlight.compareAndSet(false, true)) return

        if (BuildConfig.KAKAO_NATIVE_APP_KEY.isBlank()) {
            finishWithError()
            return
        }

        KakaoLoginFlow(
            sdk = loginSdk,
            onAccessToken = ::exchangeAccessToken,
            onCancelled = ::finishSilently,
            onFailure = ::finishWithError
        ).start()
    }

    private fun exchangeAccessToken(accessToken: String) {
        try {
            handoffClient.exchangeKakao(accessToken) { result ->
                result.fold(
                    onSuccess = { callbackUrl ->
                        finish { activity.routeNativeAuthCallback(callbackUrl) }
                    },
                    onFailure = { finishWithError() }
                )
            }
        } catch (_: Exception) {
            finishWithError()
        }
    }

    private fun finishWithError() {
        finish(activity::showSocialAuthError)
    }

    private fun finishSilently() {
        finish {}
    }

    private fun finish(action: () -> Unit) {
        activity.runOnUiThread {
            if (inFlight.compareAndSet(true, false)) {
                action()
            }
        }
    }
}

private class AndroidKakaoLoginSdk(
    private val activity: MainActivity
) : KakaoLoginSdk {
    override fun isKakaoTalkLoginAvailable(): Boolean =
        UserApiClient.instance.isKakaoTalkLoginAvailable(activity)

    override fun loginWithKakaoTalk(callback: (KakaoLoginResult) -> Unit) {
        UserApiClient.instance.loginWithKakaoTalk(activity) { token, error ->
            callback(resultOf(token, error))
        }
    }

    override fun loginWithKakaoAccount(callback: (KakaoLoginResult) -> Unit) {
        UserApiClient.instance.loginWithKakaoAccount(activity) { token, error ->
            callback(resultOf(token, error))
        }
    }

    private fun resultOf(token: OAuthToken?, error: Throwable?): KakaoLoginResult {
        if (error is ClientError && error.reason == ClientErrorCause.Cancelled) {
            return KakaoLoginResult.Cancelled
        }

        val accessToken = token?.accessToken
        return if (error != null || accessToken.isNullOrBlank()) {
            KakaoLoginResult.Failed
        } else {
            KakaoLoginResult.Success(accessToken)
        }
    }
}
