import Foundation
import HotwireNative

@MainActor
final class AppRouteCoordinator {
    static let shared = AppRouteCoordinator()

    private weak var navigationHandler: NavigationHandler?
    private var pendingNotificationURL: URL?

    init() {}

    /// The URL of the web view the learner is looking at, if the navigator is up.
    var visibleURL: URL? {
        (navigationHandler as? Navigator)?.activeWebView.url
    }

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

    /// Replaces the current screen with `url` so Back does not return to a
    /// page the learner has finished (e.g. the class review call page).
    func replaceCurrentVisit(with url: URL) {
        let proposal = VisitProposal(
            url: url,
            options: VisitOptions(action: .replace),
            properties: Hotwire.config.pathConfiguration.properties(for: url)
        )

        if let navigationHandler {
            navigationHandler.route(proposal)
        } else {
            pendingNotificationURL = url
        }
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
