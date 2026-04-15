import XCTest
@testable import Nurio

final class NurioTests: XCTestCase {
    func testAppBundleDeclaresMediaPrivacyUsageDescriptions() {
        let appBundle = Bundle(for: AppDelegate.self)

        XCTAssertEqual(
            appBundle.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
            "Nurio uses the camera so you can take a profile photo."
        )
        XCTAssertEqual(
            appBundle.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String,
            "Nurio uses your photo library so you can choose a profile photo."
        )
        XCTAssertEqual(
            appBundle.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String,
            "Nurio may save profile photos you take in the app when needed."
        )
    }

    func testTokenAuthURLFromNativeCallback() {
        let callbackURL = URL(string: "nurio://auth-callback?token=test-token&state=test-state")!
        let tokenAuthURL = NativeAuthCallback.tokenAuthURL(
            from: callbackURL,
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertEqual(
            tokenAuthURL?.absoluteString,
            "https://nurio.kr/auth/native/token_auth?token=test-token&state=test-state"
        )
    }

    func testInvalidNativeCallbackReturnsNil() {
        let callbackURL = URL(string: "nurio://auth-callback?token=test-token")!
        XCTAssertNil(
            NativeAuthCallback.tokenAuthURL(
                from: callbackURL,
                baseURL: URL(string: "https://nurio.kr")!
            )
        )
    }

    func testScopePolicyBlocksAdminAndTutorPaths() {
        XCTAssertTrue(CustomerScopePolicy.isBlocked(URL(string: "https://nurio.kr/admin/events")!))
        XCTAssertTrue(CustomerScopePolicy.isBlocked(URL(string: "https://nurio.kr/tutoring/sessions")!))
        XCTAssertTrue(CustomerScopePolicy.isBlocked(URL(string: "https://tutors.nurio.kr/events")!))
        XCTAssertFalse(CustomerScopePolicy.isBlocked(URL(string: "https://nurio.kr/events/42")!))
    }
}
