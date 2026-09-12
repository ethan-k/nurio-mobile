import Foundation
import XCTest
import HotwireNative
import WebKit
@testable import Nurio

final class SceneStartupCoordinatorTests: XCTestCase {
    func testNavigatorStartRemainsUncalledWhileLocaleBootstrapIsPending() {
        let bootstrapper = FakeLocaleBootstrapper()
        let scheduler = FakeNextMainTurnScheduler()
        var navigatorStartCount = 0
        let coordinator = SceneStartupCoordinator(
            localeBootstrapper: bootstrapper,
            startNavigator: { navigatorStartCount += 1 },
            route: { _ in },
            nextMainTurn: scheduler.schedule
        )

        coordinator.start()

        XCTAssertEqual(bootstrapper.bootstrapCount, 1)
        XCTAssertEqual(navigatorStartCount, 0)
        XCTAssertTrue(scheduler.actions.isEmpty)
    }

    func testColdURLAndLaterDeepLinkQueueInArrivalOrderUntilScheduledDrain() {
        let bootstrapper = FakeLocaleBootstrapper()
        let scheduler = FakeNextMainTurnScheduler()
        let coldURL = URL(string: "nurio://open?source=cold")!
        let laterURL = URL(string: "https://nurio.kr/events/42")!
        var navigatorStartCount = 0
        var routedURLs: [URL] = []
        let coordinator = SceneStartupCoordinator(
            localeBootstrapper: bootstrapper,
            startNavigator: { navigatorStartCount += 1 },
            route: { routedURLs.append($0) },
            nextMainTurn: scheduler.schedule
        )

        coordinator.handleIncoming(coldURL)
        coordinator.start()
        coordinator.handleIncoming(laterURL)
        bootstrapper.complete()

        XCTAssertEqual(navigatorStartCount, 1)
        XCTAssertTrue(routedURLs.isEmpty)
        XCTAssertEqual(scheduler.actions.count, 1)

        scheduler.runNext()

        XCTAssertEqual(routedURLs, [ coldURL, laterURL ])
    }

    func testBootstrapCompletionStartsNavigatorExactlyOnceAndSchedulesOneDrain() {
        let bootstrapper = FakeLocaleBootstrapper()
        let scheduler = FakeNextMainTurnScheduler()
        var navigatorStartCount = 0
        var startupEvents: [String] = []
        let coordinator = SceneStartupCoordinator(
            localeBootstrapper: bootstrapper,
            startNavigator: {
                navigatorStartCount += 1
                startupEvents.append("navigator-start")
            },
            route: { _ in },
            nextMainTurn: { action in
                startupEvents.append("drain-scheduled")
                scheduler.schedule(action)
            }
        )

        coordinator.start()
        bootstrapper.complete()

        XCTAssertEqual(navigatorStartCount, 1)
        XCTAssertEqual(scheduler.actions.count, 1)
        XCTAssertEqual(startupEvents, [ "navigator-start", "drain-scheduled" ])
    }

    func testURLArrivingWhileNavigatorIsStartingJoinsScheduledDrain() {
        let bootstrapper = FakeLocaleBootstrapper()
        let scheduler = FakeNextMainTurnScheduler()
        let coldURL = URL(string: "nurio://open?source=cold")!
        let duringStartURL = URL(string: "nurio://open?source=during-start")!
        var routedURLs: [URL] = []
        let coordinator = SceneStartupCoordinator(
            localeBootstrapper: bootstrapper,
            startNavigator: {},
            route: { routedURLs.append($0) },
            nextMainTurn: scheduler.schedule
        )

        coordinator.handleIncoming(coldURL)
        coordinator.start()
        bootstrapper.complete()
        coordinator.handleIncoming(duringStartURL)

        XCTAssertTrue(routedURLs.isEmpty)

        scheduler.runNext()

        XCTAssertEqual(routedURLs, [ coldURL, duringStartURL ])
    }

    func testURLsAfterStartedRouteImmediately() {
        let bootstrapper = FakeLocaleBootstrapper()
        let scheduler = FakeNextMainTurnScheduler()
        let liveURL = URL(string: "https://nurio.kr/events/99")!
        var routedURLs: [URL] = []
        let coordinator = SceneStartupCoordinator(
            localeBootstrapper: bootstrapper,
            startNavigator: {},
            route: { routedURLs.append($0) },
            nextMainTurn: scheduler.schedule
        )

        coordinator.start()
        bootstrapper.complete()
        scheduler.runNext()
        coordinator.handleIncoming(liveURL)

        XCTAssertEqual(routedURLs, [ liveURL ])
        XCTAssertTrue(scheduler.actions.isEmpty)
    }

    func testDuplicateBootstrapCompletionCannotStartOrDrainTwice() {
        let bootstrapper = FakeLocaleBootstrapper()
        let scheduler = FakeNextMainTurnScheduler()
        let coldURL = URL(string: "nurio://open?source=cold")!
        var navigatorStartCount = 0
        var routedURLs: [URL] = []
        let coordinator = SceneStartupCoordinator(
            localeBootstrapper: bootstrapper,
            startNavigator: { navigatorStartCount += 1 },
            route: { routedURLs.append($0) },
            nextMainTurn: scheduler.schedule
        )

        coordinator.handleIncoming(coldURL)
        coordinator.start()
        bootstrapper.complete()
        bootstrapper.complete()

        XCTAssertEqual(navigatorStartCount, 1)
        XCTAssertEqual(scheduler.actions.count, 1)

        scheduler.runNext()

        XCTAssertEqual(routedURLs, [ coldURL ])
    }

    func testBootstrapFailureOrTimeoutCompletionUsesNormalStartupPath() {
        for outcome in [ "failure", "timeout" ] {
            let bootstrapper = FakeLocaleBootstrapper()
            let scheduler = FakeNextMainTurnScheduler()
            let queuedURL = URL(string: "nurio://open?outcome=\(outcome)")!
            var navigatorStartCount = 0
            var routedURLs: [URL] = []
            let coordinator = SceneStartupCoordinator(
                localeBootstrapper: bootstrapper,
                startNavigator: { navigatorStartCount += 1 },
                route: { routedURLs.append($0) },
                nextMainTurn: scheduler.schedule
            )

            coordinator.handleIncoming(queuedURL)
            coordinator.start()
            bootstrapper.complete()

            XCTAssertEqual(navigatorStartCount, 1, outcome)
            XCTAssertTrue(routedURLs.isEmpty, outcome)
            XCTAssertEqual(scheduler.actions.count, 1, outcome)

            scheduler.runNext()

            XCTAssertEqual(routedURLs, [ queuedURL ], outcome)
        }
    }

    func testStartIsIdempotent() {
        let bootstrapper = FakeLocaleBootstrapper()
        let scheduler = FakeNextMainTurnScheduler()
        var navigatorStartCount = 0
        let coordinator = SceneStartupCoordinator(
            localeBootstrapper: bootstrapper,
            startNavigator: { navigatorStartCount += 1 },
            route: { _ in },
            nextMainTurn: scheduler.schedule
        )

        coordinator.start()
        coordinator.start()
        bootstrapper.complete()

        XCTAssertEqual(bootstrapper.bootstrapCount, 1)
        XCTAssertEqual(navigatorStartCount, 1)
        XCTAssertEqual(scheduler.actions.count, 1)
    }
}

private final class FakeLocaleBootstrapper: LocaleBootstrapping {
    private var completion: (() -> Void)?
    private(set) var bootstrapCount = 0

    func bootstrap(completion: @escaping () -> Void) {
        bootstrapCount += 1
        self.completion = completion
    }

    func complete() {
        completion?()
    }
}

private final class FakeNextMainTurnScheduler {
    private(set) var actions: [() -> Void] = []

    func schedule(_ action: @escaping () -> Void) {
        actions.append(action)
    }

    func runNext() {
        actions.removeFirst()()
    }
}


final class CheckoutVisitRecoveryTests: XCTestCase {
    @MainActor
    func testTurboCheckoutProposalsColdBootTheirDestinationSession() async {
        for (path, context) in [
            ("/orders/new", "default"),
            ("/orders/42/payment_summary", "modal"),
            ("/pass_packages/4/purchase", "modal"),
            ("/pass_packages/4/payment_summary", "modal"),
            ("/payments/portone/complete?paymentId=test", "default")
        ] {
            let (navigator, delegate, views) = makeNavigator()
            let destination = URL(string: path, relativeTo: AppEnvironment.baseURL)!.absoluteURL
            let webView = views[context == "modal" ? 1 : 0]
            webView.reportedURL = URL(string: "https://gateway.invalid/payment")!
            let loaded = expectation(description: "Initial visit and recovered cold boot: \(path)")
            loaded.expectedFulfillmentCount = 2
            webView.onLoad = { url in
                XCTAssertEqual(url, destination)
                loaded.fulfill()
            }

            // Calling route with a proposal is the Turbo/native callback path:
            // no WKNavigationAction policy handler participates here.
            navigator.route(VisitProposal(url: destination, options: .init(), properties: [
                "context": context, "animated": false
            ]))
            await fulfillment(of: [loaded], timeout: 5)
            XCTAssertEqual(webView.requests, [destination, destination])
            XCTAssertTrue(views[context == "modal" ? 0 : 1].requests.isEmpty)
            withExtendedLifetime(delegate) {}
        }
    }

    @MainActor
    func testRecoveryDoesNotLoadAfterUserNavigatesAway() async {
        let (navigator, delegate, views) = makeNavigator()
        views[0].reportedURL = URL(string: "https://gateway.invalid/payment")!
        navigator.route(AppEnvironment.baseURL.appendingPathComponent("orders/new"))
        navigator.route(AppEnvironment.baseURL.appendingPathComponent("events/42"))
        let unexpectedLoad = expectation(description: "Abandoned checkout must not reload")
        unexpectedLoad.isInverted = true
        views[0].onLoad = { _ in unexpectedLoad.fulfill() }
        await fulfillment(of: [unexpectedLoad], timeout: 0.3)
        XCTAssertEqual(views[0].requests.map(\.path), ["/orders/new", "/events/42"])
        withExtendedLifetime(delegate) {}
    }

    @MainActor
    func testHealthySessionKeepsNormalNavigation() async {
        let (navigator, delegate, views) = makeNavigator()
        views[0].reportedURL = AppEnvironment.baseURL.appendingPathComponent("events/42")
        let destination = AppEnvironment.baseURL.appendingPathComponent("orders/new")
        let proposal = VisitProposal(url: destination, options: .init(), properties: [:])
        if case .accept = delegate.handle(proposal: proposal, from: navigator) {
            XCTAssertTrue(views[0].requests.isEmpty)
        } else {
            XCTFail("Healthy checkout must retain the default controller")
        }
    }

    func testRecoveryExcludesGatewayPostsAndUnrelatedDestinations() {
        let base = URL(string: "https://nurio.kr")!
        for value in [
            "https://ksmobile.inicis.com/smart/payment/",
            "https://other.example/orders/new",
            "http://nurio.kr/orders/new",
            "https://nurio.kr:444/orders/new",
            "https://nurio.kr/events/42",
            "https://nurio.kr/orders/42",
            "nurio://payment-complete"
        ] {
            XCTAssertFalse(CheckoutNavigation.isRecoveryDestination(URL(string: value)!, baseURL: base), value)
        }
    }

    @MainActor
    private func makeNavigator() -> (Navigator, SceneController, [CheckoutRecoveryTestWebView]) {
        let originalFactory = Hotwire.config.makeCustomWebView
        defer { Hotwire.config.makeCustomWebView = originalFactory }
        var views: [CheckoutRecoveryTestWebView] = []
        Hotwire.config.makeCustomWebView = { configuration in
            let view = CheckoutRecoveryTestWebView(frame: .zero, configuration: configuration)
            views.append(view)
            return view
        }
        let delegate = SceneController()
        let navigator = Navigator(configuration: .init(name: "checkout-recovery-test", startLocation: AppEnvironment.baseURL), delegate: delegate)
        return (navigator, delegate, views)
    }
}

private final class CheckoutRecoveryTestWebView: WKWebView {
    var reportedURL: URL?
    var requests: [URL] = []
    var onLoad: ((URL) -> Void)?

    override var url: URL? { reportedURL }

    override func load(_ request: URLRequest) -> WKNavigation? {
        if let url = request.url {
            requests.append(url)
            onLoad?(url)
        }
        return nil
    }
}
