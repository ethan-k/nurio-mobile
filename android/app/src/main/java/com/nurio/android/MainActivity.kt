package com.nurio.android

import android.Manifest
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import androidx.activity.enableEdgeToEdge
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.airbnb.lottie.LottieAnimationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class MainActivity : HotwireActivity() {
    private var navigatorReady = false
    private var pendingRouteUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        showSplashAnimation(coldStart = savedInstanceState == null)
        delegate.setCurrentNavigator(navigatorConfigurations().first())
        requestNotificationPermissionIfNeeded()
        handleLaunchIntent(intent)
    }

    private fun showSplashAnimation(coldStart: Boolean) {
        val splashView = findViewById<LottieAnimationView>(R.id.splash_animation)

        if (!coldStart) {
            splashView.visibility = View.GONE
            return
        }

        splashView.addAnimatorListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                splashView.animate()
                    .alpha(0f)
                    .setDuration(250)
                    .withEndAction { splashView.visibility = View.GONE }
                    .start()
            }
        })
        splashView.playAnimation()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLaunchIntent(intent)
    }

    override fun onNavigatorReady(navigator: Navigator) {
        super.onNavigatorReady(navigator)
        navigatorReady = true

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
        handleAuthCallbackIntent(intent) ||
            handlePaymentCallbackIntent(intent) ||
            handleAppOpenIntent(intent) ||
            handleWebLinkIntent(intent) ||
            handleNotificationIntent(intent)
    }

    private fun handleAuthCallbackIntent(intent: Intent?): Boolean {
        val authUrl = intent?.data
            ?.takeIf { it.scheme == "nurio" && it.host == "auth-callback" }
            ?.let(::buildTokenAuthUrl)
            ?: return false

        routeWhenReady(authUrl)
        return true
    }

    private fun handlePaymentCallbackIntent(intent: Intent?): Boolean {
        val completeUrl = intent?.data
            ?.takeIf { it.scheme == "nurio" && it.host == "payment-complete" }
            ?.let(::buildPaymentCompleteUrl)
            ?: return false

        routeWhenReady(completeUrl)
        return true
    }

    private fun handleAppOpenIntent(intent: Intent?): Boolean {
        val uri = intent?.data
            ?.takeIf { it.scheme == "nurio" && it.host == "open" }
            ?: return false

        val routeUrl = uri.getQueryParameter("url")
            ?.takeIf { it.isNotBlank() }
            ?.let { Uri.parse(it) }
            ?.takeIf(::isCustomerWebUri)
            ?.let(::normalizeAppUri)
            ?.toString()
            ?: "${BuildConfig.BASE_URL}/events"

        routeWhenReady(routeUrl)
        return true
    }

    private fun handleWebLinkIntent(intent: Intent?): Boolean {
        val routeUrl = intent?.data
            ?.takeIf(::isCustomerWebUri)
            ?.let(::normalizeAppUri)
            ?.toString()
            ?: return false

        routeWhenReady(routeUrl)
        return true
    }

    private fun handleNotificationIntent(intent: Intent?): Boolean {
        val path = intent?.getStringExtra("path")?.takeIf { it.isNotBlank() } ?: return false

        routeWhenReady(buildAppUrl(path))
        return true
    }

    private fun routeWhenReady(url: String) {
        val navigator = delegate.currentNavigator

        if (navigatorReady && navigator != null) {
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

    private fun buildPaymentCompleteUrl(callbackUri: Uri): String? {
        val paymentId = callbackUri.getQueryParameter("paymentId")
            ?: callbackUri.getQueryParameter("payment_id")

        // A payment-complete callback with no payment id means the gateway
        // returned without a payment (e.g. the user backed out). Send the user
        // to their tickets instead of dropping the deep link.
        if (paymentId.isNullOrBlank()) {
            return "${BuildConfig.BASE_URL.trimEnd('/')}/settings/tickets"
        }

        val builder = Uri.parse("${BuildConfig.BASE_URL.trimEnd('/')}/payments/portone/complete").buildUpon()
        callbackUri.queryParameterNames.forEach { name ->
            callbackUri.getQueryParameters(name).forEach { value ->
                builder.appendQueryParameter(name, value)
            }
        }

        if (!callbackUri.queryParameterNames.contains("paymentId")) {
            builder.appendQueryParameter("paymentId", paymentId)
        }

        return builder.build().toString()
    }

    private fun buildAppUrl(path: String): String {
        return if (path.startsWith("http://") || path.startsWith("https://")) {
            Uri.parse(path)
                .takeIf(::isCustomerWebUri)
                ?.let(::normalizeAppUri)
                ?.toString()
                ?: "${BuildConfig.BASE_URL}/events"
        } else {
            "${BuildConfig.BASE_URL.trimEnd('/')}/${path.trimStart('/')}"
        }
    }

    private fun isCustomerWebUri(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return false

        val baseHost = Uri.parse(BuildConfig.BASE_URL).host?.lowercase() ?: return false
        val host = uri.host?.lowercase() ?: return false
        if (host != baseHost && host != "www.$baseHost") return false

        val path = uri.path.orEmpty().lowercase()
        return blockedPathPrefixes.none { prefix ->
            path == prefix || path.startsWith("$prefix/")
        }
    }

    private fun normalizeAppUri(uri: Uri): Uri {
        val baseUri = Uri.parse(BuildConfig.BASE_URL)
        val baseHost = baseUri.host?.lowercase()
        val host = uri.host?.lowercase()

        return if (baseHost != null && host == "www.$baseHost") {
            uri.buildUpon()
                .scheme(baseUri.scheme)
                .authority(baseUri.authority)
                .build()
        } else {
            uri
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
        private val blockedPathPrefixes = listOf(
            "/admin",
            "/tutoring",
            "/tutors",
            "/study_group_admin"
        )
    }
}
