import XCTest
@testable import NurioStudy

final class NurioStudyTests: XCTestCase {
    func testTokenAuthURLFromNativeCallback() {
        let callbackURL = URL(string: "nurio://auth-callback?token=test-token&state=test-state")!
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
        let callbackURL = URL(string: "nurio://auth-callback?token=test-token")!
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
}
