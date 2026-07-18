import Foundation
import UIKit

enum SocialAuthError: Error, Equatable, Sendable {
    case cancelled
    case notConfigured
    case providerFailed
    case handoffFailed
}

typealias SocialAuthCompletion = @MainActor @Sendable (
    Result<URL, SocialAuthError>
) -> Void

@MainActor
protocol KakaoSignInStarting: AnyObject {
    func start(completion: @escaping SocialAuthCompletion)
}

@MainActor
protocol GoogleSignInStarting: AnyObject {
    func start(completion: @escaping SocialAuthCompletion)
}

@MainActor
protocol OAuthSessionStarting: AnyObject {
    func start(url: URL, completion: @escaping SocialAuthCompletion)
}

@MainActor
final class SocialAuthCoordinator {
    static let shared = SocialAuthCoordinator(
        kakaoStarter: NativeKakaoSignInCoordinator.shared,
        googleStarter: NativeGoogleSignInCoordinator.shared,
        oauthStarter: OAuthSessionCoordinator.shared
    )

    private let kakaoStarter: any KakaoSignInStarting
    private let googleStarter: any GoogleSignInStarting
    private let oauthStarter: any OAuthSessionStarting

    init(
        kakaoStarter: any KakaoSignInStarting,
        googleStarter: any GoogleSignInStarting,
        oauthStarter: any OAuthSessionStarting
    ) {
        self.kakaoStarter = kakaoStarter
        self.googleStarter = googleStarter
        self.oauthStarter = oauthStarter
    }

    func start(route: SocialAuthRoute, completion: @escaping SocialAuthCompletion) {
        switch route.provider {
        case .kakao:
            kakaoStarter.start(completion: completion)
        case .google:
            googleStarter.start(completion: completion)
        case .naver:
            oauthStarter.start(url: route.url, completion: completion)
        }
    }
}

@MainActor
enum SocialAuthResultHandler {
    static func handle(
        _ result: Result<URL, SocialAuthError>,
        presenting viewController: UIViewController?
    ) {
        switch result {
        case let .success(callbackURL):
            AppRouteCoordinator.shared.handleIncoming(callbackURL)
        case .failure(.cancelled):
            return
        case .failure:
            let alert = UIAlertController(
                title: "Sign-in failed",
                message: "Please try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController?.present(alert, animated: true)
        }
    }
}
