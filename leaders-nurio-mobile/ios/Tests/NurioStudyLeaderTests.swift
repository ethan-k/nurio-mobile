import UIKit
import XCTest
@testable import NurioStudyLeader

final class NurioStudyLeaderTests: XCTestCase {
    func testSocialAuthRouteAcceptsOnlyAllowlistedLeaderProviderPaths() {
        let baseURL = URL(string: "https://studyleaders.nurio.kr")!
        let cases: [(String, SocialAuthProvider)] = [
            ("/auth/google_oauth2?platform=native", .google),
            ("/auth/kakao?platform=native", .kakao),
            ("/auth/naver?platform=native", .naver),
            ("/auth/apple?platform=native", .apple),
        ]

        for (startPath, provider) in cases {
            let route = SocialAuthRoute.resolve(startPath: startPath, baseURL: baseURL)
            XCTAssertEqual(route?.provider, provider)
            XCTAssertEqual(route?.url.host, "studyleaders.nurio.kr")
        }
    }

    func testSocialAuthRouteRejectsForeignOriginsAndUnknownPaths() {
        let baseURL = URL(string: "https://studyleaders.nurio.kr")!
        let invalidPaths = [
            "https://example.com/auth/google_oauth2",
            "https://studyleaders.nurio.kr:444/auth/kakao",
            "https://attacker@studyleaders.nurio.kr/auth/naver",
            "/admin/events",
            "/auth/google_oauth2/extra",
        ]

        invalidPaths.forEach {
            XCTAssertNil(SocialAuthRoute.resolve(startPath: $0, baseURL: baseURL))
        }
    }

    func testTokenAuthURLFromNativeCallback() {
        let callbackURL = URL(string: "nurioleaders://auth-callback?token=test-token&state=test-state")!
        let tokenAuthURL = NativeAuthCallback.tokenAuthURL(
            from: callbackURL,
            baseURL: URL(string: "https://studyleaders.nurio.kr")!
        )

        XCTAssertEqual(
            tokenAuthURL?.absoluteString,
            "https://studyleaders.nurio.kr/auth/native/token_auth?token=test-token&state=test-state"
        )
    }

    func testInvalidNativeCallbackReturnsNil() {
        let callbackURL = URL(string: "nurioleaders://auth-callback?token=test-token")!
        XCTAssertNil(
            NativeAuthCallback.tokenAuthURL(
                from: callbackURL,
                baseURL: URL(string: "https://studyleaders.nurio.kr")!
            )
        )
    }

    func testDuplicateNativeCallbackCredentialsReturnNil() {
        let callbackURL = URL(
            string: "nurioleaders://auth-callback?token=one&token=two&state=test-state"
        )!
        XCTAssertNil(
            NativeAuthCallback.tokenAuthURL(
                from: callbackURL,
                baseURL: URL(string: "https://studyleaders.nurio.kr")!
            )
        )
    }

    func testScopePolicyKeepsOnlyLeaderPortalRoutesInApp() {
        XCTAssertTrue(LeaderScopePolicy.isBlocked(URL(string: "https://studyleaders.nurio.kr/admin/events")!))
        XCTAssertFalse(LeaderScopePolicy.isBlocked(URL(string: "https://studyleaders.nurio.kr/schedule")!))
        XCTAssertFalse(LeaderScopePolicy.isBlocked(URL(string: "https://studyleaders.nurio.kr/pair-practice-sessions")!))
        XCTAssertTrue(LeaderScopePolicy.isBlocked(URL(string: "https://study.nurio.kr/study-groups")!))
        XCTAssertTrue(LeaderScopePolicy.isBlocked(URL(string: "https://nurio.kr/events")!))
    }

    func testNativeAuthHandoffUsesLeaderSchemeAndGoogleEndpoint() throws {
        let data = #"{"token":"signed token","state":"one/time"}"#.data(using: .utf8)!
        let callbackURL = try NativeAuthHandoffClient.callbackURL(from: data)
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) }
        )

        XCTAssertEqual(callbackURL.scheme, "nurioleaders")
        XCTAssertEqual(callbackURL.host, "auth-callback")
        XCTAssertEqual(queryItems["token"], "signed token")
        XCTAssertEqual(queryItems["state"], "one/time")

        let request = NativeAuthHandoffClient.googleRequest(
            baseURL: URL(string: "https://studyleaders.nurio.kr")!,
            idToken: "google-id-token"
        )
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(
            request.url,
            URL(string: "https://studyleaders.nurio.kr/auth/google/native")!
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(json, ["id_token": "google-id-token"])
    }

    @MainActor
    func testSocialAuthCoordinatorUsesNativeGoogleAndKakaoButSystemNaver() {
        let kakaoStarter = KakaoSignInStarterSpy()
        let googleStarter = GoogleSignInStarterSpy()
        let oauthStarter = OAuthSessionStarterSpy()
        let coordinator = SocialAuthCoordinator(
            kakaoStarter: kakaoStarter,
            googleStarter: googleStarter,
            oauthStarter: oauthStarter
        )
        let baseURL = URL(string: "https://studyleaders.nurio.kr")!
        let kakaoURL = baseURL.appendingPathComponent("auth/kakao")
        let googleURL = baseURL.appendingPathComponent("auth/google_oauth2")
        let naverURL = baseURL.appendingPathComponent("auth/naver")

        coordinator.start(route: SocialAuthRoute(provider: .kakao, url: kakaoURL)) { _ in }
        coordinator.start(route: SocialAuthRoute(provider: .google, url: googleURL)) { _ in }
        coordinator.start(route: SocialAuthRoute(provider: .naver, url: naverURL)) { _ in }

        XCTAssertEqual(kakaoStarter.startInvocationCount, 1)
        XCTAssertEqual(googleStarter.startInvocationCount, 1)
        XCTAssertEqual(oauthStarter.startedURLs, [naverURL])
    }

    @MainActor
    func testNativeGoogleExchangesSDKIDTokenForLeaderHandoff() {
        let callbackURL = URL(
            string: "nurioleaders://auth-callback?token=signed&state=one-time"
        )!
        let idTokenProvider = GoogleIDTokenProviderSpy(idToken: "google-id-token")
        let handoffClient = NativeAuthHandoffExchangerSpy(callbackURL: callbackURL)
        let configuration = GoogleSDKConfiguration(
            clientID: "leader-ios.apps.googleusercontent.com",
            serverClientID: "web.apps.googleusercontent.com"
        )
        let coordinator = NativeGoogleSignInCoordinator(
            idTokenProvider: idTokenProvider,
            handoffClient: handoffClient,
            configurationProvider: { configuration }
        )
        coordinator.presentationViewControllerProvider = { UIViewController() }
        var receivedURL: URL?

        coordinator.start { result in
            if case let .success(url) = result {
                receivedURL = url
            }
        }

        XCTAssertEqual(idTokenProvider.receivedConfigurations, [configuration])
        XCTAssertEqual(handoffClient.googleIDTokens, ["google-id-token"])
        XCTAssertEqual(receivedURL, callbackURL)
    }

    func testKakaoCallbackDetectionFailsClosedWithoutNativeKey() {
        var detectorCalled = false
        let isCallback = KakaoSDKConfiguration.isKakaoTalkLoginURL(
            URL(string: "kakaoexample://oauth")!,
            appKey: " ",
            detector: { _ in
                detectorCalled = true
                return true
            }
        )

        XCTAssertFalse(isCallback)
        XCTAssertFalse(detectorCalled)
    }
}

@MainActor
private final class KakaoSignInStarterSpy: KakaoSignInStarting {
    private(set) var startInvocationCount = 0

    func start(completion: @escaping SocialAuthCompletion) {
        startInvocationCount += 1
    }
}

@MainActor
private final class GoogleSignInStarterSpy: GoogleSignInStarting {
    private(set) var startInvocationCount = 0

    func start(completion: @escaping SocialAuthCompletion) {
        startInvocationCount += 1
    }
}

@MainActor
private final class OAuthSessionStarterSpy: OAuthSessionStarting {
    private(set) var startedURLs: [URL] = []

    func start(url: URL, completion: @escaping SocialAuthCompletion) {
        startedURLs.append(url)
    }
}

@MainActor
private final class GoogleIDTokenProviderSpy: GoogleIDTokenProviding {
    private let idToken: String
    private(set) var receivedConfigurations: [GoogleSDKConfiguration] = []

    init(idToken: String) {
        self.idToken = idToken
    }

    func signIn(
        presenting viewController: UIViewController,
        configuration: GoogleSDKConfiguration,
        completion: @escaping GoogleIDTokenCompletion
    ) {
        receivedConfigurations.append(configuration)
        completion(.success(idToken))
    }
}

@MainActor
private final class NativeAuthHandoffExchangerSpy: NativeAuthHandoffExchanging {
    private let callbackURL: URL
    private(set) var googleIDTokens: [String] = []

    init(callbackURL: URL) {
        self.callbackURL = callbackURL
    }

    func exchangeKakao(
        accessToken: String,
        completion: @escaping NativeAuthHandoffCompletion
    ) {
        completion(.failure(.invalidResponse))
    }

    func exchangeGoogle(
        idToken: String,
        completion: @escaping NativeAuthHandoffCompletion
    ) {
        googleIDTokens.append(idToken)
        completion(.success(callbackURL))
    }
}
