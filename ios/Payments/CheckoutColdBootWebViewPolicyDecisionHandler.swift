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
                if let modalURL = navigator.modalSession.webView.url,
                   CheckoutNavigation.isOffOrigin(modalURL, baseURL: AppEnvironment.baseURL) {
                    navigator.modalSession.markContentAsStale()
                }

                navigator.route(url)
            }
        }

        return .cancel
    }
}

/// Pure routing rules for checkout entry detection.
enum CheckoutNavigation {
    static func isCheckoutEntry(_ url: URL, baseURL: URL) -> Bool {
        guard isOnOrigin(url, baseURL: baseURL) else { return false }

        let path = url.path
        return path.hasPrefix("/orders") || path.hasPrefix("/pass_packages")
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
