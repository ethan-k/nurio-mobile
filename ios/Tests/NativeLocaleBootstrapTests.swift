import Foundation
import XCTest
@testable import Nurio

final class NativeLocaleBootstrapTests: XCTestCase {
    func testResolverNormalizesUppercaseRegionalAndUnderscoreIdentifiers() {
        XCTAssertEqual(NativeLocaleResolver.resolve([ "en" ]), "en")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ko" ]), "ko")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "EN-US" ]), "en")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ko_KR" ]), "ko")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "  Ko-kR  " ]), "ko")
    }

    func testResolverUsesFirstSupportedPreference() {
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ja-JP", "ko-KR" ]), "ko")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "en-US", "ko-KR" ]), "en")
        XCTAssertEqual(
            NativeLocaleResolver.resolve([ "fr-FR", "ko-KR", "en-US" ]),
            "ko"
        )
        XCTAssertEqual(
            NativeLocaleResolver.resolve([ "zh-Hant", "EN_gb", "ko-KR" ]),
            "en"
        )
    }

    func testResolverSkipsMalformedIdentifiers() {
        XCTAssertEqual(
            NativeLocaleResolver.resolve([ "-ko", "ko--KR", "en US", "EN_us" ]),
            "en"
        )
    }

    func testResolverSkipsDanglingExtensionAndPrivateUseSingletons() {
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ko-u", "en-US" ]), "en")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ko-x", "en-US" ]), "en")
    }

    func testResolverAcceptsStructuredTagsAndCompleteSingletonPayloads() {
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ko-Kore-KR" ]), "ko")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "en-Latn-US-posix" ]), "en")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ko-u-ca-buddhist" ]), "ko")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "ko-x-nurio" ]), "ko")
    }

    func testResolverDefaultsToEnglishForEmptyOrUnsupportedPreferences() {
        XCTAssertEqual(NativeLocaleResolver.resolve([]), "en")
        XCTAssertEqual(NativeLocaleResolver.resolve([ "", "fr-FR", "zh-Hant" ]), "en")
    }

    func testExistingExactLocaleCookieSuppressesWriteRegardlessOfValue() {
        for value in [ "en", "ko", "", "fr" ] {
            let store = FakeLocaleCookieStore(
                cookiesResult: .success([ makeCookie(value: value) ])
            )
            var completionCount = 0
            let bootstrap = makeBootstrap(store: store)

            bootstrap.bootstrap { completionCount += 1 }

            XCTAssertEqual(completionCount, 1, "value=\(value)")
            XCTAssertTrue(store.writtenCookies.isEmpty, "value=\(value)")
        }
    }

    func testPreferredLocaleCookieDoesNotSuppressWrite() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(name: "preferred_locale", value: "ko") ])
        )
        var completionCount = 0

        makeBootstrap(store: store).bootstrap { completionCount += 1 }

        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(store.writtenCookies.count, 1)
    }

    func testCaseVariantAndNearNameLocaleCookiesDoNotSuppressWrite() {
        for name in [ "Locale", "locale_hint" ] {
            let store = FakeLocaleCookieStore(
                cookiesResult: .success([ makeCookie(name: name, value: "ko") ])
            )

            makeBootstrap(store: store).bootstrap {}

            XCTAssertEqual(store.writtenCookies.count, 1, "name=\(name)")
        }
    }

    func testLocaleCookieForUnrelatedHostDoesNotSuppressWrite() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(domain: "unrelated.example") ])
        )

        makeBootstrap(store: store).bootstrap {}

        XCTAssertEqual(store.writtenCookies.count, 1)
    }

    func testParentDomainLocaleCookieAppliesToBaseHost() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(domain: ".nurio.kr") ])
        )

        makeBootstrap(
            baseURL: URL(string: "https://www.nurio.kr/events")!,
            store: store
        ).bootstrap {}

        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testHostOnlyLocaleCookieDoesNotApplyToSubdomain() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(domain: "nurio.kr") ])
        )

        makeBootstrap(
            baseURL: URL(string: "https://www.nurio.kr/events")!,
            store: store
        ).bootstrap {}

        XCTAssertEqual(store.writtenCookies.count, 1)
    }

    func testExistingCookiePathAppliesAtSegmentBoundary() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(path: "/app") ])
        )

        makeBootstrap(
            baseURL: URL(string: "https://nurio.kr/app/events")!,
            store: store
        ).bootstrap {}

        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testExistingCookiePathDoesNotApplyWithoutSegmentBoundary() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(path: "/app") ])
        )

        makeBootstrap(
            baseURL: URL(string: "https://nurio.kr/application")!,
            store: store
        ).bootstrap {}

        XCTAssertEqual(store.writtenCookies.count, 1)
    }

    func testSecureExistingCookieAppliesToHTTPS() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(secure: true) ])
        )

        makeBootstrap(store: store).bootstrap {}

        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testSecureExistingCookieDoesNotApplyToHTTP() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([ makeCookie(secure: true) ])
        )

        makeBootstrap(
            baseURL: URL(string: "http://nurio.kr")!,
            store: store
        ).bootstrap {}

        XCTAssertEqual(store.writtenCookies.count, 1)
    }

    func testMissingCookieWritesResolvedHTTPSCookieForOneYear() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = FakeLocaleCookieStore(cookiesResult: .success([]))
        var completionCount = 0
        var scheduledDelay: TimeInterval?

        let bootstrap = makeBootstrap(
            identifiers: { [ "fr-FR", "KO_kr" ] },
            store: store,
            clock: { now },
            timeoutScheduler: { delay, _ in scheduledDelay = delay }
        )
        bootstrap.bootstrap { completionCount += 1 }

        let cookie = store.writtenCookies.first
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(store.writtenCookies.count, 1)
        XCTAssertEqual(cookie?.name, "locale")
        XCTAssertEqual(cookie?.value, "ko")
        XCTAssertEqual(cookie?.domain, "nurio.kr")
        XCTAssertEqual(cookie?.path, "/")
        XCTAssertEqual(cookie?.expiresDate, now.addingTimeInterval(365 * 24 * 60 * 60))
        XCTAssertEqual(cookie?.isSecure, true)
        XCTAssertEqual(scheduledDelay, 1.5)
    }

    func testMissingCookieWrittenForHTTPIsNotSecure() {
        let store = FakeLocaleCookieStore(cookiesResult: .success([]))

        makeBootstrap(
            baseURL: URL(string: "http://nurio.kr")!,
            store: store
        ).bootstrap {}

        XCTAssertEqual(store.writtenCookies.count, 1)
        XCTAssertFalse(store.writtenCookies[0].isSecure)
    }

    func testMissingCookieUsesNonRootBasePath() {
        let store = FakeLocaleCookieStore(cookiesResult: .success([]))

        makeBootstrap(
            baseURL: URL(string: "https://nurio.kr/mobile/start")!,
            store: store
        ).bootstrap {}

        XCTAssertEqual(store.writtenCookies.count, 1)
        XCTAssertEqual(store.writtenCookies[0].path, "/mobile/start")
    }

    func testReadFailureCompletesOnceWithoutWrite() {
        let store = FakeLocaleCookieStore(cookiesResult: .failure(TestError.read))
        var completionCount = 0

        makeBootstrap(store: store).bootstrap { completionCount += 1 }

        XCTAssertEqual(completionCount, 1)
        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testWriteFailureCompletesOnce() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([]),
            setCookieResult: .failure(TestError.write)
        )
        var completionCount = 0

        makeBootstrap(store: store).bootstrap { completionCount += 1 }

        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(store.writtenCookies.count, 1)
    }

    func testCookieConstructionFailureCompletesOnceWithoutWrite() {
        let store = FakeLocaleCookieStore(cookiesResult: .success([]))
        var completionCount = 0

        makeBootstrap(
            baseURL: URL(string: "file:///locale")!,
            store: store
        ).bootstrap { completionCount += 1 }

        XCTAssertEqual(completionCount, 1)
        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testUnsupportedBaseURLSchemeFailsConstructionWithoutWrite() {
        let store = FakeLocaleCookieStore(cookiesResult: .success([]))
        var completionCount = 0

        makeBootstrap(
            baseURL: URL(string: "file://nurio.kr/locale")!,
            store: store
        ).bootstrap { completionCount += 1 }

        XCTAssertEqual(completionCount, 1)
        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testTimeoutCompletesOnceWithoutWrite() {
        let store = FakeLocaleCookieStore(cookiesResult: nil)
        var timeout: (() -> Void)?
        var completionCount = 0

        makeBootstrap(
            store: store,
            timeoutScheduler: { _, action in timeout = action }
        ).bootstrap { completionCount += 1 }

        XCTAssertEqual(completionCount, 0)
        timeout?()
        timeout?()

        XCTAssertEqual(completionCount, 1)
        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testDuplicateReadCallbacksWriteAndCompleteOnlyOnce() {
        let store = FakeLocaleCookieStore(cookiesResult: nil)
        var completionCount = 0

        makeBootstrap(store: store).bootstrap { completionCount += 1 }
        store.completeCookies(.success([]))
        store.completeCookies(.success([]))

        XCTAssertEqual(store.writtenCookies.count, 1)
        XCTAssertEqual(completionCount, 1)
    }

    func testDuplicateWriteCallbacksCompleteOnlyOnce() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([]),
            setCookieResult: nil
        )
        var completionCount = 0

        makeBootstrap(store: store).bootstrap { completionCount += 1 }
        store.completeSetCookie(.success(()))
        store.completeSetCookie(.success(()))

        XCTAssertEqual(store.writtenCookies.count, 1)
        XCTAssertEqual(completionCount, 1)
    }

    func testLateReadCallbackAfterTimeoutDoesNotWriteOrCompleteAgain() {
        let store = FakeLocaleCookieStore(cookiesResult: nil)
        var timeout: (() -> Void)?
        var completionCount = 0

        makeBootstrap(
            store: store,
            timeoutScheduler: { _, action in timeout = action }
        ).bootstrap { completionCount += 1 }

        timeout?()
        store.completeCookies(.success([]))

        XCTAssertEqual(completionCount, 1)
        XCTAssertTrue(store.writtenCookies.isEmpty)
    }

    func testLateWriteCallbackAfterTimeoutDoesNotCompleteAgain() {
        let store = FakeLocaleCookieStore(
            cookiesResult: .success([]),
            setCookieResult: nil
        )
        var timeout: (() -> Void)?
        var completionCount = 0

        makeBootstrap(
            store: store,
            timeoutScheduler: { _, action in timeout = action }
        ).bootstrap { completionCount += 1 }

        timeout?()
        store.completeSetCookie(.success(()))

        XCTAssertEqual(store.writtenCookies.count, 1)
        XCTAssertEqual(completionCount, 1)
    }

    private func makeBootstrap(
        baseURL: URL = URL(string: "https://nurio.kr")!,
        identifiers: @escaping () -> [String] = { [ "en-US" ] },
        store: FakeLocaleCookieStore,
        clock: @escaping () -> Date = Date.init,
        timeoutScheduler: @escaping NativeLocaleBootstrap.TimeoutScheduler = { _, _ in }
    ) -> NativeLocaleBootstrap {
        NativeLocaleBootstrap(
            baseURL: baseURL,
            languageIdentifiers: identifiers,
            store: store,
            clock: clock,
            timeoutScheduler: timeoutScheduler
        )
    }

    private func makeCookie(
        name: String = "locale",
        value: String = "en",
        domain: String = "nurio.kr",
        path: String = "/",
        secure: Bool = false
    ) -> HTTPCookie {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        if secure {
            properties[.secure] = "TRUE"
        }
        return HTTPCookie(properties: properties)!
    }
}

private final class FakeLocaleCookieStore: LocaleCookieStoring {
    private let cookiesResult: Result<[HTTPCookie], Error>?
    private let setCookieResult: Result<Void, Error>?
    private var cookiesCompletion: ((Result<[HTTPCookie], Error>) -> Void)?
    private var setCookieCompletion: ((Result<Void, Error>) -> Void)?

    private(set) var writtenCookies: [HTTPCookie] = []

    init(
        cookiesResult: Result<[HTTPCookie], Error>?,
        setCookieResult: Result<Void, Error>? = .success(())
    ) {
        self.cookiesResult = cookiesResult
        self.setCookieResult = setCookieResult
    }

    func cookies(completion: @escaping (Result<[HTTPCookie], Error>) -> Void) {
        cookiesCompletion = completion
        if let cookiesResult {
            completion(cookiesResult)
        }
    }

    func setCookie(
        _ cookie: HTTPCookie,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        writtenCookies.append(cookie)
        setCookieCompletion = completion
        if let setCookieResult {
            completion(setCookieResult)
        }
    }

    func completeCookies(_ result: Result<[HTTPCookie], Error>) {
        cookiesCompletion?(result)
    }

    func completeSetCookie(_ result: Result<Void, Error>) {
        setCookieCompletion?(result)
    }
}

private enum TestError: Error {
    case read
    case write
}
