import Foundation
import HotwireNative
import WebKit

/// Routes non-Turbo checkout navigation through the same navigator entry point
/// as Turbo visits. Recovery belongs there: a restored modal can still contain
/// the gateway page, which cannot execute Turbo's JavaScript visits.
/// Outbound gateway form POSTs continue through WebKit unchanged.
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
        navigator: any Navigating
    ) -> WebViewPolicyManager.Decision {
        if let url = navigationAction.request.url {
            Task { @MainActor in navigator.route(url) }
        }

        return .cancel
    }
}

/// Turbo link visits and native payment callbacks bypass WKNavigationAction.
/// Recover at the navigator proposal boundary so every checkout entry is covered.
@MainActor
enum CheckoutVisitRecovery {
    static func controller(for proposal: VisitProposal, navigator: Navigator) -> VisitableViewController? {
        guard CheckoutNavigation.isRecoveryDestination(proposal.url, baseURL: AppEnvironment.baseURL) else {
            return nil
        }

        let isModal = proposal.context == .modal
        let session = isModal ? navigator.modalSession : navigator.session
        guard let gatewayURL = session.webView.url,
              CheckoutNavigation.isOffOrigin(gatewayURL, baseURL: AppEnvironment.baseURL) else {
            return nil
        }

        let controller = Hotwire.config.defaultViewController(proposal.url)
        // The navigator must finish attaching this exact destination before the
        // forced visit. Never reload the abandoned gateway's POST-only URL.
        DispatchQueue.main.async { [weak navigator, weak controller] in
            guard let navigator, let controller else { return }
            let navigationController = isModal ? navigator.modalRootViewController : navigator.rootViewController
            guard navigationController.topViewController === controller,
                  !navigationController.isBeingDismissed else { return }

            PaymentGatewayData.clear(forStuckURL: gatewayURL) {
                let currentSession = isModal ? navigator.modalSession : navigator.session
                guard currentSession === session,
                      navigationController.topViewController === controller,
                      !navigationController.isBeingDismissed else { return }

                PaymentCrashTelemetry.logRetryColdBoot()
                session.visit(controller, options: VisitOptions(action: proposal.options.action), reload: true)
            }
        }
        return controller
    }
}

/// Clears web-view data for an abandoned payment gateway so a retry starts clean.
enum PaymentGatewayData {
    /// Removes cookies / storage / cache for the registrable domain of the gateway
    /// page the checkout web view is stuck on (e.g. `inicis.com` for
    /// `ksmobile.inicis.com`). Leaves nurio and all other domains untouched.
    @MainActor
    static func clear(forStuckURL url: URL, completion: @escaping () -> Void) {
        guard let host = url.host?.lowercased() else {
            completion()
            return
        }

        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            let targets = records.filter { record in
                let name = record.displayName.lowercased()
                return !name.isEmpty && (host == name || host.hasSuffix(".\(name)"))
            }

            guard !targets.isEmpty else {
                completion()
                return
            }
            store.removeData(ofTypes: types, for: targets, completionHandler: completion)
        }
    }
}

/// Pure routing rules for checkout entry detection.
enum CheckoutNavigation {
    static func isRecoveryDestination(_ url: URL, baseURL: URL) -> Bool {
        isSafeReloadURL(url, baseURL: baseURL) &&
            (isCheckoutEntry(url, baseURL: baseURL) || url.path == "/payments/portone/complete")
    }

    /// Hotwire's default retry calls Session.reload(), which must not reload a
    /// gateway URL. Check both the original visit and its current destination.
    static func safeRetryHandler(
        _ retryHandler: (() -> Void)?,
        initialURL: URL,
        currentURL: URL,
        baseURL: URL
    ) -> (() -> Void)? {
        guard isSafeReloadURL(initialURL, baseURL: baseURL),
              isSafeReloadURL(currentURL, baseURL: baseURL) else { return nil }
        return retryHandler
    }

    static func isSafeReloadURL(_ url: URL, baseURL: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              scheme == baseURL.scheme?.lowercased(),
              isOnOrigin(url, baseURL: baseURL) else { return false }

        let defaultPort = scheme == "https" ? 443 : 80
        return (url.port ?? defaultPort) == (baseURL.port ?? defaultPort)
    }

    // Merchant selection/confirmation stays full screen. Only the live gateway
    // view is presented as a modal, without changing its Hotwire session.
    static func usesMainSession(_ url: URL) -> Bool {
        url.path == "/orders/new" || url.path.hasSuffix("/payment_summary") || url.path.hasSuffix("/purchase")
    }

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
