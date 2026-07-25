package com.nurio.studyleader.android.routing

import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import dev.hotwire.core.turbo.visit.VisitProposal
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

class LeaderScopeRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "leader-scope"

    override fun matches(
        proposal: VisitProposal,
        configuration: NavigatorConfiguration
    ): Boolean {
        return LeaderScopePolicy.shouldOpenExternally(proposal.location, configuration.startLocation)
    }

    override fun handle(
        proposal: VisitProposal,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            .build()
            .launchUrl(activity, proposal.location.toUri())

        return Router.Decision.CANCEL
    }
}
