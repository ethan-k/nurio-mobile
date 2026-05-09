package com.nurio.android

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {
    private var pendingRouteUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        delegate.setCurrentNavigator(navigatorConfigurations().first())
        requestNotificationPermissionIfNeeded()
        handleLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLaunchIntent(intent)
    }

    override fun onNavigatorReady(navigator: Navigator) {
        super.onNavigatorReady(navigator)

        pendingRouteUrl?.let { url ->
            navigator.route(url)
            pendingRouteUrl = null
        }
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "events",
            startLocation = "${BuildConfig.BASE_URL}/events",
            navigatorHostId = R.id.nav_host_events
        )
    )

    private fun handleLaunchIntent(intent: Intent?) {
        handleAuthCallbackIntent(intent) || handleNotificationIntent(intent)
    }

    private fun handleAuthCallbackIntent(intent: Intent?): Boolean {
        val authUrl = intent?.data
            ?.takeIf { it.scheme == "nurio" && it.host == "auth-callback" }
            ?.let(::buildTokenAuthUrl)
            ?: return false

        routeWhenReady(authUrl)
        return true
    }

    private fun handleNotificationIntent(intent: Intent?): Boolean {
        val path = intent?.getStringExtra("path")?.takeIf { it.isNotBlank() } ?: return false

        routeWhenReady(buildAppUrl(path))
        return true
    }

    private fun routeWhenReady(url: String) {
        val navigator = delegate.currentNavigator

        if (navigator != null) {
            navigator.route(url)
            pendingRouteUrl = null
        } else {
            pendingRouteUrl = url
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

    private fun buildAppUrl(path: String): String {
        return if (path.startsWith("http://") || path.startsWith("https://")) {
            path
        } else {
            "${BuildConfig.BASE_URL.trimEnd('/')}/${path.trimStart('/')}"
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    }
}
