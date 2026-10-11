import UIKit
import XCTest
@testable import NurioStudy

@MainActor
final class AiTutorCallTests: XCTestCase {
    private let baseURL = URL(string: "https://study.nurio.kr")!

    // MARK: - Endpoints

    func testEndpointsResolveRelativePathsAgainstTheAppOrigin() throws {
        let endpoints = try XCTUnwrap(AiTutorCallEndpoints.resolve(startData(), baseURL: baseURL))

        XCTAssertEqual(endpoints.joinURL, URL(string: "https://study.nurio.kr/practice/42/tutor/join"))
        XCTAssertEqual(endpoints.endURL, URL(string: "https://study.nurio.kr/practice/42/tutor/end"))
        XCTAssertEqual(endpoints.reviewURL, URL(string: "https://study.nurio.kr/practice/42/review"))
        XCTAssertEqual(endpoints.topic, "Ordering coffee")
        XCTAssertEqual(endpoints.csrfToken, "csrf-123")
    }

    func testEndpointsRejectPathsThatLeaveTheAppOrigin() {
        for foreign in [
            "https://evil.example/practice/42/tutor/join",
            "//evil.example/practice/42/tutor/join",
            "http://study.nurio.kr/practice/42/tutor/join",
            "https://study.nurio.kr:8443/practice/42/tutor/join",
            "",
        ] {
            let data = startData(joinUrl: foreign)
            XCTAssertNil(AiTutorCallEndpoints.resolve(data, baseURL: baseURL), foreign)
        }
    }

    // MARK: - Join polling

    func testJoinPollsWhileProvisioningUntilLiveKitCredentialsArrive() async throws {
        let transport = FakeAiTutorTransport(responses: [
            .response(202, #"{"status":"provisioning","deadline_at":"2026-10-11T14:30:00+09:00"}"#),
            .response(202, #"{"status":"provisioning","deadline_at":"2026-10-11T14:30:00+09:00"}"#),
            .response(200, #"{"status":"connecting","deadline_at":"2026-10-11T14:30:00+09:00","livekit":{"url":"wss://lk.example","room":"ait_1","participant_token":"tok"}}"#),
        ])
        let clock = FakeAiTutorClock()
        let api = makeAPI(transport: transport, clock: clock)

        let outcome = try await api.join()

        XCTAssertEqual(
            outcome,
            .ready(
                AiTutorLiveKitCredentials(url: "wss://lk.example", room: "ait_1", participantToken: "tok"),
                deadline: AiTutorCallAPI.parseDate("2026-10-11T05:30:00Z")
            )
        )
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertTrue(transport.requests.allSatisfy { $0.url == URL(string: "https://study.nurio.kr/practice/42/tutor/join") })
        XCTAssertEqual(clock.sleeps, [ 1.5, 1.5 ])
    }

    func testJoinGivesUpWhenProvisioningOutlastsThirtySeconds() async {
        let transport = FakeAiTutorTransport(repeating: .response(202, #"{"status":"provisioning"}"#))
        let clock = FakeAiTutorClock()
        let api = makeAPI(transport: transport, clock: clock)

        do {
            _ = try await api.join()
            XCTFail("expected provisioning timeout")
        } catch {
            XCTAssertEqual(error as? AiTutorCallAPIError, .provisioningTimedOut)
        }

        XCTAssertEqual(transport.requests.count, 21)
        XCTAssertEqual(clock.elapsed, 30, accuracy: 0.001)
    }

    func testJoinReturnsReviewURLWhenSessionHasAlreadyEnded() async throws {
        let transport = FakeAiTutorTransport(responses: [
            .response(410, #"{"status":"ended","review_url":"/practice/42/review?from=ended"}"#),
        ])
        let api = makeAPI(transport: transport)

        let outcome = try await api.join()

        XCTAssertEqual(outcome, .ended(reviewURL: URL(string: "https://study.nurio.kr/practice/42/review?from=ended")!))
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testJoinTreatsSignInRedirectAsRejection() async {
        let transport = FakeAiTutorTransport(responses: [ .response(302, "") ])
        let api = makeAPI(transport: transport)

        do {
            _ = try await api.join()
            XCTFail("expected rejection")
        } catch {
            XCTAssertEqual(error as? AiTutorCallAPIError, .rejected(302))
        }
    }

    // MARK: - End

    func testEndRetriesTransientFailuresAndReturnsServerReviewURL() async {
        let transport = FakeAiTutorTransport(responses: [
            .response(500, ""),
            .failure,
            .response(200, #"{"review_url":"/practice/42/review"}"#),
        ])
        let clock = FakeAiTutorClock()
        let api = makeAPI(transport: transport, clock: clock)

        let reviewURL = await api.end()

        XCTAssertEqual(reviewURL, URL(string: "https://study.nurio.kr/practice/42/review"))
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertTrue(transport.requests.allSatisfy { $0.url == URL(string: "https://study.nurio.kr/practice/42/tutor/end") })
    }

    func testEndStopsAfterThreeAttemptsAndFallsBackToPageReviewURL() async {
        let transport = FakeAiTutorTransport(repeating: .response(500, ""))
        let api = makeAPI(transport: transport)

        let reviewURL = await api.end()

        XCTAssertEqual(reviewURL, URL(string: "https://study.nurio.kr/practice/42/review"))
        XCTAssertEqual(transport.requests.count, 3)
    }

    func testEndIgnoresReviewURLOnAnotherOrigin() async {
        let transport = FakeAiTutorTransport(responses: [
            .response(200, #"{"review_url":"https://evil.example/phish"}"#),
        ])
        let api = makeAPI(transport: transport)

        let reviewURL = await api.end()

        XCTAssertEqual(reviewURL, URL(string: "https://study.nurio.kr/practice/42/review"))
    }

    // MARK: - Headers and cookies

    func testCallRequestsCarryCSRFTokenWebViewSessionCookieAndJSONHeaders() async throws {
        let transport = FakeAiTutorTransport(responses: [
            .response(200, #"{"status":"connecting","livekit":{"url":"wss://lk.example","room":"r","participant_token":"t"}}"#),
        ])
        let cookieStore = FakeAiTutorCookieStore(cookies: [
            try XCTUnwrap(cookie(name: "_nurio_session", value: "abc", domain: "study.nurio.kr")),
        ])
        let api = makeAPI(transport: transport, cookieStore: cookieStore)

        _ = try await api.join()

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-CSRF-Token"), "csrf-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "_nurio_session=abc")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.httpBody, Data("{}".utf8))
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertEqual(cookieStore.requestedURLs, [ URL(string: "https://study.nurio.kr/practice/42/tutor/join")! ])
    }

    func testRotatedSessionCookieIsWrittenBackToTheWebViewStore() async {
        let transport = FakeAiTutorTransport(responses: [
            .response(
                200,
                #"{"review_url":"/practice/42/review"}"#,
                headers: [ "Set-Cookie": "_nurio_session=rotated; path=/; secure; HttpOnly" ]
            ),
        ])
        let cookieStore = FakeAiTutorCookieStore(cookies: [])
        let api = makeAPI(transport: transport, cookieStore: cookieStore)

        _ = await api.end()

        XCTAssertEqual(cookieStore.stored.map(\.name), [ "_nurio_session" ])
        XCTAssertEqual(cookieStore.stored.first?.value, "rotated")
    }

    func testCookieMatcherSendsOnlyLiveCookiesForTheStudyHostAndPath() throws {
        let now = Date()
        let cookies = [
            try XCTUnwrap(cookie(name: "session", value: "1", domain: "study.nurio.kr")),
            try XCTUnwrap(cookie(name: "shared", value: "2", domain: ".nurio.kr")),
            try XCTUnwrap(cookie(name: "foreign", value: "3", domain: "evil.example")),
            try XCTUnwrap(cookie(name: "other_path", value: "4", domain: "study.nurio.kr", path: "/admin")),
            try XCTUnwrap(cookie(name: "expired", value: "5", domain: "study.nurio.kr", expires: now.addingTimeInterval(-60))),
            try XCTUnwrap(cookie(name: "lookalike", value: "6", domain: "notstudy.nurio.kr")),
        ]

        let matched = AiTutorCookieMatcher.cookies(
            cookies,
            for: URL(string: "https://study.nurio.kr/practice/42/tutor/join")!,
            now: now
        )

        XCTAssertEqual(Set(matched.map(\.name)), [ "session", "shared" ])
    }

    // MARK: - Coordinator and bridge

    func testDuplicateStartForTheSamePageIsIgnoredWhileTheCallIsActive() throws {
        let launcher = AiTutorCallLauncherSpy()
        let coordinator = AiTutorCallCoordinator(baseURL: baseURL, launcher: launcher)
        let presenter = visiblePresenter()

        XCTAssertEqual(coordinator.handleStart(startData(), presenter: presenter), .started)
        XCTAssertEqual(coordinator.handleStart(startData(), presenter: presenter), .alreadyActive)
        XCTAssertEqual(
            coordinator.handleStart(startData(joinUrl: "/practice/7/tutor/join"), presenter: presenter),
            .busy
        )
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertTrue(coordinator.isCallActive)

        try XCTUnwrap(launcher.finishers.first)()

        XCTAssertFalse(coordinator.isCallActive)
        XCTAssertEqual(coordinator.handleStart(startData(), presenter: presenter), .started)
        XCTAssertEqual(launcher.launches.count, 2)
    }

    func testStartWithoutAVisiblePresenterLeavesTheWebCallInPlace() {
        let launcher = AiTutorCallLauncherSpy()
        let coordinator = AiTutorCallCoordinator(baseURL: baseURL, launcher: launcher)

        XCTAssertEqual(coordinator.handleStart(startData(), presenter: nil), .rejected)
        XCTAssertEqual(coordinator.handleStart(startData(), presenter: UIViewController()), .rejected)
        XCTAssertEqual(
            coordinator.handleStart(startData(joinUrl: "https://evil.example/join"), presenter: visiblePresenter()),
            .rejected
        )
        XCTAssertTrue(launcher.launches.isEmpty)
    }

    func testBridgeRepliesPresentedOnlyWhenNativeOwnsTheCall() throws {
        XCTAssertTrue(AiTutorCallComponent.shouldReplyPresented(to: .started))
        XCTAssertTrue(AiTutorCallComponent.shouldReplyPresented(to: .alreadyActive))
        XCTAssertFalse(AiTutorCallComponent.shouldReplyPresented(to: .busy))
        XCTAssertFalse(AiTutorCallComponent.shouldReplyPresented(to: .rejected))

        let encoded = try JSONEncoder().encode(AiTutorCallComponent.PresentedReply())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: String])
        XCTAssertEqual(json, [ "event": "presented" ])
        XCTAssertEqual(AiTutorCallComponent.name, "ai-tutor-call")
    }

    // MARK: - Screen support

    func testCountdownFormatsRemainingTimeAndClampsAtZero() {
        XCTAssertEqual(AiTutorCallCountdown.format(remaining: 600), "10:00")
        XCTAssertEqual(AiTutorCallCountdown.format(remaining: 61.2), "1:02")
        XCTAssertEqual(AiTutorCallCountdown.format(remaining: 0.4), "0:01")
        XCTAssertEqual(AiTutorCallCountdown.format(remaining: -5), "0:00")
    }

    func testCallScreenCopyIsLocalizedInEnglishAndKorean() throws {
        let keys = [
            "ai_tutor_call_title",
            "ai_tutor_call_mute",
            "ai_tutor_call_unmute",
            "ai_tutor_call_end",
            "ai_tutor_call_remaining_accessibility",
        ] + AiTutorCallStatus.allCases.map(\.localizationKey)

        var tables: [String: [String: String]] = [:]
        for localization in [ "en", "ko" ] {
            let url = try XCTUnwrap(
                Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: localization)
            )
            tables[localization] = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        }

        for key in keys {
            let english = try XCTUnwrap(tables["en"]?[key], key)
            let korean = try XCTUnwrap(tables["ko"]?[key], key)
            XCTAssertFalse(english.isEmpty, key)
            XCTAssertFalse(korean.isEmpty, key)
            XCTAssertNotEqual(english, korean, key)
        }
        XCTAssertEqual(tables["en"]?["ai_tutor_call_status_live"], "Listening — speak whenever you're ready.")
        XCTAssertEqual(tables["ko"]?["ai_tutor_call_status_live"], "듣고 있어요. 편하게 말해 주세요.")
    }

    func testCallKeepsRunningWhenTheScreenLocks() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        XCTAssertEqual(modes, [ "audio" ])
    }

    func testCallAudioSessionDefaultsToSpeakerAndAllowsBluetooth() {
        let options = AiTutorLiveCall.audioSessionOptions
        XCTAssertTrue(options.contains(.defaultToSpeaker))
        XCTAssertTrue(options.contains(.allowBluetoothA2DP))
        XCTAssertFalse(options.contains(.mixWithOthers))
    }

    // MARK: - Helpers

    private func startData(joinUrl: String = "/practice/42/tutor/join") -> AiTutorCallStartData {
        AiTutorCallStartData(
            joinUrl: joinUrl,
            endUrl: "/practice/42/tutor/end",
            reviewUrl: "/practice/42/review",
            topic: " Ordering coffee ",
            csrfToken: "csrf-123"
        )
    }

    private func makeAPI(
        transport: FakeAiTutorTransport,
        cookieStore: FakeAiTutorCookieStore? = nil,
        clock: FakeAiTutorClock = FakeAiTutorClock()
    ) -> AiTutorCallAPI {
        AiTutorCallAPI(
            endpoints: AiTutorCallEndpoints.resolve(startData(), baseURL: baseURL)!,
            baseURL: baseURL,
            transport: transport,
            cookieStore: cookieStore ?? FakeAiTutorCookieStore(cookies: []),
            clock: clock
        )
    }

    private func cookie(
        name: String,
        value: String,
        domain: String,
        path: String = "/",
        expires: Date? = nil
    ) -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path,
            .secure: "TRUE",
        ]
        if let expires { properties[.expires] = expires }
        return HTTPCookie(properties: properties)
    }

    private func visiblePresenter() -> UIViewController {
        let presenter = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = presenter
        window.isHidden = false
        presenter.loadViewIfNeeded()
        addTeardownBlock { window.isHidden = true }
        return presenter
    }
}

private final class FakeAiTutorTransport: AiTutorHTTPTransport {
    enum Reply {
        case response(Int, String, headers: [String: String] = [:])
        case failure
    }

    private var responses: [Reply]
    private let fallback: Reply?
    private(set) var requests: [URLRequest] = []

    init(responses: [Reply]) {
        self.responses = responses
        self.fallback = nil
    }

    init(repeating reply: Reply) {
        self.responses = []
        self.fallback = reply
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let reply = responses.isEmpty ? fallback : responses.removeFirst()

        switch reply {
        case let .response(status, body, headers)?:
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            return (Data(body.utf8), response)
        case .failure?, .none:
            throw URLError(.networkConnectionLost)
        }
    }
}

@MainActor
private final class FakeAiTutorCookieStore: AiTutorCookieStore {
    private let cookies: [HTTPCookie]
    private(set) var requestedURLs: [URL] = []
    private(set) var stored: [HTTPCookie] = []

    init(cookies: [HTTPCookie]) {
        self.cookies = cookies
    }

    func cookies(for url: URL) async -> [HTTPCookie] {
        requestedURLs.append(url)
        return cookies
    }

    func store(_ cookies: [HTTPCookie]) async {
        stored.append(contentsOf: cookies)
    }
}

private final class FakeAiTutorClock: AiTutorClock {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var current: Date
    private(set) var sleeps: [TimeInterval] = []

    init() {
        current = start
    }

    var elapsed: TimeInterval { current.timeIntervalSince(start) }

    func now() -> Date { current }

    func sleep(seconds: TimeInterval) async throws {
        sleeps.append(seconds)
        current = current.addingTimeInterval(seconds)
    }
}

@MainActor
private final class AiTutorCallLauncherSpy: AiTutorCallLaunching {
    private(set) var launches: [AiTutorCallEndpoints] = []
    private(set) var finishers: [@MainActor () -> Void] = []

    func launch(
        endpoints: AiTutorCallEndpoints,
        presenter: UIViewController,
        onFinished: @escaping @MainActor () -> Void
    ) -> AnyObject {
        launches.append(endpoints)
        finishers.append(onFinished)
        return NSObject()
    }
}
