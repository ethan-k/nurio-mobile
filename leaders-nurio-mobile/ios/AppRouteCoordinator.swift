import Foundation
import HotwireNative

@MainActor
final class AppRouteCoordinator {
    static let shared = AppRouteCoordinator()

    private weak var navigationHandler: NavigationHandler?
    private var pendingNotificationURL: URL?

    init() {}

    func installNavigationHandler(_ navigationHandler: NavigationHandler) {
        self.navigationHandler = navigationHandler

        if let pendingNotificationURL {
            self.pendingNotificationURL = nil
            navigationHandler.route(pendingNotificationURL)
        }
    }

    func handleIncoming(_ url: URL) {
        if let tokenAuthURL = NativeAuthCallback.tokenAuthURL(from: url, baseURL: AppEnvironment.baseURL) {
            navigationHandler?.route(tokenAuthURL)
            return
        }

        navigationHandler?.route(url)
    }

    func handleNotification(path: String?, url: String?) {
        let destination = NotificationDestination.resolve(
            path: path,
            url: url,
            baseURL: AppEnvironment.baseURL
        )

        if let navigationHandler {
            navigationHandler.route(destination)
        } else {
            pendingNotificationURL = destination
        }
    }
}
