import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import OSLog

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "auth"
)

@MainActor
final class NativeKakaoSignInCoordinator {
    static let shared = NativeKakaoSignInCoordinator()

    private var completion: ((URL?) -> Void)?

    private init() {}

    func start(completion: @escaping (URL?) -> Void) {
        if self.completion != nil {
            authLogger.error("NativeKakaoSignInCoordinator ignoring start while a flow is already in progress")
            completion(nil)
            return
        }
        self.completion = completion

        let talkAvailable = UserApi.isKakaoTalkLoginAvailable()
        authLogger.info("NativeKakaoSignInCoordinator starting Kakao authorization flow talk_available=\(talkAvailable)")

        if talkAvailable {
            UserApi.shared.loginWithKakaoTalk { [weak self] oauthToken, error in
                Task { @MainActor in
                    self?.handleLoginResult(oauthToken: oauthToken, error: error)
                }
            }
        } else {
            UserApi.shared.loginWithKakaoAccount { [weak self] oauthToken, error in
                Task { @MainActor in
                    self?.handleLoginResult(oauthToken: oauthToken, error: error)
                }
            }
        }
    }

    private func handleLoginResult(oauthToken: OAuthToken?, error: Error?) {
        if let error {
            authLogger.error("NativeKakaoSignInCoordinator kakao login failed error=\(error.localizedDescription, privacy: .public)")
            finish(with: nil)
            return
        }

        guard let accessToken = oauthToken?.accessToken, !accessToken.isEmpty else {
            authLogger.error("NativeKakaoSignInCoordinator kakao login returned no access token")
            finish(with: nil)
            return
        }

        postToBackend(accessToken: accessToken)
    }

    private func finish(with url: URL?) {
        if url == nil {
            authLogger.error("NativeKakaoSignInCoordinator finishing without callback url")
        }
        let completion = self.completion
        self.completion = nil
        completion?(url)
    }

    private func postToBackend(accessToken: String) {
        let endpoint = AppEnvironment.baseURL.appendingPathComponent("/auth/kakao/native")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = ["access_token": accessToken]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            authLogger.error("NativeKakaoSignInCoordinator failed to encode backend payload")
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
            authLogger.error("NativeKakaoSignInCoordinator backend request error=\(error.localizedDescription, privacy: .public)")
            finish(with: nil)
            return
        }

        guard let http = response as? HTTPURLResponse else {
            authLogger.error("NativeKakaoSignInCoordinator missing HTTP response")
            finish(with: nil)
            return
        }

        guard (200..<300).contains(http.statusCode) else {
            let responseText = Self.responseText(from: data)
            authLogger.error(
                "NativeKakaoSignInCoordinator backend rejected status=\(http.statusCode) body=\(responseText, privacy: .public)"
            )
            finish(with: nil)
            return
        }

        guard let data else {
            authLogger.error("NativeKakaoSignInCoordinator backend success missing body")
            finish(with: nil)
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            authLogger.error("NativeKakaoSignInCoordinator backend success invalid JSON body_bytes=\(data.count)")
            finish(with: nil)
            return
        }

        guard let token = json["token"] as? String, let state = json["state"] as? String else {
            let keys = json.keys.sorted().joined(separator: ",")
            authLogger.error("NativeKakaoSignInCoordinator backend success missing token/state keys=\(keys, privacy: .public)")
            finish(with: nil)
            return
        }

        guard let callbackURL = Self.buildCallbackURL(token: token, state: state) else {
            authLogger.error(
                "NativeKakaoSignInCoordinator failed to build callback url token_length=\(token.count) state_length=\(state.count)"
            )
            finish(with: nil)
            return
        }

        authLogger.info("NativeKakaoSignInCoordinator backend success status=\(http.statusCode)")
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

    private static func responseText(from data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        return String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
    }
}
