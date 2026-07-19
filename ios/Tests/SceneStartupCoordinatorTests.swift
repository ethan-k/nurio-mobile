import Foundation
import XCTest
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
