import HotwireNative
import GoogleSignIn
import KakaoSDKAuth
import UIKit
import WebKit

enum AiPracticeNativePolicy {
    private static let sessionPathPattern = #"^/practice/[0-9]+/?$"#

    static func isSessionURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        return components.percentEncodedPath.range(
            of: sessionPathPattern,
            options: .regularExpression
        ) != nil
    }

    static func isTrustedSessionURL(_ url: URL, baseURL: URL) -> Bool {
        isSessionURL(url) && hasTrustedHTTPSOrigin(url, baseURL: baseURL)
    }

    static func isTrustedMicrophoneOrigin(
        protocol originProtocol: String,
        host: String,
        port: Int,
        baseURL: URL
    ) -> Bool {
        guard let requestedOrigin = Origin(
            scheme: originProtocol,
            host: host,
            port: port == 0 ? nil : port
        ), let trustedOrigin = Origin(url: baseURL) else {
            return false
        }

        return requestedOrigin == trustedOrigin && requestedOrigin.scheme == "https"
    }

    static func shouldGrantMicrophoneCapture(
        type: WKMediaCaptureType,
        originProtocol: String,
        originHost: String,
        originPort: Int,
        isMainFrame: Bool,
        frameURL: URL?,
        webViewURL: URL?,
        baseURL: URL
    ) -> Bool {
        guard type == .microphone,
              isMainFrame,
              isTrustedMicrophoneOrigin(
                  protocol: originProtocol,
                  host: originHost,
                  port: originPort,
                  baseURL: baseURL
              ),
              let webViewURL,
              isTrustedSessionURL(webViewURL, baseURL: baseURL) else {
            return false
        }

        return frameURL.map { hasTrustedHTTPSOrigin($0, baseURL: baseURL) } ?? true
    }

    private static func hasTrustedHTTPSOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard let requestedOrigin = Origin(url: url),
              let trustedOrigin = Origin(url: baseURL) else {
            return false
        }

        return requestedOrigin == trustedOrigin && requestedOrigin.scheme == "https"
    }

    private struct Origin: Equatable {
        let scheme: String
        let host: String
        let port: Int?

        init?(url: URL) {
            guard url.user == nil, url.password == nil, let scheme = url.scheme, let host = url.host else {
                return nil
            }
            self.init(scheme: scheme, host: host, port: url.port)
        }

        init?(scheme: String, host: String, port: Int?) {
            let normalizedScheme = scheme.lowercased()
            let normalizedHost = host.lowercased()
            guard !normalizedScheme.isEmpty, !normalizedHost.isEmpty else { return nil }

            self.scheme = normalizedScheme
            self.host = normalizedHost
            self.port = Self.isDefaultPort(port, scheme: normalizedScheme) ? nil : port
        }

        private static func isDefaultPort(_ port: Int?, scheme: String) -> Bool {
            (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
        }
    }
}

final class StudyWKUIController: WKUIController {
    private let trustedBaseURL: URL

    init(delegate: WKUIControllerDelegate, trustedBaseURL: URL) {
        self.trustedBaseURL = trustedBaseURL
        super.init(delegate: delegate)
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let trustedRequest = AiPracticeNativePolicy.shouldGrantMicrophoneCapture(
            type: type,
            originProtocol: origin.`protocol`,
            originHost: origin.host,
            originPort: origin.port,
            isMainFrame: frame.isMainFrame,
            frameURL: frame.request.url,
            webViewURL: webView.url,
            baseURL: trustedBaseURL
        )
        decisionHandler(trustedRequest ? .grant : .deny)
    }
}

final class SceneController: UIResponder {
    var window: UIWindow?

    private lazy var navigator: Navigator = {
        let navigator = Navigator(
            configuration: .init(
                name: "NurioStudy",
                startLocation: AppEnvironment.startURL
            ),
            delegate: self
        )
        navigator.webkitUIDelegate = StudyWKUIController(
            delegate: navigator,
            trustedBaseURL: AppEnvironment.baseURL
        )
        return navigator
    }()

    private var hasStarted = false

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Visit failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        navigator.activeNavigationController.present(alert, animated: true)
    }

    private func startIfNeeded(with url: URL? = nil) {
        AppRouteCoordinator.shared.installNavigationHandler(navigator)

        if let anchorWindow = window {
            OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak anchorWindow] in
                anchorWindow
            }
        }

        guard !hasStarted else {
            if let url {
                AppRouteCoordinator.shared.handleIncoming(url)
            }
            return
        }

        hasStarted = true

        if let url {
            AppRouteCoordinator.shared.handleIncoming(url)
        } else {
            navigator.start()
        }
    }

    private func hideNavigationBarOnMainStack() {
        guard let rootNav = navigator.rootViewController as? UINavigationController else { return }
        rootNav.setNavigationBarHidden(true, animated: false)
        rootNav.delegate = self
    }

    private func updateIdleTimer(for url: URL?) {
        UIApplication.shared.isIdleTimerDisabled = url.map(AiPracticeNativePolicy.isSessionURL) ?? false
    }
}

extension SceneController: UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigator.rootViewController
        window.makeKeyAndVisible()
        self.window = window

        hideNavigationBarOnMainStack()

        if let launchURL = connectionOptions.urlContexts.first?.url {
            if GIDSignIn.sharedInstance.handle(launchURL) {
                startIfNeeded()
                return
            }

            if KakaoSDKConfiguration.isKakaoTalkLoginURL(launchURL) {
                _ = AuthController.handleOpenUrl(url: launchURL)
                startIfNeeded()
                return
            }
        }

        startIfNeeded(with: connectionOptions.urlContexts.first?.url)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        if KakaoSDKConfiguration.isKakaoTalkLoginURL(url) {
            _ = AuthController.handleOpenUrl(url: url)
            return
        }

        startIfNeeded(with: url)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        let visitable = navigator.activeNavigationController.topViewController as? any Visitable
        updateIdleTimer(for: visitable?.currentVisitableURL)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        updateIdleTimer(for: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        updateIdleTimer(for: nil)
    }
}

extension SceneController: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        .accept
    }

    func visitableDidFailRequest(_ visitable: any Visitable, error: any Error, retryHandler: RetryBlock?) {
        if let turboError = error as? TurboError, case let .http(statusCode) = turboError, statusCode == 401 {
            navigator.route(AppEnvironment.signInURL)
            return
        }

        if let errorPresenter = visitable as? ErrorPresenter {
            errorPresenter.presentError(error) {
                retryHandler?()
            }
            return
        }

        presentError(error.localizedDescription)
    }
}

extension SceneController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        navigationController.setNavigationBarHidden(true, animated: animated)
        let visitable = viewController as? any Visitable
        updateIdleTimer(for: visitable?.currentVisitableURL)
    }
}
