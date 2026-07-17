import XCTest
@testable import NurioStudy

final class NurioStudyTests: XCTestCase {
    func testTokenAuthURLFromNativeCallback() {
        let callbackURL = URL(string: "nuriostudy://auth-callback?token=test-token&state=test-state")!
        let tokenAuthURL = NativeAuthCallback.tokenAuthURL(
            from: callbackURL,
            baseURL: URL(string: "https://study.nurio.kr")!
        )

        XCTAssertEqual(
            tokenAuthURL?.absoluteString,
            "https://study.nurio.kr/auth/native/token_auth?token=test-token&state=test-state"
        )
    }

    func testInvalidNativeCallbackReturnsNil() {
        let callbackURL = URL(string: "nuriostudy://auth-callback?token=test-token")!
        XCTAssertNil(
            NativeAuthCallback.tokenAuthURL(
                from: callbackURL,
                baseURL: URL(string: "https://study.nurio.kr")!
            )
        )
    }

    func testScopePolicyBlocksAdminAndTutorPaths() {
        XCTAssertTrue(StudyScopePolicy.isBlocked(URL(string: "https://study.nurio.kr/admin/events")!))
        XCTAssertTrue(StudyScopePolicy.isBlocked(URL(string: "https://study.nurio.kr/tutoring/sessions")!))
        XCTAssertTrue(StudyScopePolicy.isBlocked(URL(string: "https://tutors.nurio.kr/events")!))
        XCTAssertFalse(StudyScopePolicy.isBlocked(URL(string: "https://study.nurio.kr/events/42")!))
    }

    func testSocialAuthRouteResolvesAllowlistedStudyProviderPaths() {
        let baseURL = URL(string: "https://study.nurio.kr")!
        let cases: [(startPath: String, provider: SocialAuthProvider, expectedURL: URL)] = [
            ("/auth/kakao", .kakao, URL(string: "https://study.nurio.kr/auth/kakao")!),
            (
                "/auth/google_oauth2?platform=native",
                .google,
                URL(string: "https://study.nurio.kr/auth/google_oauth2?platform=native")!
            ),
            (
                "https://STUDY.NURIO.KR/auth/naver?platform=native",
                .naver,
                URL(string: "https://STUDY.NURIO.KR/auth/naver?platform=native")!
            ),
        ]

        for testCase in cases {
            XCTAssertEqual(
                SocialAuthRoute.resolve(startPath: testCase.startPath, baseURL: baseURL),
                SocialAuthRoute(provider: testCase.provider, url: testCase.expectedURL)
            )
        }
    }

    func testSocialAuthRouteRejectsForeignHostAndUnknownPath() {
        let baseURL = URL(string: "https://study.nurio.kr")!

        XCTAssertNil(
            SocialAuthRoute.resolve(
                startPath: "https://evil.example/auth/kakao",
                baseURL: baseURL
            )
        )
        XCTAssertNil(SocialAuthRoute.resolve(startPath: "/admin/events", baseURL: baseURL))
    }

    @MainActor
    func testSocialAuthCoordinatorRoutesKakaoOnlyToNativeStarter() {
        let kakaoStarter = KakaoSignInStarterSpy()
        let oauthStarter = OAuthSessionStarterSpy()
        let coordinator = SocialAuthCoordinator(
            kakaoStarter: kakaoStarter,
            oauthStarter: oauthStarter
        )
        let route = SocialAuthRoute(
            provider: .kakao,
            url: URL(string: "https://study.nurio.kr/auth/kakao")!
        )

        coordinator.start(route: route) { _ in }

        XCTAssertEqual(kakaoStarter.startInvocationCount, 1)
        XCTAssertEqual(oauthStarter.startedURLs, [])
    }

    @MainActor
    func testSocialAuthCoordinatorRoutesGoogleAndNaverOnlyToOAuthInOrder() {
        let kakaoStarter = KakaoSignInStarterSpy()
        let oauthStarter = OAuthSessionStarterSpy()
        let coordinator = SocialAuthCoordinator(
            kakaoStarter: kakaoStarter,
            oauthStarter: oauthStarter
        )
        let googleURL = URL(
            string: "https://study.nurio.kr/auth/google_oauth2?platform=native"
        )!
        let naverURL = URL(
            string: "https://study.nurio.kr/auth/naver?return_to=%2Fevents"
        )!

        coordinator.start(route: SocialAuthRoute(provider: .google, url: googleURL)) { _ in }
        coordinator.start(route: SocialAuthRoute(provider: .naver, url: naverURL)) { _ in }

        XCTAssertEqual(kakaoStarter.startInvocationCount, 0)
        XCTAssertEqual(oauthStarter.startedURLs, [googleURL, naverURL])
    }

    func testNativeAuthHandoffCallbackURLUsesStudySchemeAndDecodedValues() throws {
        let data = #"{"token":"signed token","state":"one/time"}"#.data(using: .utf8)!

        let callbackURL = try NativeAuthHandoffClient.callbackURL(from: data)
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) }
        )

        XCTAssertEqual(callbackURL.scheme, "nuriostudy")
        XCTAssertEqual(callbackURL.host, "auth-callback")
        XCTAssertEqual(queryItems["token"], "signed token")
        XCTAssertEqual(queryItems["state"], "one/time")
    }

    func testNativeAuthHandoffRedirectDelegateRejectsRedirect() {
        let delegate = NativeAuthRedirectRejectingDelegate()
        let session = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        let originalURL = URL(string: "https://study.nurio.kr/auth/kakao/native")!
        let redirectedURL = URL(string: "https://evil.example/capture")!
        let task = session.dataTask(with: originalURL)
        let response = HTTPURLResponse(
            url: originalURL,
            statusCode: 307,
            httpVersion: nil,
            headerFields: ["Location": redirectedURL.absoluteString]
        )!
        let recorder = RedirectCompletionRecorder()

        delegate.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: redirectedURL)
        ) { request in
            recorder.record(request)
        }

        let result = recorder.result
        XCTAssertEqual(result.invocationCount, 1)
        XCTAssertNil(result.request)
    }

    func testNativeAuthHandoffClientReleasesSessionResources() {
        weak var session: URLSession?
        weak var delegate: NativeAuthRedirectRejectingDelegate?

        autoreleasepool {
            let client = NativeAuthHandoffClient()
            let resources = client.lifecycleResourcesForTesting
            session = resources.session
            delegate = resources.delegate
        }

        let deadline = Date(timeIntervalSinceNow: 1)
        while (session != nil || delegate != nil) && Date() < deadline {
            _ = RunLoop.current.run(
                mode: .default,
                before: Date(timeIntervalSinceNow: 0.01)
            )
        }

        XCTAssertNil(session)
        XCTAssertNil(delegate)
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
private final class OAuthSessionStarterSpy: OAuthSessionStarting {
    private(set) var startedURLs: [URL] = []

    func start(url: URL, completion: @escaping SocialAuthCompletion) {
        startedURLs.append(url)
    }
}

private final class RedirectCompletionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var invocationCount = 0
    private var request: URLRequest?

    func record(_ request: URLRequest?) {
        lock.lock()
        defer { lock.unlock() }
        invocationCount += 1
        self.request = request
    }

    var result: (invocationCount: Int, request: URLRequest?) {
        lock.lock()
        defer { lock.unlock() }
        return (invocationCount, request)
    }
}
