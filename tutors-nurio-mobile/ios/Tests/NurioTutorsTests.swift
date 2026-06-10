import XCTest
@testable import NurioTutors

final class NurioTutorsTests: XCTestCase {
    func testTokenAuthURLFromNativeCallback() {
        let callbackURL = URL(string: "nurio://auth-callback?token=test-token&state=test-state")!
        let tokenAuthURL = NativeAuthCallback.tokenAuthURL(
            from: callbackURL,
            baseURL: URL(string: "https://tutors.nurio.kr")!
        )

        XCTAssertEqual(
            tokenAuthURL?.absoluteString,
            "https://tutors.nurio.kr/auth/native/token_auth?token=test-token&state=test-state"
        )
    }

    func testInvalidNativeCallbackReturnsNil() {
        let callbackURL = URL(string: "nurio://auth-callback?token=test-token")!
        XCTAssertNil(
            NativeAuthCallback.tokenAuthURL(
                from: callbackURL,
                baseURL: URL(string: "https://tutors.nurio.kr")!
            )
        )
    }

    func testScopePolicyBlocksAdminOnlyOnTutorHost() {
        XCTAssertTrue(TutorScopePolicy.isBlocked(URL(string: "https://tutors.nurio.kr/admin/events")!))
        XCTAssertFalse(TutorScopePolicy.isBlocked(URL(string: "https://tutors.nurio.kr/dashboard")!))
        XCTAssertFalse(TutorScopePolicy.isBlocked(URL(string: "https://tutors.nurio.kr/tutors/42")!))
        XCTAssertFalse(TutorScopePolicy.isBlocked(URL(string: "https://nurio.kr/admin/events")!))
    }
}
