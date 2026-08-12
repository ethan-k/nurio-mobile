import GoogleSignIn
import HotwireNative
import KakaoSDKAuth
import UIKit

final class SceneController: UIResponder {
    var window: UIWindow?

    private lazy var navigator = Navigator(
        configuration: .init(
            name: "Nurio Study Leader",
            startLocation: AppEnvironment.startURL
        ),
        delegate: self
    )

    private var hasStarted = false

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Visit failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        navigator.activeNavigationController.present(alert, animated: true)
    }

    private func startIfNeeded(with url: URL? = nil) {
        AppRouteCoordinator.shared.navigationHandler = navigator

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
        let rootNav = navigator.rootViewController
        rootNav.setNavigationBarHidden(true, animated: false)
        rootNav.delegate = self
    }

    // The main stack hides the navigation bar and the web pages pad for the
    // status bar with env(safe-area-inset-top). Without this, UIKit adds its
    // own safe-area content inset on top of the CSS padding, doubling the gap
    // and misplacing the sticky web app bar. Modal stack keeps its native nav
    // bar, so its web view is left with the default behavior.
    private func disableMainStackSafeAreaInset() {
        navigator.session.webView.scrollView.contentInsetAdjustmentBehavior = .never
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
        disableMainStackSafeAreaInset()

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
}

extension SceneController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        navigationController.setNavigationBarHidden(true, animated: animated)
    }
}

extension SceneController: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        // Reapplied per visit because the Navigator recreates the session's
        // web view after a web content process termination.
        disableMainStackSafeAreaInset()
        return .accept
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
