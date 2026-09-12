import Foundation
import HotwireNative
import UIKit
import WebKit

/// Observe the gateway navigation without cancelling or replaying its POST.
@MainActor
struct PaymentGatewayWebViewPolicyDecisionHandler: @preconcurrency WebViewPolicyDecisionHandler {
    let name = "payment-gateway-presentation"

    func matches(navigationAction: WKNavigationAction, configuration: Navigator.Configuration) -> Bool {
        guard navigationAction.targetFrame?.isMainFrame == true,
              let url = navigationAction.request.url else { return false }
        return PaymentGatewayPresentation.isGatewayURL(url) ||
            PaymentGatewayPresentation.isCompletionURL(url, baseURL: configuration.startLocation)
    }

    func handle(navigationAction: WKNavigationAction, configuration: Navigator.Configuration, navigator: any Navigating) -> WebViewPolicyManager.Decision {
        guard let navigator = navigator as? Navigator,
              let url = navigationAction.request.url else { return .allow }

        if PaymentGatewayPresentation.isCompletionURL(url, baseURL: configuration.startLocation) {
            if PaymentGatewayPresentation.shared.completionURLBeingRouted == url { return .allow }
            Task { @MainActor in
                PaymentGatewayPresentation.shared.routeAppReturn(url, navigator: navigator)
            }
            return .cancel
        }

        Task { @MainActor in
            PaymentGatewayPresentation.shared.presentGateway(navigator: navigator)
        }
        return .allow
    }
}

@MainActor
final class PaymentGatewayPresentation {
    static let shared = PaymentGatewayPresentation()

    private(set) var gatewayController: PaymentGatewayViewController?
    private(set) var completionURLBeingRouted: URL?
    private var closing = false
    private var pendingPaymentReturn: (() -> Void)?

    nonisolated static func isGatewayURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return host == "inicis.com" || host.hasSuffix(".inicis.com")
    }

    nonisolated static func isCompletionURL(_ url: URL, baseURL: URL) -> Bool {
        CheckoutNavigation.isSafeReloadURL(url, baseURL: baseURL) && url.path == "/payments/portone/complete"
    }

    func presentGateway(navigator: Navigator) {
        guard gatewayController == nil, !closing,
              navigator.activeNavigationController.presentedViewController == nil else { return }
        let session = navigator.activeNavigationController === navigator.rootViewController ? navigator.session : navigator.modalSession
        guard let source = session.activeVisitable as? VisitableViewController,
              CheckoutNavigation.isSafeReloadURL(source.initialVisitableURL, baseURL: AppEnvironment.baseURL),
              source.visitableView.webView === session.webView else { return }

        let controller = PaymentGatewayViewController(source: source)
        let modal = UINavigationController(rootViewController: controller)
        modal.modalPresentationStyle = .pageSheet
        modal.isModalInPresentation = true
        if let sheet = modal.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        completionURLBeingRouted = nil
        gatewayController = controller
        controller.onClose = { [weak self, weak controller] in
            guard let self, let controller else { return }
            controller.navigationItem.leftBarButtonItem?.isEnabled = false
            let returnURL = source.initialVisitableURL
            let finish = {
                guard self.gatewayController === controller else { return }
                self.dismissGateway {
                    // Closing abandons the gateway page. Load only the merchant
                    // page, never replay the provider initialization POST.
                    self.routeMerchantURL(returnURL, navigator: navigator, replace: true)
                }
            }
            if !CheckoutNavigation.isRecoveryDestination(returnURL, baseURL: AppEnvironment.baseURL),
               let gatewayURL = source.visitableView.webView?.url,
               CheckoutNavigation.isOffOrigin(gatewayURL, baseURL: AppEnvironment.baseURL) {
                PaymentGatewayData.clear(forStuckURL: gatewayURL, completion: finish)
            } else { finish() }
        }
        controller.takeCheckoutView()
        navigator.activeNavigationController.present(modal, animated: true)
    }

    func routeAppReturn(_ url: URL, navigator: Navigator) {
        guard CheckoutNavigation.isSafeReloadURL(url, baseURL: AppEnvironment.baseURL) else {
            navigator.route(url)
            return
        }
        let isCompletion = Self.isCompletionURL(url, baseURL: AppEnvironment.baseURL)
        if isCompletion {
            // A provider result arriving during a Close animation must win over
            // the cancellation destination, rather than being dropped.
            pendingPaymentReturn = { self.routeMerchantURL(url, navigator: navigator, replace: true) }
        }
        dismissGateway {
            self.routeMerchantURL(url, navigator: navigator, replace: isCompletion)
        }
    }

    func errorController(for visitable: any Visitable) -> UIViewController? {
        guard gatewayController?.source === visitable else { return nil }
        return gatewayController
    }

    private func dismissGateway(completion: @escaping () -> Void) {
        guard let controller = gatewayController else {
            finishDismissal(completion)
            return
        }
        guard !closing else { return }
        closing = true
        controller.navigationController?.dismiss(animated: true) {
            controller.restoreCheckoutView()
            self.gatewayController = nil
            self.closing = false
            self.finishDismissal(completion)
        }
    }

    private func finishDismissal(_ fallback: () -> Void) {
        let paymentReturn = pendingPaymentReturn
        pendingPaymentReturn = nil
        if let paymentReturn { paymentReturn() } else { fallback() }
    }

    private func routeMerchantURL(_ url: URL, navigator: Navigator, replace: Bool) {
        if Self.isCompletionURL(url, baseURL: AppEnvironment.baseURL) {
            completionURLBeingRouted = url
        }
        // CheckoutVisitRecovery owns checkout/completion cold boots at the
        // navigator proposal boundary, including Turbo and native callbacks.
        if CheckoutNavigation.isRecoveryDestination(url, baseURL: AppEnvironment.baseURL) {
            navigator.route(url, options: VisitOptions(action: replace ? .replace : .advance))
            return
        }
        let properties = navigator.session.pathConfiguration?.properties(for: url)
        let usesModal = properties?["context"] as? String == "modal"
        let session = usesModal ? navigator.modalSession : navigator.session
        let navigationController = usesModal ? navigator.modalRootViewController : navigator.rootViewController
        let needsColdBoot = session.webView.url.map { !CheckoutNavigation.isSafeReloadURL($0, baseURL: AppEnvironment.baseURL) } ?? false
        navigator.route(url, options: VisitOptions(action: replace ? .replace : .advance))
        if needsColdBoot {
            DispatchQueue.main.async { [weak navigator] in
                guard navigator != nil,
                      let visitable = navigationController.topViewController as? VisitableViewController,
                      visitable.initialVisitableURL == url else { return }
                session.visit(visitable, options: VisitOptions(action: .replace), reload: true)
            }
        }
    }
}

/// Reparents the existing checkout view, including its WKWebView. The document,
/// JavaScript, submitted request and cookies remain in the same live session.
@MainActor
final class PaymentGatewayViewController: UIViewController, WKUIDelegate {
    let source: VisitableViewController
    var onClose: (() -> Void)?

    private weak var originalDelegate: (any VisitableDelegate)?
    private weak var originalWebUIDelegate: (any WKUIDelegate)?
    private var placeholder: UIView?
    private var originalPullToRefresh = false
    private var ownsCheckoutView = false

    init(source: VisitableViewController) {
        self.source = source
        super.init(nibName: nil, bundle: nil)
        title = "Payment"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    func takeCheckoutView() {
        guard !ownsCheckoutView else { return }
        source.loadViewIfNeeded()
        loadViewIfNeeded()
        originalDelegate = source.visitableDelegate
        originalWebUIDelegate = source.visitableView.webView?.uiDelegate
        source.visitableView.webView?.uiDelegate = self
        // UIKit may hide the source controller when a sheet adapts to full screen.
        // Keep Hotwire from deactivating its still-live payment view in that case.
        source.visitableDelegate = nil
        originalPullToRefresh = source.visitableView.allowsPullToRefresh
        source.visitableView.allowsPullToRefresh = false
        placeholder = source.view.snapshotView(afterScreenUpdates: false)
        if let placeholder {
            placeholder.frame = source.view.bounds
            placeholder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            source.view.addSubview(placeholder)
        }
        attach(source.visitableView, to: view, respectsSafeArea: true)
        ownsCheckoutView = true
    }

    func restoreCheckoutView() {
        guard ownsCheckoutView else { return }
        attach(source.visitableView, to: source.view)
        source.visitableView.allowsPullToRefresh = originalPullToRefresh
        source.visitableDelegate = originalDelegate
        source.visitableView.webView?.uiDelegate = originalWebUIDelegate
        placeholder?.removeFromSuperview()
        placeholder = nil
        ownsCheckoutView = false
    }

    private func attach(_ content: UIView, to parent: UIView, respectsSafeArea: Bool = false) {
        content.removeFromSuperview()
        parent.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            content.topAnchor.constraint(equalTo: respectsSafeArea ? parent.safeAreaLayoutGuide.topAnchor : parent.topAnchor),
            content.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])
    }

    @objc private func close() { onClose?() }

    // Keep the existing popup/window behavior, but present gateway JavaScript
    // dialogs from the visible sheet instead of the covered root navigator.
    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || originalWebUIDelegate?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if originalWebUIDelegate?.responds(to: selector) == true { return originalWebUIDelegate }
        return super.forwardingTarget(for: selector)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in completionHandler(alert?.textFields?.first?.text) })
        present(alert, animated: true)
    }
}
