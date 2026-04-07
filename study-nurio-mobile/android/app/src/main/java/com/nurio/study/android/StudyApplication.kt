package com.nurio.study.android

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.routing.AppNavigationRouteDecisionHandler
import dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler
import dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler
import com.nurio.study.android.bridge.SignInWithOAuthComponent
import com.nurio.study.android.fragments.WebFragment
import com.nurio.study.android.fragments.WebModalFragment
import com.nurio.study.android.routing.OAuthRouteDecisionHandler

class StudyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        configureHotwire()
    }

    private fun configureHotwire() {
        Hotwire.config.debugLoggingEnabled = BuildConfig.DEBUG_LOGGING
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        Hotwire.config.applicationUserAgentPrefix = "Nurio Study Android"

        Hotwire.registerRouteDecisionHandlers(
            OAuthRouteDecisionHandler(),
            AppNavigationRouteDecisionHandler(),
            BrowserTabRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler()
        )

        Hotwire.registerBridgeComponents(
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
