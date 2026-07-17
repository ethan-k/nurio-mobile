import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class OAuthSessionCoordinator: NSObject, OAuthSessionStarting {
    static let shared = OAuthSessionCoordinator()

    var presentationAnchorProvider: (() -> UIWindow?)?

    private var session: ASWebAuthenticationSession?
    private var activeSessionID: UUID?

    private override init() {
        super.init()
    }

    func start(url: URL, completion: @escaping SocialAuthCompletion) {
        session?.cancel()
        let sessionID = UUID()
        activeSessionID = sessionID

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: AppEnvironment.callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self, self.activeSessionID == sessionID else { return }
                self.session = nil
                self.activeSessionID = nil

                if let error = error as NSError? {
                    if error.domain == ASWebAuthenticationSessionErrorDomain,
                       error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
                        completion(.failure(.cancelled))
                    } else {
                        completion(.failure(.providerFailed))
                    }
                    return
                }

                guard let callbackURL else {
                    completion(.failure(.providerFailed))
                    return
                }

                completion(.success(callbackURL))
            }
        }

        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = self
        self.session = session

        guard session.start() else {
            self.session = nil
            activeSessionID = nil
            completion(.failure(.providerFailed))
            return
        }
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
