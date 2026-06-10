import Foundation
import HotwireNative
import UIKit
import WebKit

/// Intercepts the main-frame redirect that leaves a nurio checkout page for an
/// external payment gateway (PortOne / Inicis) and runs it in a dedicated native
/// modal instead of letting it take over the Turbo session's web view.
///
/// Scope is deliberately narrow: it only fires when an on-origin **checkout**
/// page redirects the main frame to an off-origin http(s) URL. Native OAuth runs
/// through `ASWebAuthenticationSession`, and OAuth provider redirects originate
/// from `/auth/*` pages, so this handler never captures them.
struct PaymentFlowWebViewPolicyDecisionHandler: WebViewPolicyDecisionHandler {
    let name = "payment-flow-policy"

    func matches(navigationAction: WKNavigationAction, configuration: Navigator.Configuration) -> Bool {
        guard navigationAction.targetFrame?.isMainFrame ?? false,
              let destination = navigationAction.request.url else {
            return false
        }

        return PaymentGatewayNavigation.isCheckoutHandoff(
            to: destination,
            from: navigationAction.sourceFrame.request.url,
            baseURL: AppEnvironment.baseURL
        )
    }

    func handle(
        navigationAction: WKNavigationAction,
        configuration: Navigator.Configuration,
        navigator: Navigator
    ) -> WebViewPolicyManager.Decision {
        if let url = navigationAction.request.url {
            Task { @MainActor in
                PaymentFlowPresenter.present(url: url, from: navigator)
            }
        }

        return .cancel
    }
}

/// Pure routing rules for recognizing a checkout → gateway handoff.
enum PaymentGatewayNavigation {
    static func isCheckoutHandoff(to destination: URL, from source: URL?, baseURL: URL) -> Bool {
        guard let scheme = destination.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        guard isOffOrigin(destination, baseURL: baseURL) else { return false }
        guard let source, isOnOrigin(source, baseURL: baseURL), isCheckoutPath(source.path) else {
            return false
        }

        return true
    }

    static func isCheckoutPath(_ path: String) -> Bool {
        path.contains("/payment_summary") ||
            path.hasPrefix("/orders") ||
            path.hasPrefix("/pass_packages")
    }

    private static func isOnOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard let host = url.host?.lowercased(), let baseHost = baseURL.host?.lowercased() else {
            return false
        }

        return host == baseHost || host == "www.\(baseHost)"
    }

    private static func isOffOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard let host = url.host?.lowercased(), let baseHost = baseURL.host?.lowercased() else {
            return false
        }

        return host != baseHost && host != "www.\(baseHost)"
    }
}

/// Presents the payment flow modal, guarding against double presentation.
@MainActor
enum PaymentFlowPresenter {
    static func present(url: URL, from navigator: Navigator) {
        let presenter = navigator.activeNavigationController
        if presenter.presentedViewController is PaymentFlowHostController {
            return
        }

        let paymentViewController = PaymentFlowViewController(
            url: url,
            onComplete: { completeURL in
                AppRouteCoordinator.shared.handleIncoming(completeURL)
            },
            onCancel: {}
        )

        let host = PaymentFlowHostController(rootViewController: paymentViewController)
        host.modalPresentationStyle = .fullScreen
        presenter.present(host, animated: true)
    }
}

/// Marker subclass so the presenter can detect an in-flight payment modal.
final class PaymentFlowHostController: UINavigationController {}
