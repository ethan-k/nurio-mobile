package com.nurio.tutors.routing

import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

class OAuthRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "oauth-browser-tab"

    private val oauthPaths = setOf(
        "/auth/google_oauth2",
        "/auth/kakao",
        "/auth/naver"
    )

    override fun matches(
        location: String,
        configuration: NavigatorConfiguration
    ): Boolean {
        val locationUri = location.toUri()
        val startLocationUri = configuration.startLocation.toUri()

        return startLocationUri.host == locationUri.host &&
            (locationUri.scheme?.lowercase() == "https" || locationUri.scheme?.lowercase() == "http") &&
            oauthPaths.contains(locationUri.path)
    }

    override fun handle(
        location: String,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        val colorParams = CustomTabColorSchemeParams.Builder()
            .build()

        CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            .setUrlBarHidingEnabled(false)
            .setDefaultColorSchemeParams(colorParams)
            .build()
            .launchUrl(activity, location.toUri())

        return Router.Decision.CANCEL
    }
}
