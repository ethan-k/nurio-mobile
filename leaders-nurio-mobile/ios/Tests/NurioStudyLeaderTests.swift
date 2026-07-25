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
}
