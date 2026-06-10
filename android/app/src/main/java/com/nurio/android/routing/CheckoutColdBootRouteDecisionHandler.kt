package com.nurio.android.routing

import android.webkit.CookieManager
import android.webkit.WebStorage
import androidx.core.net.toUri
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

/**
 * Forces a checkout page to cold-boot when the navigator's web view is still
 * parked on an external payment-gateway page from a previous attempt.
 *
 * Why: the PortOne SDK submits a form POST to KG Inicis inside the Turbo web
 * view. If the user abandons the gateway and re-enters checkout, the session
 * would otherwise attempt a JavaScript visit on a page without Turbo's runtime,
 * re-showing the stale gateway page. The abandoned gateway session cookies also
 * poison the retry — Inicis rejects it with "비정상적인 접근" (code 01) even
 * though the order id rotates per attempt.
 *
 * Mirror of iOS `CheckoutColdBootWebViewPolicyDecisionHandler`; the full
 * constraints are documented in `ios/docs/PAYMENT_FLOW.md`. This handler only
 * matches on-origin checkout *entry* URLs, so the outbound gateway POST (which
 * must never be intercepted or re-issued) is untouched, as are the order
 * confirmation page and the payment-complete return.
 */
class CheckoutColdBootRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "checkout-cold-boot"

    override fun matches(
        location: String,
        configuration: NavigatorConfiguration
    ): Boolean {
        val locationUri = location.toUri()
        val scheme = locationUri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return false

        val baseHost = configuration.startLocation.toUri().host?.lowercase() ?: return false
        val host = locationUri.host?.lowercase() ?: return false
        if (host != baseHost && host != "www.$baseHost") return false

        return isCheckoutEntryPath(locationUri.path.orEmpty())
    }

    override fun handle(
        location: String,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        val session = activity.delegate.currentNavigator?.session
        val stuckUrl = session?.webView?.url
        val baseHost = configuration.startLocation.toUri().host?.lowercase()

        if (session != null && stuckUrl != null && baseHost != null && isOffOrigin(stuckUrl, baseHost)) {
            clearGatewayWebData(stuckUrl)
            session.reset()
        }

        return Router.Decision.NAVIGATE
    }

    private fun isCheckoutEntryPath(path: String): Boolean {
        return path == "/orders/new" ||
            path.endsWith("/payment_summary") ||
            path.endsWith("/purchase")
    }

    private fun isOffOrigin(url: String, baseHost: String): Boolean {
        val uri = url.toUri()
        val scheme = uri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return false

        val host = uri.host?.lowercase() ?: return false
        return host != baseHost && host != "www.$baseHost"
    }

    /**
     * Expires cookies and removes web storage for the stuck gateway's domain
     * (and its parent domains, e.g. `ksmobile.inicis.com` → `.inicis.com`).
     * The app origin is never touched — [isOffOrigin] guarantees the stuck URL
     * is foreign before this is called.
     */
    private fun clearGatewayWebData(stuckUrl: String) {
        val uri = stuckUrl.toUri()
        val host = uri.host?.lowercase() ?: return

        val cookieManager = CookieManager.getInstance()
        val cookieNames = cookieManager.getCookie(stuckUrl)
            .orEmpty()
            .split(";")
            .mapNotNull { it.substringBefore("=").trim().takeIf(String::isNotEmpty) }

        val domains = parentDomains(host)
        cookieNames.forEach { cookieName ->
            cookieManager.setCookie(stuckUrl, "$cookieName=; Max-Age=0; Path=/")
            domains.forEach { domain ->
                cookieManager.setCookie("https://$domain", "$cookieName=; Max-Age=0; Path=/; Domain=$domain")
            }
        }
        cookieManager.flush()

        WebStorage.getInstance().deleteOrigin("${uri.scheme}://$host")
    }

    /** `a.b.example.com` → `[a.b.example.com, b.example.com, example.com]`. */
    private fun parentDomains(host: String): List<String> {
        val labels = host.split(".")
        if (labels.size < 2) return listOf(host)

        return (0..labels.size - 2).map { start ->
            labels.subList(start, labels.size).joinToString(".")
        }
    }
}
