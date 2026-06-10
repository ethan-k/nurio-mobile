import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class OAuthSessionCoordinator: NSObject {
    static let shared = OAuthSessionCoordinator()

    var presentationAnchorProvider: (() -> UIWindow?)?

    private var session: ASWebAuthenticationSession?
    private var completionHandler: ((URL) -> Void)?

    private override init() {
        super.init()
    }

    func start(url: URL, completion: @escaping (URL) -> Void) {
        session?.cancel()
        completionHandler = completion

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: AppEnvironment.callbackScheme
        ) { [weak self] callbackURL, _ in
            guard let self else { return }

            defer {
                self.session = nil
                self.completionHandler = nil
            }

            guard let callbackURL else { return }
            completion(callbackURL)
        }

        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = self
        session.start()
        self.session = session
    }
}

extension OAuthSessionCoordinator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = presentationAnchorProvider?() {
            return window
        }

        if let keyWindow = UIApplication.shared.activeKeyWindow {
            return keyWindow
        }

        return ASPresentationAnchor()
    }
}
