package com.nurio.study.android.auth

import com.kakao.sdk.auth.model.OAuthToken
import com.kakao.sdk.common.model.ClientError
import com.kakao.sdk.common.model.ClientErrorCause
import com.kakao.sdk.user.UserApiClient
import com.nurio.study.android.BuildConfig
import com.nurio.study.android.MainActivity
import java.lang.ref.WeakReference
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

    fun cancel() {
        terminal.set(true)
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

internal interface KakaoHandoffExchanger {
    fun exchange(accessToken: String, callback: (Result<String>) -> Unit)
}

internal interface KakaoAuthHost {
    fun routeNativeAuthCallback(callbackUrl: String)
    fun showSocialAuthError()
    fun invalidate()
}

internal class NativeKakaoSignInCoordinator(
    private val host: KakaoAuthHost,
    private val loginSdk: KakaoLoginSdk,
    private val handoffExchanger: KakaoHandoffExchanger,
    private val isConfigured: () -> Boolean
) {
    private val stateLock = Any()
    private var activeOperation: Operation? = null
    private var invalidated = false

    internal constructor(
        activity: MainActivity,
        handoffClient: NativeAuthHandoffClient
    ) : this(
        host = MainActivityKakaoAuthHost(activity),
        loginSdk = AndroidKakaoLoginSdk(activity),
        handoffExchanger = NativeKakaoHandoffExchanger(handoffClient),
        isConfigured = { BuildConfig.KAKAO_NATIVE_APP_KEY.isNotBlank() }
    )

    fun start() {
        val operation = synchronized(stateLock) {
            if (invalidated || activeOperation != null) return
            Operation().also { activeOperation = it }
        }

        val configured = try {
            isConfigured()
        } catch (_: Exception) {
            false
        }
        if (!configured) {
            finishWithError(operation)
            return
        }

        val flow = KakaoLoginFlow(
            sdk = loginSdk,
            onAccessToken = { accessToken ->
                exchangeAccessToken(operation, accessToken)
            },
            onCancelled = { finishSilently(operation) },
            onFailure = { finishWithError(operation) }
        )
        val shouldStart = synchronized(stateLock) {
            if (!invalidated && activeOperation === operation) {
                operation.flow = flow
                true
            } else {
                false
            }
        }

        if (shouldStart) {
            flow.start()
        } else {
            flow.cancel()
        }
    }

    fun cancel() {
        synchronized(stateLock) {
            activeOperation?.flow?.cancel()
            activeOperation = null
        }
    }

    fun invalidate() {
        synchronized(stateLock) {
            invalidated = true
            activeOperation?.flow?.cancel()
            activeOperation = null
        }
        host.invalidate()
    }

    private fun exchangeAccessToken(operation: Operation, accessToken: String) {
        if (!isActive(operation)) return

        try {
            handoffExchanger.exchange(accessToken) { result ->
                result.fold(
                    onSuccess = { callbackUrl ->
                        finish(operation) {
                            host.routeNativeAuthCallback(callbackUrl)
                        }
                    },
                    onFailure = { finishWithError(operation) }
                )
            }
        } catch (_: Exception) {
            finishWithError(operation)
        }
    }

    private fun finishWithError(operation: Operation) {
        finish(operation, host::showSocialAuthError)
    }

    private fun finishSilently(operation: Operation) {
        finish(operation) {}
    }

    private fun finish(operation: Operation, action: () -> Unit) {
        val shouldDeliver = synchronized(stateLock) {
            if (!invalidated && activeOperation === operation) {
                activeOperation = null
                true
            } else {
                false
            }
        }

        if (shouldDeliver) action()
    }

    private fun isActive(operation: Operation): Boolean = synchronized(stateLock) {
        !invalidated && activeOperation === operation
    }

    private class Operation {
        var flow: KakaoLoginFlow? = null
    }
}

private class AndroidKakaoLoginSdk(
    activity: MainActivity
) : KakaoLoginSdk {
    private val activityReference = WeakReference(activity)

    override fun isKakaoTalkLoginAvailable(): Boolean {
        val activity = activeActivity()
        return UserApiClient.instance.isKakaoTalkLoginAvailable(activity)
    }

    override fun loginWithKakaoTalk(callback: (KakaoLoginResult) -> Unit) {
        val activity = activeActivity()
        UserApiClient.instance.loginWithKakaoTalk(activity) { token, error ->
            callback(kakaoLoginResult(token, error))
        }
    }

    override fun loginWithKakaoAccount(callback: (KakaoLoginResult) -> Unit) {
        val activity = activeActivity()
        UserApiClient.instance.loginWithKakaoAccount(activity) { token, error ->
            callback(kakaoLoginResult(token, error))
        }
    }

    private fun activeActivity(): MainActivity {
        val activity = activityReference.get()
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            throw IllegalStateException("Kakao auth host is unavailable")
        }
        return activity
    }
}

private class NativeKakaoHandoffExchanger(
    private val handoffClient: NativeAuthHandoffClient
) : KakaoHandoffExchanger {
    override fun exchange(
        accessToken: String,
        callback: (Result<String>) -> Unit
    ) {
        handoffClient.exchangeKakao(accessToken, callback)
    }
}

private class MainActivityKakaoAuthHost(
    activity: MainActivity
) : KakaoAuthHost {
    private val activityReference = WeakReference(activity)
    private val valid = AtomicBoolean(true)

    override fun routeNativeAuthCallback(callbackUrl: String) {
        deliver { activity ->
            activity.routeNativeAuthCallback(callbackUrl)
        }
    }

    override fun showSocialAuthError() {
        deliver(MainActivity::showSocialAuthError)
    }

    override fun invalidate() {
        valid.set(false)
        activityReference.clear()
    }

    private fun deliver(action: (MainActivity) -> Unit) {
        if (!valid.get()) return
        val activity = activityReference.get() ?: return

        activity.runOnUiThread {
            if (!valid.get()) return@runOnUiThread
            val currentActivity = activityReference.get() ?: return@runOnUiThread
            if (currentActivity.isFinishing || currentActivity.isDestroyed) {
                return@runOnUiThread
            }
            action(currentActivity)
        }
    }
}

private fun kakaoLoginResult(
    token: OAuthToken?,
    error: Throwable?
): KakaoLoginResult {
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
