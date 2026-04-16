import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
final class NativeAppleSignInCoordinator: NSObject {
    static let shared = NativeAppleSignInCoordinator()

    var presentationAnchorProvider: (() -> UIWindow?)?

    private var completion: ((URL?) -> Void)?
    private var rawNonce: String?

    private override init() {
        super.init()
    }

    func start(completion: @escaping (URL?) -> Void) {
        self.completion = completion

        let nonce = Self.randomNonceString()
        rawNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func finish(with url: URL?) {
        let completion = self.completion
        self.completion = nil
        rawNonce = nil
        completion?(url)
    }

    private func postToBackend(
        idToken: String,
        givenName: String?,
        familyName: String?,
        email: String?
    ) {
        let endpoint = AppEnvironment.baseURL.appendingPathComponent("/auth/apple/native")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = ["id_token": idToken]
        if let givenName, !givenName.isEmpty { body["given_name"] = givenName }
        if let familyName, !familyName.isEmpty { body["family_name"] = familyName }
        if let email, !email.isEmpty { body["email"] = email }

        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            finish(with: nil)
            return
        }
        request.httpBody = payload

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            Task { @MainActor in
                self.handleBackendResponse(data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handleBackendResponse(data: Data?, response: URLResponse?, error: Error?) {
        guard error == nil,
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let state = json["state"] as? String,
              let callbackURL = Self.buildCallbackURL(token: token, state: state)
        else {
            finish(with: nil)
            return
        }

        finish(with: callbackURL)
    }

    private static func buildCallbackURL(token: String, state: String) -> URL? {
        var components = URLComponents()
        components.scheme = AppEnvironment.callbackScheme
        components.host = "auth-callback"
        components.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url
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
            finish(with: nil)
            return
        }

        let givenName = credential.fullName?.givenName
        let familyName = credential.fullName?.familyName
        let email = credential.email

        postToBackend(
            idToken: identityToken,
            givenName: givenName,
            familyName: familyName,
            email: email
        )
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(with: nil)
    }
}

extension NativeAppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let anchor = presentationAnchorProvider?() {
            return anchor
        }
        if let keyWindow = UIApplication.shared.activeKeyWindow {
            return keyWindow
        }
        return ASPresentationAnchor()
    }
}
