import Foundation
import HotwireNative
import UIKit

@MainActor
final class SignInWithOAuthComponent: BridgeComponent {
    override class var name: String { "sign-in-with-oauth" }

    override func onReceive(message: Message) {
        guard message.event == "click" else { return }
        guard let data: ClickData = message.data() else { return }
        guard let route = SocialAuthRoute.resolve(
            startPath: data.startPath,
            baseURL: AppEnvironment.baseURL
        ) else { return }

        OAuthSessionCoordinator.shared.presentationAnchorProvider = { [weak self] in
            (self?.delegate?.destination as? UIViewController)?.view.window
        }

        SocialAuthCoordinator.shared.start(route: route) { [weak self] result in
            SocialAuthResultHandler.handle(
                result,
                presenting: self?.delegate?.destination as? UIViewController
            )
        }
    }
}

private extension SignInWithOAuthComponent {
    struct ClickData: Decodable {
        let startPath: String
    }
}
