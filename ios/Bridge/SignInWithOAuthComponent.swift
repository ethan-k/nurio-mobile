import Foundation
import HotwireNative
import OSLog
import UIKit

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "auth"
)

@MainActor
final class SignInWithOAuthComponent: BridgeComponent {
    override class var name: String { "sign-in-with-oauth" }

    override func onReceive(message: Message) {
        guard message.event == "click" else { return }
        guard let data: ClickData = message.data() else { return }
        guard let url = absoluteURL(from: data.startPath) else {
            authLogger.error("SignInWithOAuthComponent could not resolve startPath=\(data.startPath, privacy: .public)")
            return
        }

        authLogger.info("SignInWithOAuthComponent received url=\(url.absoluteString, privacy: .public)")

        if url.path == "/auth/apple" {
            NativeAppleSignInCoordinator.shared.presentationAnchorProvider = { [weak self] in
                (self?.delegate?.destination as? UIViewController)?.view.window
            }

            NativeAppleSignInCoordinator.shared.start { callbackURL in
                guard let callbackURL else {
                    authLogger.error("SignInWithOAuthComponent native Apple flow returned no callback url")
                    return
                }
                authLogger.info("SignInWithOAuthComponent received native Apple callback url=\(callbackURL.absoluteString, privacy: .public)")
                AppRouteCoordinator.shared.handleIncoming(callbackURL)
            }
            return
        }

        OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak self] in
            (self?.delegate?.destination as? UIViewController)?.view.window
        }

        OAuthSessionCoordinator.shared.start(url: url) { callbackURL in
            authLogger.info("SignInWithOAuthComponent received web auth callback url=\(callbackURL.absoluteString, privacy: .public)")
            AppRouteCoordinator.shared.handleIncoming(callbackURL)
        }
    }

    private func absoluteURL(from startPath: String) -> URL? {
        guard !startPath.isEmpty else { return nil }

        if let absoluteURL = URL(string: startPath), absoluteURL.scheme != nil {
            return absoluteURL
        }

        return URL(string: startPath, relativeTo: AppEnvironment.baseURL)?.absoluteURL
    }
}

private extension SignInWithOAuthComponent {
    struct ClickData: Decodable {
        let startPath: String
    }
}
