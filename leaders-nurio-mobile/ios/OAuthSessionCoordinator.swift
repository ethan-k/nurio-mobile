import AuthenticationServices
import Foundation
import UIKit

typealias OAuthSessionCallback = @Sendable (URL?, (any Error)?) -> Void

@MainActor
struct OAuthSessionLifecycle {
    let start: () -> Bool
    let cancel: () -> Void
}

typealias OAuthSessionFactory = @MainActor (
    _ url: URL,
    _ callbackURLScheme: String,
    _ presentationContextProvider: any ASWebAuthenticationPresentationContextProviding,
    _ completion: @escaping OAuthSessionCallback
) -> OAuthSessionLifecycle

@MainActor
final class OAuthSessionCoordinator: NSObject, OAuthSessionStarting {
    static let shared = OAuthSessionCoordinator(sessionFactory: makeSystemSession)

    var presentationAnchorProvider: (() -> UIWindow?)?

    private struct ActiveRequest {
        let id: UUID
        let completion: SocialAuthCompletion
    }

    private let sessionFactory: OAuthSessionFactory
    private var session: OAuthSessionLifecycle?
    private var activeRequest: ActiveRequest?

    init(sessionFactory: @escaping OAuthSessionFactory) {
        self.sessionFactory = sessionFactory
        super.init()
    }

    func start(url: URL, completion: @escaping SocialAuthCompletion) {
        cancelActiveRequestForReplacement()
        let requestID = UUID()
        activeRequest = ActiveRequest(id: requestID, completion: completion)

        let session = sessionFactory(
            url,
            AppEnvironment.callbackScheme,
            self
        ) { [weak self] callbackURL, error in
            let result = Self.result(callbackURL: callbackURL, error: error)
            Task { @MainActor in
                self?.finish(requestID: requestID, result: result)
            }
        }

        self.session = session

        guard session.start() else {
            finish(requestID: requestID, result: .failure(.providerFailed))
            return
        }
    }

    private func cancelActiveRequestForReplacement() {
        guard let activeRequest else { return }

        self.activeRequest = nil
        let displacedSession = session
        session = nil
        displacedSession?.cancel()
        activeRequest.completion(.failure(.cancelled))
    }

    private func finish(
        requestID: UUID,
        result: Result<URL, SocialAuthError>
    ) {
        guard activeRequest?.id == requestID, let completion = activeRequest?.completion else {
            return
        }

        activeRequest = nil
        session = nil
        completion(result)
    }

    private nonisolated static func result(
        callbackURL: URL?,
        error: (any Error)?
    ) -> Result<URL, SocialAuthError> {
        if let error = error as NSError? {
            if error.domain == ASWebAuthenticationSessionErrorDomain,
               error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
                return .failure(.cancelled)
            }
            return .failure(.providerFailed)
        }

        guard let callbackURL else {
            return .failure(.providerFailed)
        }

        return .success(callbackURL)
    }

    private static func makeSystemSession(
        url: URL,
        callbackURLScheme: String,
        presentationContextProvider: any ASWebAuthenticationPresentationContextProviding,
        completion: @escaping OAuthSessionCallback
    ) -> OAuthSessionLifecycle {
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme,
            completionHandler: completion
        )
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = presentationContextProvider

        return OAuthSessionLifecycle(
            start: { session.start() },
            cancel: { session.cancel() }
        )
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
