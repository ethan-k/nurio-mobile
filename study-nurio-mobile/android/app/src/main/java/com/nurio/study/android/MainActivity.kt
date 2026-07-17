package com.nurio.study.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AlertDialog
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.nurio.study.android.auth.NativeAuthCallback
import com.nurio.study.android.auth.NativeAuthHandoffClient
import com.nurio.study.android.auth.NativeKakaoSignInCoordinator
import com.nurio.study.android.auth.SocialAuthCoordinator
import com.nurio.study.android.auth.SocialAuthRoute
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {
    private var pendingAuthUrl: String? = null
    private var readyNavigator: Navigator? = null
    private val socialAuthCoordinator by lazy {
        val kakaoCoordinator = NativeKakaoSignInCoordinator(
            activity = this,
            handoffClient = NativeAuthHandoffClient()
        )
        SocialAuthCoordinator(
            startKakao = kakaoCoordinator::start,
            openSystemAuth = ::openSystemAuth
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        delegate.setCurrentNavigator(navigatorConfigurations().first())
        handleAuthCallbackIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthCallbackIntent(intent)
    }

    override fun onNavigatorReady(navigator: Navigator) {
        super.onNavigatorReady(navigator)
        readyNavigator = navigator

        pendingAuthUrl?.let { authUrl ->
            navigator.route(authUrl)
            pendingAuthUrl = null
        }
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "study",
            startLocation = BuildConfig.BASE_URL,
            navigatorHostId = R.id.nav_host_study
        )
    )

    private fun handleAuthCallbackIntent(intent: Intent?) {
        intent?.dataString?.let(::routeNativeAuthCallback)
    }

    internal fun dispatchSocialAuth(route: SocialAuthRoute) {
        socialAuthCoordinator.start(route)
    }

    internal fun routeNativeAuthCallback(callbackUrl: String) {
        val authUrl = NativeAuthCallback.toTokenAuthUrl(
            callbackUrl = callbackUrl,
            baseUrl = BuildConfig.BASE_URL
        ) ?: return

        val navigator = readyNavigator

        if (navigator != null) {
            navigator.route(authUrl)
            pendingAuthUrl = null
        } else {
            pendingAuthUrl = authUrl
        }
    }

    internal fun showSocialAuthError() {
        AlertDialog.Builder(this)
            .setTitle("Sign-in failed")
            .setMessage("Please try again.")
            .setPositiveButton("OK", null)
            .show()
    }

    private fun openSystemAuth(url: String) {
        val colorParams = CustomTabColorSchemeParams.Builder().build()
        CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            .setUrlBarHidingEnabled(false)
            .setDefaultColorSchemeParams(colorParams)
            .build()
            .launchUrl(this, url.toUri())
    }
}
