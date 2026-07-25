package com.nurio.studyleader.android

import android.app.Application
import com.kakao.sdk.common.KakaoSdk
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.logging.HotwireLogLevel
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.routing.AppNavigationRouteDecisionHandler
import dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler
import dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler
import com.nurio.studyleader.android.bridge.SignInWithOAuthComponent
import com.nurio.studyleader.android.fragments.WebFragment
import com.nurio.studyleader.android.fragments.WebModalFragment
import com.nurio.studyleader.android.routing.LeaderScopeRouteDecisionHandler
import com.nurio.studyleader.android.routing.OAuthRouteDecisionHandler

class StudyLeaderApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.KAKAO_NATIVE_APP_KEY.isNotBlank()) {
            KakaoSdk.init(this, BuildConfig.KAKAO_NATIVE_APP_KEY)
        }
        configureHotwire()
    }

    private fun configureHotwire() {
        Hotwire.config.logger.logLevel =
            if (BuildConfig.DEBUG_LOGGING) HotwireLogLevel.DEBUG else HotwireLogLevel.NONE
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        Hotwire.config.applicationUserAgentPrefix = "Nurio Study Leader Android"

        Hotwire.registerRouteDecisionHandlers(
            LeaderScopeRouteDecisionHandler(),
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
