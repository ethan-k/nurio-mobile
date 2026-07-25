import Foundation
import HotwireNative
import UIKit

@MainActor
final class SignInWithOAuthComponent: BridgeComponent {
    override class var name: String { "sign-in-with-oauth" }

    override func onReceive(message: Message) {
        guard message.event == "click" else { return }
        guard let data: ClickData = message.data() else { return }
        guard let url = absoluteURL(from: data.startPath) else { return }

        OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak self] in
            (self?.delegate?.destination as? UIViewController)?.view.window
        }

        OAuthSessionCoordinator.shared.start(url: url) { callbackURL in
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
