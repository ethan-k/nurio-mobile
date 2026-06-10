import Foundation
import HotwireNative
import WebKit

/// Forces a checkout page to **cold-boot** when the modal session's web view is
/// still parked on an external payment-gateway page from a previous attempt.
///
/// Why: Hotwire Native reuses one web view per session. After "pay by card" the
/// modal web view navigates to the gateway (Inicis). When the user backs out and
/// re-enters checkout, the framework sees the session as still `initialized` and
/// attempts a *JavaScript* visit — but a JS visit needs Turbo's runtime on the
/// current page, and the current page is the foreign gateway. The visit collapses
/// and the cached gateway page is re-shown instead of a fresh checkout.
///
/// This handler detects that re-entry, marks the modal session content stale so
/// `visitableViewWillAppear` cold-boots it, then routes as usual. It never touches
/// the outbound gateway navigation (that is off-origin), so the form POST that
/// carries `P_INIT_PAYMENT` is left completely intact.
struct CheckoutColdBootWebViewPolicyDecisionHandler: WebViewPolicyDecisionHandler {
    let name = "checkout-cold-boot-policy"

    func matches(navigationAction: WKNavigationAction, configuration: Navigator.Configuration) -> Bool {
        guard navigationAction.targetFrame?.isMainFrame ?? false,
              navigationAction.navigationType == .other || navigationAction.navigationType == .linkActivated,
              let destination = navigationAction.request.url else {
            return false
        }

        return CheckoutNavigation.isCheckoutEntry(destination, baseURL: AppEnvironment.baseURL)
    }

    func handle(
        navigationAction: WKNavigationAction,
        configuration: Navigator.Configuration,
        navigator: Navigator
    ) -> WebViewPolicyManager.Decision {
        if let url = navigationAction.request.url {
            Task { @MainActor in
                let stuckGatewayURL = navigator.modalSession.webView.url.flatMap { modalURL in
                    CheckoutNavigation.isOffOrigin(modalURL, baseURL: AppEnvironment.baseURL) ? modalURL : nil
                }

                if let stuckGatewayURL {
                    // Drop the abandoned gateway's cookies/session so the retry starts
                    // clean — Korean PGs (KG Inicis) reject a reused session with
                    // "비정상적인 접근" even when the order id is fresh.
                    PaymentGatewayData.clear(forStuckURL: stuckGatewayURL)
                }

                navigator.route(url)

                // Force the NEW checkout visitable to cold-boot. A JavaScript visit
                // can't run on the gateway page (no Turbo runtime), and reloading the
                // session would re-fetch the gateway URL as a GET — which Inicis
                // rejects with payError.ini. Cold-booting the fresh visitable loads
                // only the checkout URL.
                if stuckGatewayURL != nil,
                   let visitable = navigator.modalRootViewController.topViewController as? VisitableViewController,
                   visitable.initialVisitableURL == url {
                    navigator.modalSession.visit(visitable, options: VisitOptions(action: .replace), reload: true)
                }
            }
        }

        return .cancel
    }
}

/// Clears web-view data for an abandoned payment gateway so a retry starts clean.
enum PaymentGatewayData {
    /// Removes cookies / storage / cache for the registrable domain of the gateway
    /// page the modal web view is stuck on (e.g. `inicis.com` for
    /// `ksmobile.inicis.com`). Leaves nurio and all other domains untouched.
    @MainActor
    static func clear(forStuckURL url: URL) {
        guard let host = url.host?.lowercased() else { return }

        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            let targets = records.filter { record in
                let name = record.displayName.lowercased()
                return !name.isEmpty && (host == name || host.hasSuffix(".\(name)"))
            }

            guard !targets.isEmpty else { return }
            store.removeData(ofTypes: types, for: targets) {}
        }
    }
}

/// Pure routing rules for checkout entry detection.
enum CheckoutNavigation {
    static func isCheckoutEntry(_ url: URL, baseURL: URL) -> Bool {
        guard isOnOrigin(url, baseURL: baseURL) else { return false }

        // Only the checkout *entry* points — never the order confirmation page
        // (/orders/:id) or the payment-complete return, which must navigate normally.
        let path = url.path
        return path == "/orders/new" ||
            path.hasSuffix("/payment_summary") ||
            path.hasSuffix("/purchase")
    }

    static func isOnOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard let host = url.host?.lowercased(), let baseHost = baseURL.host?.lowercased() else {
            return false
        }

        return host == baseHost || host == "www.\(baseHost)"
    }

    static func isOffOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }

        return !isOnOrigin(url, baseURL: baseURL)
    }
}
