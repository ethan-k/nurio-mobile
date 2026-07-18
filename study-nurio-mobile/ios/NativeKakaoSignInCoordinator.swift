import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

enum KakaoSDKConfiguration {
    static var appKey: String? {
        normalizedAppKey(
            Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String
        )
    }

    static var isConfigured: Bool {
        appKey != nil
    }

    static func isKakaoTalkLoginURL(_ url: URL) -> Bool {
        isKakaoTalkLoginURL(
            url,
            appKey: appKey,
            detector: AuthApi.isKakaoTalkLoginUrl
        )
    }

    static func isKakaoTalkLoginURL(
        _ url: URL,
        appKey: String?,
        detector: (URL) -> Bool
    ) -> Bool {
        guard normalizedAppKey(appKey) != nil else { return false }
        return detector(url)
    }

    private static func normalizedAppKey(_ appKey: String?) -> String? {
        guard let appKey else { return nil }
        let normalized = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

@MainActor
final class NativeKakaoSignInCoordinator: KakaoSignInStarting {
    static let shared = NativeKakaoSignInCoordinator()

    private let handoffClient: NativeAuthHandoffClient
    private var completion: SocialAuthCompletion?

    private convenience init() {
        self.init(handoffClient: NativeAuthHandoffClient())
    }

    private init(handoffClient: NativeAuthHandoffClient) {
        self.handoffClient = handoffClient
    }

    func start(completion: @escaping SocialAuthCompletion) {
        guard KakaoSDKConfiguration.isConfigured else {
            completion(.failure(.notConfigured))
            return
        }

        guard self.completion == nil else {
            completion(.failure(.providerFailed))
            return
        }

        self.completion = completion

        if UserApi.isKakaoTalkLoginAvailable() {
            UserApi.shared.loginWithKakaoTalk { [weak self] oauthToken, error in
                let result = Self.loginResult(oauthToken: oauthToken, error: error)
                Task { @MainActor in
                    self?.handleLoginResult(result)
                }
            }
        } else {
            UserApi.shared.loginWithKakaoAccount { [weak self] oauthToken, error in
                let result = Self.loginResult(oauthToken: oauthToken, error: error)
                Task { @MainActor in
                    self?.handleLoginResult(result)
                }
            }
        }
    }

    private nonisolated static func loginResult(
        oauthToken: OAuthToken?,
        error: Error?
    ) -> Result<String, SocialAuthError> {
        if let sdkError = error as? SdkError,
           case let .ClientFailed(reason, _) = sdkError,
           reason == .Cancelled {
            return .failure(.cancelled)
        }

        if error != nil {
            return .failure(.providerFailed)
        }

        guard let accessToken = oauthToken?.accessToken, !accessToken.isEmpty else {
            return .failure(.providerFailed)
        }

        return .success(accessToken)
    }

    private func handleLoginResult(_ result: Result<String, SocialAuthError>) {
        switch result {
        case let .success(accessToken):
            handoffClient.exchangeKakao(accessToken: accessToken) { [weak self] result in
                switch result {
                case let .success(callbackURL):
                    self?.finish(with: .success(callbackURL))
                case .failure:
                    self?.finish(with: .failure(.handoffFailed))
                }
            }
        case let .failure(error):
            finish(with: .failure(error))
        }
    }

    private func finish(with result: Result<URL, SocialAuthError>) {
        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}
