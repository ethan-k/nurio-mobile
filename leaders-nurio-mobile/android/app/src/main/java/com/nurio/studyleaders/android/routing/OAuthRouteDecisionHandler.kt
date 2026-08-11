package com.nurio.studyleaders.android.routing

import com.nurio.studyleaders.android.MainActivity
import com.nurio.studyleaders.android.auth.SocialAuthRoute
import dev.hotwire.core.turbo.visit.VisitProposal
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

class OAuthRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "oauth-browser-tab"

    override fun matches(
        proposal: VisitProposal,
        configuration: NavigatorConfiguration
    ): Boolean {
        return SocialAuthRoute.resolve(
            proposal.location,
            configuration.startLocation
        ) != null
    }

    override fun handle(
        proposal: VisitProposal,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        val route = SocialAuthRoute.resolve(
            proposal.location,
            configuration.startLocation
        ) ?: return Router.Decision.CANCEL
        (activity as? MainActivity)?.dispatchSocialAuth(route)

        return Router.Decision.CANCEL
    }
}
