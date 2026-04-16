import Foundation
import HotwireNative

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
        if location.path == "/auth/apple" {
            NativeAppleSignInCoordinator.shared.presentationAnchorProvider = { [weak navigator] in
                navigator?.activeNavigationController.view.window
            }

            NativeAppleSignInCoordinator.shared.start { callbackURL in
                guard let callbackURL else { return }
                AppRouteCoordinator.shared.handleIncoming(callbackURL)
            }

            return .cancel
        }

        OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak navigator] in
            navigator?.activeNavigationController.view.window
        }

        OAuthSessionCoordinator.shared.start(url: location) { callbackURL in
            AppRouteCoordinator.shared.handleIncoming(callbackURL)
        }

        return .cancel
    }
}
