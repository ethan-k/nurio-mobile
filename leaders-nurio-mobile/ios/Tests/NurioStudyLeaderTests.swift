import XCTest
@testable import NurioStudyLeader

final class NurioStudyLeaderTests: XCTestCase {
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
