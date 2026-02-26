package com.nurio.android

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import com.nurio.android.bridge.SignInWithOAuthComponent
import com.nurio.android.fragments.WebFragment
import com.nurio.android.fragments.WebModalFragment

class NurioApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        configureHotwire()
    }

    private fun configureHotwire() {
        Hotwire.config.debugLoggingEnabled = BuildConfig.DEBUG_LOGGING
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        Hotwire.config.applicationUserAgentPrefix = "Nurio Android"

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
