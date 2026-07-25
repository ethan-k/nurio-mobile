import Foundation
@preconcurrency import HotwireNative

@MainActor
final class OAuthRouteDecisionHandler: @preconcurrency RouteDecisionHandler {
    let name = "oauth"

    func matches(location: URL, configuration: Navigator.Configuration) -> Bool {
        SocialAuthRoute.resolve(
            startPath: location.absoluteString,
            baseURL: configuration.startLocation
        ) != nil
    }

    func handle(location: URL, configuration: Navigator.Configuration, navigator: Navigator) -> Router.Decision {
        guard let route = SocialAuthRoute.resolve(
            startPath: location.absoluteString,
            baseURL: configuration.startLocation
        ) else {
            return .cancel
        }

        OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak navigator] in
            navigator?.activeNavigationController.view.window
        }

        OAuthSessionCoordinator.shared.start(url: route.url) { callbackURL in
            AppRouteCoordinator.shared.handleIncoming(callbackURL)
        }

        return .cancel
    }
}
