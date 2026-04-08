package com.nurio.tutors.android

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
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
            name = "tutors",
            startLocation = BuildConfig.BASE_URL,
            navigatorHostId = R.id.nav_host_tutors
        )
    )

    private fun handleAuthCallbackIntent(intent: Intent?) {
        val authUrl = intent?.data
            ?.takeIf { it.scheme == "nurio" && it.host == "auth-callback" }
            ?.let(::buildTokenAuthUrl)
            ?: return

        val navigator = delegate.currentNavigator

        if (navigator != null) {
            navigator.route(authUrl)
            pendingAuthUrl = null
        } else {
            pendingAuthUrl = authUrl
        }
    }

    private fun buildTokenAuthUrl(callbackUri: Uri): String? {
        val token = callbackUri.getQueryParameter("token") ?: return null
        val state = callbackUri.getQueryParameter("state") ?: return null

        return Uri.parse("${BuildConfig.BASE_URL}/auth/native/token_auth")
            .buildUpon()
            .appendQueryParameter("token", token)
            .appendQueryParameter("state", state)
            .build()
            .toString()
    }
}
