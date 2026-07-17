import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

@MainActor
final class NativeKakaoSignInCoordinator: KakaoSignInStarting {
    static let shared = NativeKakaoSignInCoordinator()

    private let handoffClient: NativeAuthHandoffClient
    private var completion: SocialAuthCompletion?

    private init(handoffClient: NativeAuthHandoffClient = NativeAuthHandoffClient()) {
        self.handoffClient = handoffClient
    }

    func start(completion: @escaping SocialAuthCompletion) {
        guard Self.hasConfiguredAppKey else {
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

    private static var hasConfiguredAppKey: Bool {
        guard let appKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String else {
            return false
        }

        return !appKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
