import HotwireNative
import XCTest
@testable import NurioTutors

final class NurioTutorsTests: XCTestCase {
    func testLocalePathStripsOnlyTheFirstLocaleSegment() {
        let cases = [
            ("/ko/events", "/events"),
            ("/en", "/"),
            ("/ko/", "/"),
            ("/KO/events", "/events"),
            ("/korean-program", "/korean-program"),
            ("/kor/x", "/kor/x"),
            ("/english", "/english"),
            ("/events/ko", "/events/ko"),
            ("/ko-kr/x", "/ko-kr/x"),
            ("/Ko/x", "/Ko/x"),
            ("/ko/en/x", "/en/x"),
            ("/en?next=/ko#top", "/?next=/ko#top"),
            ("/KO/events?lang=en#top", "/events?lang=en#top"),
            ("/ko//x", "/x"),
            ("/ko///x?next=//y#//top", "/x?next=//y#//top"),
            ("//admin", "//admin"),
            ("/events", "/events"),
            ("", ""),
        ]
        for (path, expected) in cases {
            XCTAssertEqual(LocalePath.stripLocalePrefix(path), expected, path)
        }
    }

    func testLocalePrefixPreservesScopePolicy() {
        let baseURL = URL(string: "https://tutors.nurio.kr")!
        for path in ["/ko/admin", "/ko//admin", "/en/admin/x"] {
            XCTAssertTrue(TutorScopePolicy.isBlocked(URL(string: path, relativeTo: baseURL)!.absoluteURL, appHost: baseURL.host), path)
        }
        XCTAssertFalse(TutorScopePolicy.isBlocked(baseURL.appendingPathComponent("ko/events"), appHost: baseURL.host))
    }

    func testLocalePrefixesPreserveBundledPathConfigurationProperties() throws {
        let asset = try XCTUnwrap(
            Bundle(for: AppDelegate.self).url(forResource: AppEnvironment.pathConfigurationResourceName, withExtension: "json")
        )
        let configuration = PathConfiguration(sources: [.file(asset)])
        let paths = [
            "/settings",
            "/auth/login",
            "/auth/create-account",
            "/auth/verify",
            "/signup",
            "/orders/new",
            "/orders/12/payment_summary",
            "/bookings/new",
            "/bookings/12/review/new",
            "/dashboard/onboarding",
            "/dashboard/offers/new",
            "/dashboard/offers/12/edit",
            "/credits",
            "/bookings",
            "/dashboard",
            "/tutors",
        ]
        let data = try Data(contentsOf: asset)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rules = try XCTUnwrap(json["rules"] as? [[String: Any]])
        XCTAssertFalse(rules.isEmpty)
        for rule in rules {
            let patterns = try XCTUnwrap(rule["patterns"] as? [String])
            XCTAssertFalse(patterns.isEmpty)
            for pattern in patterns {
                let regex = try NSRegularExpression(pattern: pattern)
                func matches(_ path: String) -> Bool {
                    regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
                }
                let samples = paths.filter(matches)
                XCTAssertFalse(samples.isEmpty, "Missing sample for \(pattern)")
                for sample in samples {
                    XCTAssertTrue(matches("/ko\(sample)"), "\(pattern) must match /ko\(sample)")
                }
            }
        }
        for path in paths {
            let expected = configuration.properties(for: path)
            for locale in ["en", "ko", "KO"] {
                let prefixed = "/\(locale)\(path)"
                XCTAssertEqual(configuration.properties(for: prefixed), expected, prefixed)
            }
        }
    }

    @MainActor
    func testHotwireAdvertisesLocalePathSupport() {
        let prefix = Hotwire.config.applicationUserAgentPrefix
        XCTAssertTrue(prefix?.contains("NurioLocalePaths/1;") == true)
    }


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
