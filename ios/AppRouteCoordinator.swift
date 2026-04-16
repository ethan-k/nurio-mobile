import Foundation
import HotwireNative
import OSLog

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "auth"
)

@MainActor
final class AppRouteCoordinator {
    static let shared = AppRouteCoordinator()

    weak var navigationHandler: NavigationHandler?

    private init() {}

    func handleIncoming(_ url: URL) {
        authLogger.info("AppRouteCoordinator received url=\(url.absoluteString, privacy: .public)")

        if let tokenAuthURL = NativeAuthCallback.tokenAuthURL(from: url, baseURL: AppEnvironment.baseURL) {
            guard let navigationHandler else {
                authLogger.error("AppRouteCoordinator missing navigation handler for token auth url")
                return
            }

            authLogger.info("AppRouteCoordinator routing token auth url=\(tokenAuthURL.absoluteString, privacy: .public)")
            navigationHandler.route(tokenAuthURL)
            return
        }

        guard let navigationHandler else {
            authLogger.error("AppRouteCoordinator missing navigation handler for raw url")
            return
        }

        authLogger.info("AppRouteCoordinator routing raw url=\(url.absoluteString, privacy: .public)")
        navigationHandler.route(url)
    }
}
