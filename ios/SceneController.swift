import HotwireNative
import KakaoSDKAuth
import SwiftUI
import UIKit

final class SceneController: UIResponder {
    var window: UIWindow?

    private lazy var navigator = Navigator(
        configuration: .init(
            name: "Nurio",
            startLocation: AppEnvironment.coldStartURL
        ),
        delegate: self
    )

    private lazy var startupCoordinator = SceneStartupCoordinator(
        localeBootstrapper: NativeLocaleBootstrap(baseURL: AppEnvironment.baseURL),
        startNavigator: { [weak self] in
            guard let self else { return }

            AppRouteCoordinator.shared.navigationHandler = self.navigator

            if let anchorWindow = self.window {
                OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak anchorWindow] in
                    anchorWindow
                }
            }

            self.navigator.start()
        },
        route: { url in
            AppRouteCoordinator.shared.handleIncoming(url)
        },
        nextMainTurn: { action in
            DispatchQueue.main.async(execute: action)
        }
    )

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Visit failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        navigator.activeNavigationController.present(alert, animated: true)
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

        PushNotificationResponseRouter.shared.attach { [weak self] url in
            self?.startupCoordinator.handleIncoming(url)
        }

        if let notificationResponse = connectionOptions.notificationResponse {
            PushNotificationResponseRouter.shared.receive(notificationResponse)
        }

        hideNavigationBarOnMainStack()

        if let coldLaunchURL = connectionOptions.urlContexts.first?.url,
           AuthApi.isKakaoTalkLoginUrl(coldLaunchURL) {
            _ = AuthController.handleOpenUrl(url: coldLaunchURL)
            startupCoordinator.start()
        } else {
            let launchURL = connectionOptions.urlContexts.first?.url ??
                connectionOptions.userActivities.compactMap(Self.url(from:)).first
            if let launchURL {
                startupCoordinator.handleIncoming(launchURL)
            }
            startupCoordinator.start()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
            return
        }
        startupCoordinator.handleIncoming(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = Self.url(from: userActivity) else { return }
        startupCoordinator.handleIncoming(url)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        PushNotificationResponseRouter.shared.detach()
    }
}

extension SceneController: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        .accept
    }

    func visitableDidFailRequest(_ visitable: any Visitable, error: HotwireNativeError, retryHandler: RetryBlock?) {
        if error.statusCode == 401 {
            navigator.route(AppEnvironment.signInURL)
            return
        }

        PaymentCrashTelemetry.reportNativeRequestFailure(error, currentURL: visitable.currentVisitableURL)

        if let errorPresenter = visitable as? ErrorPresenter {
            let safeRetryHandler = CheckoutNavigation.safeRetryHandler(
                retryHandler,
                initialURL: visitable.initialVisitableURL,
                currentURL: visitable.currentVisitableURL,
                baseURL: AppEnvironment.baseURL
            )
            RequestErrorPresentation.present(error, on: errorPresenter, retryHandler: safeRetryHandler)
            return
        }

        presentError(error.localizedDescription)
    }
}

/// Hotwire 1.3.1's ErrorPresenter wraps even a nil handler in a closure. Keep
/// nil intact so its error-view factory cannot offer an unsafe gateway retry.
@MainActor
enum RequestErrorPresentation {
    static func present(_ error: HotwireNativeError, on controller: UIViewController, retryHandler: (() -> Void)?) {
        remove(from: controller)
        let handler = retryHandler.map { retry in
            { [weak controller] in
                retry()
                if let controller { remove(from: controller) }
            }
        }
        let errorView = Hotwire.config.makeCustomErrorView(error, handler)
        let host = RequestErrorHostingController(rootView: AnyView(errorView))
        controller.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: controller.view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
        ])
        host.didMove(toParent: controller)
    }

    private static func remove(from controller: UIViewController) {
        for child in controller.children where child is RequestErrorHostingController {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
}

private final class RequestErrorHostingController: UIHostingController<AnyView> {}

extension SceneController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        navigationController.setNavigationBarHidden(true, animated: animated)
    }
}
