package com.nurio.android.routing

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.net.toUri
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router
import java.net.URI

/** nurio study is a separate product; its links leave the customer app for the browser. */
internal object StudyHostPolicy {
    fun opensInSystemBrowser(location: String, startLocation: String): Boolean {
        val uri = runCatching { URI(location) }.getOrNull() ?: return false
        val scheme = uri.scheme?.lowercase()
        if (scheme != "https" && scheme != "http") return false

        val appHost = runCatching { URI(startLocation).host }.getOrNull()?.lowercase() ?: return false
        return uri.host?.lowercase() == "study.$appHost"
    }
}

class StudyHostRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "study-host-system-browser"

    override fun matches(
        location: String,
        configuration: NavigatorConfiguration
    ): Boolean = StudyHostPolicy.opensInSystemBrowser(location, configuration.startLocation)

    override fun handle(
        location: String,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        val intent = Intent(Intent.ACTION_VIEW, location.toUri()).addCategory(Intent.CATEGORY_BROWSABLE)
        return try {
            activity.startActivity(intent)
            Router.Decision.CANCEL
        } catch (_: ActivityNotFoundException) {
            Router.Decision.NAVIGATE
        }
    }
}
