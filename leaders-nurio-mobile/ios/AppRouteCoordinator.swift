import Foundation
import HotwireNative

@MainActor
final class AppRouteCoordinator {
    static let shared = AppRouteCoordinator()

    weak var navigationHandler: NavigationHandler?

    private init() {}

    func handleIncoming(_ url: URL) {
        if let tokenAuthURL = NativeAuthCallback.tokenAuthURL(from: url, baseURL: AppEnvironment.baseURL) {
            navigationHandler?.route(tokenAuthURL)
            return
        }

        navigationHandler?.route(url)
    }
}
