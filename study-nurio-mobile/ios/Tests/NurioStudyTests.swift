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
}
