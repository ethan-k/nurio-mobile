package com.nurio.study.android.routing

import com.nurio.study.android.BuildConfig
import com.nurio.study.android.MainActivity
import com.nurio.study.android.auth.SocialAuthRoute
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

class OAuthRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "oauth-browser-tab"

    override fun matches(
        location: String,
        configuration: NavigatorConfiguration
    ): Boolean {
        return SocialAuthRoute.resolve(location, BuildConfig.BASE_URL) != null
    }

    override fun handle(
        location: String,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        val route = SocialAuthRoute.resolve(location, BuildConfig.BASE_URL)
            ?: return Router.Decision.CANCEL
        (activity as? MainActivity)?.dispatchSocialAuth(route)

        return Router.Decision.CANCEL
    }
}
