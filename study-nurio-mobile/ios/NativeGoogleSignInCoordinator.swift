import Foundation
import GoogleSignIn
import UIKit

struct GoogleSDKConfiguration: Equatable {
    let clientID: String
    let serverClientID: String

    static var current: Self? {
        guard
            let clientID = configuredValue(for: "GIDClientID"),
            let serverClientID = configuredValue(for: "GIDServerClientID")
        else { return nil }

        return Self(clientID: clientID, serverClientID: serverClientID)
    }

    private static func configuredValue(for key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.contains("$(") ? nil : value
    }
}

typealias GoogleIDTokenCompletion = @MainActor @Sendable (
    Result<String, SocialAuthError>
) -> Void

@MainActor
protocol GoogleIDTokenProviding: AnyObject {
    func signIn(
        presenting viewController: UIViewController,
        configuration: GoogleSDKConfiguration,
        completion: @escaping GoogleIDTokenCompletion
    )
}

@MainActor
final class GoogleIDTokenProvider: GoogleIDTokenProviding {
    func signIn(
        presenting viewController: UIViewController,
        configuration: GoogleSDKConfiguration,
        completion: @escaping GoogleIDTokenCompletion
    ) {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: configuration.clientID,
            serverClientID: configuration.serverClientID
        )
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            Task { @MainActor in
                if let error {
                    completion(.failure(Self.socialAuthError(for: error)))
                    return
                }

                guard let user = result?.user else {
                    completion(.failure(.providerFailed))
                    return
                }

                do {
                    let refreshedUser = try await user.refreshTokensIfNeeded()
                    guard let idToken = refreshedUser.idToken?.tokenString, !idToken.isEmpty else {
                        completion(.failure(.providerFailed))
                        return
                    }

                    completion(.success(idToken))
                } catch {
                    completion(.failure(.providerFailed))
                }
            }
        }
    }

    private static func socialAuthError(for error: Error) -> SocialAuthError {
        let error = error as NSError
        let cancelled = error.domain == kGIDSignInErrorDomain &&
            error.code == GIDSignInError.canceled.rawValue
        return cancelled ? .cancelled : .providerFailed
    }
}

@MainActor
final class NativeGoogleSignInCoordinator: GoogleSignInStarting {
    static let shared = NativeGoogleSignInCoordinator()

    var presentationViewControllerProvider: () -> UIViewController? = {
        UIApplication.shared.activeKeyWindow?.rootViewController
    }

    private let idTokenProvider: any GoogleIDTokenProviding
    private let handoffClient: any NativeAuthHandoffExchanging
    private let configurationProvider: () -> GoogleSDKConfiguration?
    private var completion: SocialAuthCompletion?

    private convenience init() {
        self.init(
            idTokenProvider: GoogleIDTokenProvider(),
            handoffClient: NativeAuthHandoffClient(),
            configurationProvider: { GoogleSDKConfiguration.current }
        )
    }

    init(
        idTokenProvider: any GoogleIDTokenProviding,
        handoffClient: any NativeAuthHandoffExchanging,
        configurationProvider: @escaping () -> GoogleSDKConfiguration?
    ) {
        self.idTokenProvider = idTokenProvider
        self.handoffClient = handoffClient
        self.configurationProvider = configurationProvider
    }

    func start(completion: @escaping SocialAuthCompletion) {
        guard let configuration = configurationProvider(),
              let viewController = presentationViewControllerProvider() else {
            completion(.failure(.notConfigured))
            return
        }

        guard self.completion == nil else {
            completion(.failure(.providerFailed))
            return
        }

        self.completion = completion
        idTokenProvider.signIn(
            presenting: viewController,
            configuration: configuration
        ) { [weak self] result in
            self?.handleSignInResult(result)
        }
    }

    private func handleSignInResult(_ result: Result<String, SocialAuthError>) {
        switch result {
        case let .success(idToken):
            handoffClient.exchangeGoogle(idToken: idToken) { [weak self] result in
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
