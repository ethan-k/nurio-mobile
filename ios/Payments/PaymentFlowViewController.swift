import OSLog
import UIKit
import WebKit

private let paymentLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "payment"
)

/// Hosts the external payment-gateway (PortOne / Inicis) flow in a dedicated
/// modal web view so it never hijacks the Turbo session's web view.
///
/// Why this exists: the PortOne browser SDK performs a top-level redirect to the
/// PG when paying by card. If that redirect runs inside the Turbo web view, the
/// app is left parked on the PG page with no way back when the user abandons the
/// flow (a blank/stranded modal). Running it in a throwaway web view means:
/// - cancelling returns the user to the checkout page completely intact, and
/// - the `nurio://payment-complete` return is handled here instead of relying on
///   the OS deep-link round trip.
@MainActor
final class PaymentFlowViewController: UIViewController {
    private let initialURL: URL
    private let onComplete: (URL) -> Void
    private let onCancel: () -> Void
    private var didFinish = false

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        // Share cookies / session with the Turbo web views so the gateway return
        // and any nurio.kr calls stay authenticated.
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    init(url: URL, onComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.initialURL = url
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = NSLocalizedString("결제", comment: "Payment flow screen title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        webView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        webView.load(URLRequest(url: initialURL))
    }

    @objc private func cancelTapped() {
        finish(animated: true) { [onCancel] in onCancel() }
    }

    /// Completes the flow exactly once, dismissing the modal first so the main
    /// Turbo session is active before the completion handler routes onward.
    private func complete(with url: URL) {
        finish(animated: true) { [onComplete] in onComplete(url) }
    }

    private func finish(animated: Bool, then handler: @escaping () -> Void) {
        guard !didFinish else { return }
        didFinish = true
        dismiss(animated: animated, completion: handler)
    }

    private func openExternally(_ url: URL) {
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                paymentLogger.error("PaymentFlow failed to open external app url=\(url.scheme ?? "?", privacy: .public)")
            }
        }
    }
}

extension PaymentFlowViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased()

        // The gateway finished and is returning control to the app.
        if scheme == AppEnvironment.callbackScheme {
            decisionHandler(.cancel)
            complete(with: url)
            return
        }

        // Ordinary web navigation continues inside this web view.
        if scheme == "http" || scheme == "https" || scheme == "about" || scheme == "blob" || scheme == "data" {
            decisionHandler(.allow)
            return
        }

        // Anything else is a card / bank / wallet app launch
        // (ispmobile, kakaotalk, supertoss, payco, intent, itms-apps, tel, ...).
        decisionHandler(.cancel)
        openExternally(url)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
    }
}

extension PaymentFlowViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Korean PG pages open auth / 3-D Secure popups via window.open with no
        // target frame. Load them in the same web view instead of dropping them.
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if url.scheme?.lowercased() == AppEnvironment.callbackScheme {
                complete(with: url)
            } else {
                webView.load(navigationAction.request)
            }
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("확인", comment: "OK"), style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("취소", comment: "Cancel"), style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("확인", comment: "OK"), style: .default) { _ in
            completionHandler(true)
        })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: NSLocalizedString("취소", comment: "Cancel"), style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("확인", comment: "OK"), style: .default) { [weak alert] _ in
            completionHandler(alert?.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}
