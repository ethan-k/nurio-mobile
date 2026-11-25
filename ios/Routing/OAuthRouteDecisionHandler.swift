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

    func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
        let location = proposal.url
        guard
            let scheme = location.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return false
        }

        let appHost = configuration.startLocation.host?.lowercased()
        return location.host?.lowercased() == appHost && AppEnvironment.oauthPaths.contains(LocalePath.stripLocalePrefix(location.path))
    }

    func handle(proposal: VisitProposal, configuration: Navigator.Configuration, navigator: any Navigating) -> Router.Decision {
        let location = proposal.url
        let path = LocalePath.stripLocalePrefix(location.path)
        if path == "/auth/apple" {
            NativeAppleSignInCoordinator.shared.presentationAnchorProvider = { [weak navigator] in
                navigator?.activeNavigationController.view.window
            }

            NativeAppleSignInCoordinator.shared.start { callbackURL in
                guard let callbackURL else {
                    authLogger.error("OAuthRouteDecisionHandler native Apple flow returned no callback url")
                    return
                }
                AppRouteCoordinator.shared.handleIncoming(callbackURL)
            }

            return .cancel
        }

        if path == "/auth/kakao" {
            NativeKakaoSignInCoordinator.shared.start { callbackURL in
                guard let callbackURL else {
                    authLogger.error("OAuthRouteDecisionHandler native Kakao flow returned no callback url")
                    return
                }
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
