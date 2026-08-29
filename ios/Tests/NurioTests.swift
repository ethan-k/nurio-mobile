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

    func testSignInURLUsesExistingAuthLoginRoute() {
        XCTAssertEqual(
            AppEnvironment.signInURL.absoluteString,
            "https://nurio.kr/auth/login"
        )
    }

    func testColdStartURLUsesServerAuthenticationGate() {
        let baseURL = URL(string: "https://nurio.kr")!

        XCTAssertEqual(
            AppEnvironment.coldStartURL(for: baseURL).absoluteString,
            "https://nurio.kr"
        )
    }

    func testBlockedRecognizedWebURLFallsBackToEvents() {
        let baseURL = URL(string: "https://nurio.kr")!

        XCTAssertEqual(
            AppRouteCoordinator.destinationURL(
                for: URL(string: "https://nurio.kr/admin/events")!,
                baseURL: baseURL
            ).absoluteString,
            "https://nurio.kr/events"
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

    func testPaymentCompleteURLFromNativeCallbackPreservesPortOneParams() {
        let callbackURL = URL(string: "nurio://payment-complete?paymentId=payment-123&tx_id=tx-456&redirect_uri=%2Fevents%2F42")!
        let completeURL = NativePaymentCallback.completeURL(
            from: callbackURL,
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertEqual(
            completeURL?.absoluteString,
            "https://nurio.kr/payments/portone/complete?paymentId=payment-123&tx_id=tx-456&redirect_uri=/events/42"
        )
    }

    func testMalformedPaymentCallbackFallsBackToTickets() {
        let callbackURL = URL(string: "nurio://payment-complete?tx_id=tx-456")!

        XCTAssertEqual(
            NativePaymentCallback.completeURL(
                from: callbackURL,
                baseURL: URL(string: "https://nurio.kr")!
            )?.absoluteString,
            "https://nurio.kr/settings/tickets"
        )
    }

    func testPaymentCallbackUsesNonemptySnakeCaseIDWhenCamelCaseIDIsBlank() {
        let callbackURL = URL(string: "nurio://payment-complete?paymentId=&payment_id=payment-123")!
        let completeURL = NativePaymentCallback.completeURL(
            from: callbackURL,
            baseURL: URL(string: "https://nurio.kr")!
        )
        let paymentIDs = URLComponents(
            url: completeURL!,
            resolvingAgainstBaseURL: false
        )?.queryItems?.filter { $0.name == "paymentId" }.compactMap(\.value)

        XCTAssertEqual(paymentIDs, ["payment-123"])
    }

    func testPaymentCrashContextHashesReferenceAndClearsState() {
        let reporter = RecordingPaymentCrashReporter()
        let context = PaymentCrashContext(reporter: reporter, appSurface: "nurio")

        context.track(
            stage: "payment_requested",
            orderKind: "ticket",
            paymentReference: "payment-123",
            handoff: "webview",
            failureKind: "none",
            reportNonfatal: false
        )

        XCTAssertTrue(context.isActive)
        XCTAssertEqual(reporter.values["payment_reference"] as? String, "0220adf67b8fcdc0")
        XCTAssertNotEqual(reporter.values["payment_reference"] as? String, "payment-123")

        context.track(
            stage: "flow_finished",
            orderKind: nil,
            paymentReference: nil,
            handoff: nil,
            failureKind: nil,
            reportNonfatal: false
        )

        XCTAssertFalse(context.isActive)
        XCTAssertEqual(reporter.values["payment_reference"] as? String, "none")
        XCTAssertEqual(reporter.values["payment_provider"] as? String, "none")
    }

    func testPaymentCrashReporterFailureCannotEscapeTelemetry() {
        let context = PaymentCrashContext(
            reporter: ThrowingPaymentCrashReporter(),
            appSurface: "nurio"
        )

        context.reset()
        context.track(
            stage: "payment_requested",
            orderKind: "ticket",
            paymentReference: "payment-123",
            handoff: "webview",
            failureKind: "sdk_request",
            reportNonfatal: true
        )

        XCTAssertTrue(context.isActive)
    }

    func testScopePolicyBlocksAdminAndTutorPaths() {
        XCTAssertTrue(CustomerScopePolicy.isBlocked(URL(string: "https://nurio.kr/admin/events")!))
        XCTAssertTrue(CustomerScopePolicy.isBlocked(URL(string: "https://nurio.kr/tutoring/sessions")!))
        XCTAssertTrue(CustomerScopePolicy.isBlocked(URL(string: "https://tutors.nurio.kr/events")!))
        XCTAssertFalse(CustomerScopePolicy.isBlocked(URL(string: "https://nurio.kr/events/42")!))
    }

    func testNativeAppOpenURLRoutesToRequestedCustomerPage() {
        let openURL = URL(string: "nurio://open?url=https%3A%2F%2Fnurio.kr%2Fevents%2F42%3Fref%3Dhome")!
        let webURL = NativeAppOpenURL.webURL(
            from: openURL,
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertEqual(webURL?.absoluteString, "https://nurio.kr/events/42?ref=home")
    }

    func testNativeAppOpenURLNormalizesWwwHost() {
        let openURL = URL(string: "nurio://open?url=https%3A%2F%2Fwww.nurio.kr%2Fevents%2F42")!
        let webURL = NativeAppOpenURL.webURL(
            from: openURL,
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertEqual(webURL?.absoluteString, "https://nurio.kr/events/42")
    }

    func testNativeAppOpenURLRejectsBlockedCustomerPaths() {
        let openURL = URL(string: "nurio://open?url=https%3A%2F%2Fnurio.kr%2Fadmin%2Fevents")!
        let webURL = NativeAppOpenURL.webURL(
            from: openURL,
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertNil(webURL)
    }

    func testNativeAppOpenURLFallsBackToEventsWhenNoURLIsProvided() {
        let openURL = URL(string: "nurio://open")!
        let webURL = NativeAppOpenURL.webURL(
            from: openURL,
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertEqual(webURL?.absoluteString, "https://nurio.kr/events")
    }

    func testPushNotificationPathRoutesToDedicatedFeedbackPage() {
        let destination = PushNotificationRoute.destinationURL(
            from: [
                "path": "/events/42/feedback/new?t=signed-token&src=push",
                "url": ""
            ],
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertEqual(
            destination?.absoluteString,
            "https://nurio.kr/events/42/feedback/new?t=signed-token&src=push"
        )
    }

    func testPushNotificationRouteRejectsExternalDestinations() {
        let destination = PushNotificationRoute.destinationURL(
            from: [ "url": "https://example.com/phishing" ],
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertNil(destination)
    }
}

private final class RecordingPaymentCrashReporter: PaymentCrashReporting {
    var values: [String: Any] = [:]
    var logs: [String] = []
    var errors: [Error] = []

    func setCustomValue(_ value: Any, forKey key: String) throws {
        values[key] = value
    }

    func log(_ message: String) throws {
        logs.append(message)
    }

    func record(error: Error) throws {
        errors.append(error)
    }
}

private final class ThrowingPaymentCrashReporter: PaymentCrashReporting {
    private enum ReportingError: Error {
        case unavailable
    }

    func setCustomValue(_ value: Any, forKey key: String) throws {
        throw ReportingError.unavailable
    }

    func log(_ message: String) throws {
        throw ReportingError.unavailable
    }

    func record(error: Error) throws {
        throw ReportingError.unavailable
    }
}
