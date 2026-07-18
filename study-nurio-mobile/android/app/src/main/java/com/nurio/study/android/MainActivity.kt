package com.nurio.study.android

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AlertDialog
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.nurio.study.android.auth.NativeAuthCallback
import com.nurio.study.android.auth.NativeAuthCallbackConsumer
import com.nurio.study.android.auth.NativeAuthCallbackSource
import com.nurio.study.android.auth.NativeAuthHandoffClient
import com.nurio.study.android.auth.NativeKakaoSignInCoordinator
import com.nurio.study.android.auth.SocialAuthCoordinator
import com.nurio.study.android.auth.SocialAuthRoute
import com.nurio.study.android.notifications.NotificationDestination
import com.nurio.study.android.notifications.NotificationPayload
import com.nurio.study.android.notifications.NotificationPermissionHost
import com.nurio.study.android.notifications.PendingNotificationRoute
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity(), NotificationPermissionHost {
    companion object {
        private const val PENDING_AUTH_URL_KEY = "pending_auth_url"
        private const val PUSH_PERMISSION_PREFERENCES = "nurio_study_push"
        private const val PUSH_PERMISSION_REQUESTED_KEY = "permission_requested"
        const val NOTIFICATION_DESTINATION_EXTRA = "notification_destination"
    }

    private var pendingAuthUrl: String? = null
    private val pendingNotificationRoute = PendingNotificationRoute()
    private var readyNavigator: Navigator? = null
    private val notificationPermissionCallbacks = mutableListOf<(Boolean) -> Unit>()
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        val callbacks = notificationPermissionCallbacks.toList()
        notificationPermissionCallbacks.clear()
        callbacks.forEach { it(granted) }
    }
    private val nativeKakaoCoordinatorDelegate = lazy {
        NativeKakaoSignInCoordinator(
            activity = this,
            handoffClient = NativeAuthHandoffClient()
        )
    }
    private val nativeKakaoCoordinator by nativeKakaoCoordinatorDelegate
    private val socialAuthCoordinator by lazy {
        SocialAuthCoordinator(
            startKakao = nativeKakaoCoordinator::start,
            openSystemAuth = ::openSystemAuth
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        pendingAuthUrl = savedInstanceState?.getString(PENDING_AUTH_URL_KEY)
        delegate.setCurrentNavigator(navigatorConfigurations().first())
        handleAuthCallbackIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthCallbackIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onNavigatorReady(navigator: Navigator) {
        super.onNavigatorReady(navigator)
        readyNavigator = navigator

        pendingAuthUrl?.let { authUrl ->
            navigator.route(authUrl)
            pendingAuthUrl = null
        }

        pendingNotificationRoute.consume()?.let(navigator::route)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        pendingAuthUrl?.let { authUrl ->
            outState.putString(PENDING_AUTH_URL_KEY, authUrl)
        }
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        readyNavigator = null
        if (nativeKakaoCoordinatorDelegate.isInitialized()) {
            nativeKakaoCoordinatorDelegate.value.invalidate()
        }
        super.onDestroy()
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "study",
            startLocation = BuildConfig.BASE_URL,
            navigatorHostId = R.id.nav_host_study
        )
    )

    private fun handleAuthCallbackIntent(intent: Intent?) {
        val authUrl = intent?.let { callbackIntent ->
            NativeAuthCallbackConsumer.consume(
                source = IntentNativeAuthCallbackSource(callbackIntent),
                baseUrl = BuildConfig.BASE_URL
            )
        } ?: return

        routeTokenAuthUrl(authUrl)
    }

    internal fun dispatchSocialAuth(route: SocialAuthRoute) {
        socialAuthCoordinator.start(route)
    }

    internal fun routeNativeAuthCallback(callbackUrl: String) {
        val authUrl = NativeAuthCallback.toTokenAuthUrl(
            callbackUrl = callbackUrl,
            baseUrl = BuildConfig.BASE_URL
        ) ?: return

        routeTokenAuthUrl(authUrl)
    }

    private fun routeTokenAuthUrl(authUrl: String) {
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

    override fun requestNotificationPermission(callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback(true)
            return
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            callback(true)
            return
        }

        val preferences = getSharedPreferences(PUSH_PERMISSION_PREFERENCES, MODE_PRIVATE)
        if (preferences.getBoolean(PUSH_PERMISSION_REQUESTED_KEY, false)) {
            callback(false)
            return
        }

        notificationPermissionCallbacks += callback
        if (notificationPermissionCallbacks.size > 1) return

        preferences.edit().putBoolean(PUSH_PERMISSION_REQUESTED_KEY, true).apply()
        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        intent ?: return

        val explicitDestination = intent.getStringExtra(NOTIFICATION_DESTINATION_EXTRA)
        val destination = when {
            explicitDestination != null -> NotificationDestination.resolve(
                explicitDestination,
                null,
                BuildConfig.BASE_URL
            )
            intent.hasExtra("path") || intent.hasExtra("url") -> NotificationPayload.destination(
                mapOf(
                    "path" to intent.getStringExtra("path").orEmpty(),
                    "url" to intent.getStringExtra("url").orEmpty()
                ),
                BuildConfig.BASE_URL
            )
            else -> return
        }

        val navigator = readyNavigator
        if (navigator != null) {
            navigator.route(destination)
        } else {
            pendingNotificationRoute.accept(destination)
        }
        intent.removeExtra(NOTIFICATION_DESTINATION_EXTRA)
        intent.removeExtra("path")
        intent.removeExtra("url")
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

private class IntentNativeAuthCallbackSource(
    private val intent: Intent
) : NativeAuthCallbackSource {
    override var callbackUrl: String?
        get() = intent.dataString
        set(value) {
            intent.data = value?.toUri()
        }
}
