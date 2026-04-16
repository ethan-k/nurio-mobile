import Foundation
import HotwireNative
import OSLog

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "auth"
)

@MainActor
final class OAuthRouteDecisionHandler: RouteDecisionHandler {
    let name = "oauth"

    func matches(location: URL, configuration: Navigator.Configuration) -> Bool {
        guard
            let scheme = location.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return false
        }

        let appHost = configuration.startLocation.host?.lowercased()
        return location.host?.lowercased() == appHost && AppEnvironment.oauthPaths.contains(location.path)
    }

    func handle(location: URL, configuration: Navigator.Configuration, navigator: Navigator) -> Router.Decision {
        authLogger.info("OAuthRouteDecisionHandler intercepting path=\(location.path, privacy: .public)")

        if location.path == "/auth/apple" {
            NativeAppleSignInCoordinator.shared.presentationAnchorProvider = { [weak navigator] in
                navigator?.activeNavigationController.view.window
            }

            NativeAppleSignInCoordinator.shared.start { callbackURL in
                guard let callbackURL else {
                    authLogger.error("OAuthRouteDecisionHandler native Apple flow returned no callback url")
                    return
                }
                authLogger.info("OAuthRouteDecisionHandler received native Apple callback url=\(callbackURL.absoluteString, privacy: .public)")
                AppRouteCoordinator.shared.handleIncoming(callbackURL)
            }

            return .cancel
        }

        OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak navigator] in
            navigator?.activeNavigationController.view.window
        }

        OAuthSessionCoordinator.shared.start(url: location) { callbackURL in
            authLogger.info("OAuthRouteDecisionHandler received web auth callback url=\(callbackURL.absoluteString, privacy: .public)")
            AppRouteCoordinator.shared.handleIncoming(callbackURL)
        }

        return .cancel
    }
}
