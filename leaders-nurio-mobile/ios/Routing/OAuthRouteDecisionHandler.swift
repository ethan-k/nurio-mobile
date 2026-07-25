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

        NativeGoogleSignInCoordinator.shared.presentationViewControllerProvider = { [weak navigator] in
            navigator?.activeNavigationController
        }

        SocialAuthCoordinator.shared.start(route: route) { [weak navigator] result in
            SocialAuthResultHandler.handle(
                result,
                presenting: navigator?.activeNavigationController
            )
        }

        return .cancel
    }
}
