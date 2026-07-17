package com.nurio.study.android.auth

import com.kakao.sdk.auth.model.OAuthToken
import com.kakao.sdk.common.model.ClientError
import com.kakao.sdk.common.model.ClientErrorCause
import com.kakao.sdk.user.UserApiClient
import com.nurio.study.android.BuildConfig
import com.nurio.study.android.MainActivity
import java.util.concurrent.atomic.AtomicBoolean

internal class NativeKakaoSignInCoordinator(
    private val activity: MainActivity,
    private val handoffClient: NativeAuthHandoffClient
) {
    private val inFlight = AtomicBoolean(false)

    fun start() {
        if (!inFlight.compareAndSet(false, true)) return

        if (BuildConfig.KAKAO_NATIVE_APP_KEY.isBlank()) {
            finishWithError()
            return
        }

        val callback: (OAuthToken?, Throwable?) -> Unit = { token, error ->
            handleLoginResult(token, error)
        }

        try {
            if (UserApiClient.instance.isKakaoTalkLoginAvailable(activity)) {
                UserApiClient.instance.loginWithKakaoTalk(activity, callback = callback)
            } else {
                UserApiClient.instance.loginWithKakaoAccount(activity, callback = callback)
            }
        } catch (_: Exception) {
            finishWithError()
        }
    }

    private fun handleLoginResult(token: OAuthToken?, error: Throwable?) {
        if (error is ClientError && error.reason == ClientErrorCause.Cancelled) {
            finishSilently()
            return
        }

        val accessToken = token?.accessToken
        if (error != null || accessToken.isNullOrBlank()) {
            finishWithError()
            return
        }

        handoffClient.exchangeKakao(accessToken) { result ->
            result.fold(
                onSuccess = { callbackUrl ->
                    finish { activity.routeNativeAuthCallback(callbackUrl) }
                },
                onFailure = { finishWithError() }
            )
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
