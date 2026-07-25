package com.nurio.studyleader.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.nurio.studyleader.android.auth.NativeAuthCallback
import com.nurio.studyleader.android.auth.SocialAuthRoute
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {
    private var pendingAuthUrl: String? = null

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

        pendingAuthUrl?.let { authUrl ->
            navigator.route(authUrl)
            pendingAuthUrl = null
        }
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "leader",
            startLocation = BuildConfig.BASE_URL,
            navigatorHostId = R.id.nav_host_leader
        )
    )

    internal fun dispatchSocialAuth(route: SocialAuthRoute) {
        CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            .build()
            .launchUrl(this, route.url.toUri())
    }

    private fun handleAuthCallbackIntent(intent: Intent?) {
        val callbackUrl = intent?.dataString ?: return
        val authUrl = NativeAuthCallback.toTokenAuthUrl(callbackUrl, BuildConfig.BASE_URL) ?: return
        intent.data = null

        val navigator = delegate.currentNavigator

        if (navigator != null) {
            navigator.route(authUrl)
            pendingAuthUrl = null
        } else {
            pendingAuthUrl = authUrl
        }
    }
}
