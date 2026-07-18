import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
final class NativeAppleSignInCoordinator: NSObject, AppleSignInStarting {
    static let shared = NativeAppleSignInCoordinator()

    private let handoffClient: NativeAuthHandoffClient
    private var completion: SocialAuthCompletion?
    private var authorizationController: ASAuthorizationController?

    private init(handoffClient: NativeAuthHandoffClient = NativeAuthHandoffClient()) {
        self.handoffClient = handoffClient
        super.init()
    }

    func start(completion: @escaping SocialAuthCompletion) {
        guard self.completion == nil else {
            completion(.failure(.providerFailed))
            return
        }

        self.completion = completion

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(Self.randomNonceString())

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        authorizationController = controller
        controller.performRequests()
    }

    private func handleAuthorization(idToken: String, credential: ASAuthorizationAppleIDCredential) {
        handoffClient.exchangeApple(
            idToken: idToken,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName,
            email: credential.email
        ) { [weak self] result in
            switch result {
            case let .success(callbackURL):
                self?.finish(with: .success(callbackURL))
            case .failure:
                self?.finish(with: .failure(.handoffFailed))
            }
        }
    }

    private func finish(with result: Result<URL, SocialAuthError>) {
        let completion = self.completion
        self.completion = nil
        authorizationController = nil
        completion?(result)
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                fatalError("Unable to generate secure random nonce: \(status)")
            }

            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension NativeAppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let identityTokenData = credential.identityToken,
            let identityToken = String(data: identityTokenData, encoding: .utf8)
        else {
            finish(with: .failure(.providerFailed))
            return
        }

        handleAuthorization(idToken: identityToken, credential: credential)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            finish(with: .failure(.cancelled))
            return
        }

        finish(with: .failure(.providerFailed))
    }
}

extension NativeAppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let keyWindow = UIApplication.shared.activeKeyWindow {
            return keyWindow
        }

        return ASPresentationAnchor()
    }
}
