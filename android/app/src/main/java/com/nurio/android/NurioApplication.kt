package com.nurio.android

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.routing.AppNavigationRouteDecisionHandler
import dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler
import dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler
import com.nurio.android.bridge.RegisterDeviceTokenComponent
import com.nurio.android.bridge.PaymentTelemetryComponent
import com.nurio.android.bridge.SignInWithOAuthComponent
import com.nurio.android.fragments.WebFragment
import com.nurio.android.fragments.WebModalFragment
import com.nurio.android.notifications.NotificationChannels
import com.nurio.android.payments.PaymentCrashTelemetry
import com.nurio.android.routing.CheckoutColdBootRouteDecisionHandler
import com.nurio.android.routing.OAuthRouteDecisionHandler
import com.nurio.android.webview.NurioHotwireWebView
import kotlinx.serialization.json.Json

class NurioApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PaymentCrashTelemetry.reset()
        NotificationChannels.ensureCreated(this)
        configureHotwire()
    }

    private fun configureHotwire() {
        Hotwire.config.debugLoggingEnabled = BuildConfig.DEBUG_LOGGING
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
        Hotwire.config.makeCustomWebView = { context -> NurioHotwireWebView(context) }

        Hotwire.config.applicationUserAgentPrefix = "Nurio Android; NurioPaymentReturn/1"

        // Bridge components (sign-in-with-oauth, register-device-token) decode/encode
        // message JSON through Hotwire.config.jsonConverter. It is null by default, so
        // Message.data<T>() throws IllegalArgumentException unless we set one here.
        Hotwire.config.jsonConverter = KotlinXJsonConverter(
            Json { ignoreUnknownKeys = true }
        )

        Hotwire.registerRouteDecisionHandlers(
            // Must run before AppNavigationRouteDecisionHandler so checkout
            // re-entry can cold-boot a web view stuck on a payment gateway.
            CheckoutColdBootRouteDecisionHandler(),
            OAuthRouteDecisionHandler(),
            AppNavigationRouteDecisionHandler(),
            BrowserTabRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler()
        )

        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("register-device-token", ::RegisterDeviceTokenComponent),
            BridgeComponentFactory("payment-telemetry", ::PaymentTelemetryComponent),
            BridgeComponentFactory("sign-in-with-oauth", ::SignInWithOAuthComponent)
        )

        Hotwire.defaultFragmentDestination = WebFragment::class
        Hotwire.registerFragmentDestinations(
            WebFragment::class,
            WebModalFragment::class
        )

        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json"
            )
        )
    }
}
