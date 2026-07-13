import HotwireNative
import KakaoSDKAuth
import UIKit

final class SceneController: UIResponder {
    var window: UIWindow?

    private lazy var navigator = Navigator(
        configuration: .init(
            name: "Nurio",
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
        navigator.start()

        if let url {
            DispatchQueue.main.async {
                AppRouteCoordinator.shared.handleIncoming(url)
            }
        }
    }

    private func hideNavigationBarOnMainStack() {
        guard let rootNav = navigator.rootViewController as? UINavigationController else { return }
        rootNav.setNavigationBarHidden(true, animated: false)
        rootNav.delegate = self
    }

    private static func url(from userActivity: NSUserActivity) -> URL? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return nil }

        return userActivity.webpageURL
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

        if let coldLaunchURL = connectionOptions.urlContexts.first?.url,
           AuthApi.isKakaoTalkLoginUrl(coldLaunchURL) {
            _ = AuthController.handleOpenUrl(url: coldLaunchURL)
            startIfNeeded(with: nil)
        } else {
            let launchURL = connectionOptions.urlContexts.first?.url ??
                connectionOptions.userActivities.compactMap(Self.url(from:)).first
            startIfNeeded(with: launchURL)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
            return
        }
        startIfNeeded(with: url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = Self.url(from: userActivity) else { return }
        startIfNeeded(with: url)
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
    }
}
