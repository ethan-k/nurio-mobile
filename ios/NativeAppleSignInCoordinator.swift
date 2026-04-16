import AuthenticationServices
import CryptoKit
import Foundation
import OSLog
import UIKit

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "auth"
)

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
        authLogger.info("NativeAppleSignInCoordinator starting Apple authorization flow")

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func finish(with url: URL?) {
        if let url {
            authLogger.info("NativeAppleSignInCoordinator finishing with callback url=\(url.absoluteString, privacy: .public)")
        } else {
            authLogger.error("NativeAppleSignInCoordinator finishing without callback url")
        }
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
        authLogger.info(
            "NativeAppleSignInCoordinator posting to backend endpoint=\(endpoint.absoluteString, privacy: .public) given_name_present=\(givenName?.isEmpty == false) family_name_present=\(familyName?.isEmpty == false) email_present=\(email?.isEmpty == false) token_length=\(idToken.count)"
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = ["id_token": idToken]
        if let givenName, !givenName.isEmpty { body["given_name"] = givenName }
        if let familyName, !familyName.isEmpty { body["family_name"] = familyName }
        if let email, !email.isEmpty { body["email"] = email }

        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            authLogger.error("NativeAppleSignInCoordinator failed to encode backend payload")
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
        if let error {
            authLogger.error("NativeAppleSignInCoordinator backend request error=\(error.localizedDescription, privacy: .public)")
            finish(with: nil)
            return
        }

        guard let http = response as? HTTPURLResponse else {
            authLogger.error("NativeAppleSignInCoordinator missing HTTP response")
            finish(with: nil)
            return
        }

        guard (200..<300).contains(http.statusCode) else {
            let responseText = Self.responseText(from: data)
            authLogger.error(
                "NativeAppleSignInCoordinator backend rejected status=\(http.statusCode) body=\(responseText, privacy: .public)"
            )
            finish(with: nil)
            return
        }

        guard let data else {
            authLogger.error("NativeAppleSignInCoordinator backend success missing body")
            finish(with: nil)
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            authLogger.error("NativeAppleSignInCoordinator backend success invalid JSON body_bytes=\(data.count)")
            finish(with: nil)
            return
        }

        guard let token = json["token"] as? String, let state = json["state"] as? String else {
            let keys = json.keys.sorted().joined(separator: ",")
            authLogger.error("NativeAppleSignInCoordinator backend success missing token/state keys=\(keys, privacy: .public)")
            finish(with: nil)
            return
        }

        guard let callbackURL = Self.buildCallbackURL(token: token, state: state) else {
            authLogger.error(
                "NativeAppleSignInCoordinator failed to build callback url token_length=\(token.count) state_length=\(state.count)"
            )
            finish(with: nil)
            return
        }

        authLogger.info("NativeAppleSignInCoordinator backend success status=\(http.statusCode)")
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

    private static func responseText(from data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        return String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
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
            authLogger.error("NativeAppleSignInCoordinator authorization completed without usable identity token")
            finish(with: nil)
            return
        }

        let givenName = credential.fullName?.givenName
        let familyName = credential.fullName?.familyName
        let email = credential.email
        authLogger.info(
            "NativeAppleSignInCoordinator authorization succeeded token_length=\(identityToken.count) given_name_present=\(givenName?.isEmpty == false) family_name_present=\(familyName?.isEmpty == false) email_present=\(email?.isEmpty == false)"
        )

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
        let nsError = error as NSError
        authLogger.error(
            "NativeAppleSignInCoordinator authorization failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code) message=\(nsError.localizedDescription, privacy: .public)"
        )
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
