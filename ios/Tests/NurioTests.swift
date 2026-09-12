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

    // /auth/native/token_auth is visited on the main stack and redirects to /signup for a
    // brand-new account. A modal rule for that destination makes Hotwire Native present
    // /signup as a sheet on top of the main screen that already rendered the same page.
    func testPathConfigurationKeepsNativeSignInDestinationsOutOfModals() throws {
        let configurationURL = try XCTUnwrap(
            Bundle(for: AppDelegate.self).url(forResource: AppEnvironment.pathConfigurationResourceName, withExtension: "json")
        )
        let configuration = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: configurationURL)) as? [String: Any]
        )
        let rules = try XCTUnwrap(configuration["rules"] as? [[String: Any]])

        let modalPatterns = rules
            .filter { ($0["properties"] as? [String: Any])?["context"] as? String == "modal" }
            .flatMap { $0["patterns"] as? [String] ?? [] }

        for path in [ "/signup", "/login", "/auth/native/token_auth" ] {
            for pattern in modalPatterns {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(path.startIndex..., in: path)
                XCTAssertNil(
                    regex.firstMatch(in: path, range: range),
                    "\(path) must not be presented as a modal, but modal pattern \(pattern) matches it"
                )
            }
        }
    }

    func testTicketCheckoutUsesMainStackAndPreservesOtherCheckoutModals() throws {
        let configurationURL = try XCTUnwrap(
            Bundle(for: AppDelegate.self).url(forResource: AppEnvironment.pathConfigurationResourceName, withExtension: "json")
        )
        let configuration = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: configurationURL)) as? [String: Any]
        )
        let rules = try XCTUnwrap(configuration["rules"] as? [[String: Any]])
        let destinations = [
            ("/orders/new", "default"),
            ("/orders/new?event_id=34&lang=en&quantity=1&ticket_offer_id=4&step=tickets", "default"),
            ("/orders/new?event_id=34&lang=ko", "default"),
            ("/orders/42/payment_summary?lang=en", "modal"),
            ("/pass_packages/4/purchase?lang=en", "modal"),
            ("/pass_packages/4/payment_summary", "modal"),
            ("/events/34/reviews/new", "modal")
        ]

        for (path, expectedContext) in destinations {
            var properties: [String: Any] = [:]
            for rule in rules {
                let patterns = try XCTUnwrap(rule["patterns"] as? [String])
                if try patterns.contains(where: { pattern in
                    let regex = try NSRegularExpression(pattern: pattern)
                    return regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
                }) {
                    properties.merge(try XCTUnwrap(rule["properties"] as? [String: Any])) { _, new in new }
                }
            }
            XCTAssertEqual(properties["context"] as? String, expectedContext, path)
            if path.hasPrefix("/orders/new") {
                XCTAssertEqual(properties["pull_to_refresh_enabled"] as? Bool, false, path)
            }
        }
    }

    func testCheckoutRetrySelectsTicketDestinationSessionWithoutMatchingGatewayNavigation() {
        let baseURL = URL(string: "https://nurio.kr")!
        let ticketURL = URL(string: "https://nurio.kr/orders/new?event_id=34&step=tickets")!
        XCTAssertTrue(CheckoutNavigation.usesMainSession(ticketURL))
        XCTAssertTrue(CheckoutNavigation.isCheckoutEntry(ticketURL, baseURL: baseURL))

        for path in [ "/orders/42/payment_summary", "/pass_packages/4/purchase", "/pass_packages/4/payment_summary" ] {
            let url = baseURL.appendingPathComponent(path)
            XCTAssertFalse(CheckoutNavigation.usesMainSession(url))
            XCTAssertTrue(CheckoutNavigation.isCheckoutEntry(url, baseURL: baseURL))
        }
        for destination in [
            "https://mobile.inicis.com/orders/new",
            "https://ksmobile.inicis.com/payment_summary",
            "https://nurio.kr/orders/42",
            "https://nurio.kr/orders/newer",
            "https://nurio.kr/payments/portone/complete?paymentId=123"
        ] {
            XCTAssertFalse(CheckoutNavigation.isCheckoutEntry(URL(string: destination)!, baseURL: baseURL))
        }
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

    func testPushNotificationRouteRejectsBlockedCustomerPaths() {
        let destination = PushNotificationRoute.destinationURL(
            from: [ "path": "/admin/events" ],
            baseURL: URL(string: "https://nurio.kr")!
        )

        XCTAssertNil(destination)
    }

    func testPushNotificationRefreshURLPreservesExistingQueryParameters() {
        let destination = URL(string: "https://nurio.kr/events/42/chat?from=push")!

        let refreshingURL = PushNotificationRoute.refreshingURL(
            destination,
            token: "notification-123"
        )

        XCTAssertEqual(
            refreshingURL.absoluteString,
            "https://nurio.kr/events/42/chat?from=push&_native_refresh=notification-123"
        )
    }

    func testPushNotificationRefreshURLReplacesAnExistingRefreshToken() {
        let destination = URL(
            string: "https://nurio.kr/events/42/chat?_native_refresh=old&from=push"
        )!

        let refreshingURL = PushNotificationRoute.refreshingURL(
            destination,
            token: "notification-456"
        )

        XCTAssertEqual(
            refreshingURL.absoluteString,
            "https://nurio.kr/events/42/chat?from=push&_native_refresh=notification-456"
        )
    }

    func testPushNotificationRefreshURLPreservesSignedQueryEncoding() {
        let destination = URL(
            string: "https://nurio.kr/events/42/feedback/new?t=a%2Bb%2Fc%3D"
        )!

        let refreshingURL = PushNotificationRoute.refreshingURL(
            destination,
            token: "notification-789"
        )

        XCTAssertEqual(
            refreshingURL.absoluteString,
            "https://nurio.kr/events/42/feedback/new?t=a%2Bb%2Fc%3D&_native_refresh=notification-789"
        )
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
