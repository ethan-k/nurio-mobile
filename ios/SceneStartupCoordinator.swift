import Foundation

final class SceneStartupCoordinator {
    typealias NextMainTurnScheduler = (@escaping () -> Void) -> Void

    private enum State {
        case idle
        case bootstrapping
        case starting
        case started
    }

    private let localeBootstrapper: LocaleBootstrapping
    private let startNavigator: () -> Void
    private let route: (URL) -> Void
    private let nextMainTurn: NextMainTurnScheduler

    private var state = State.idle
    private var queuedURLs: [URL] = []

    init(
        localeBootstrapper: LocaleBootstrapping,
        startNavigator: @escaping () -> Void,
        route: @escaping (URL) -> Void,
        nextMainTurn: @escaping NextMainTurnScheduler
    ) {
        self.localeBootstrapper = localeBootstrapper
        self.startNavigator = startNavigator
        self.route = route
        self.nextMainTurn = nextMainTurn
    }

    func start() {
        guard state == .idle else {
            return
        }

        state = .bootstrapping
        localeBootstrapper.bootstrap { [weak self] in
            self?.finishBootstrap()
        }
    }

    func handleIncoming(_ url: URL) {
        switch state {
        case .idle, .bootstrapping, .starting:
            queuedURLs.append(url)
        case .started:
            route(url)
        }
    }

    private func finishBootstrap() {
        guard state == .bootstrapping else {
            return
        }

        state = .starting
        startNavigator()
        nextMainTurn { [weak self] in
            self?.drainQueuedURLs()
        }
    }

    private func drainQueuedURLs() {
        guard state == .starting else {
            return
        }

        state = .started
        let urlsToRoute = queuedURLs
        queuedURLs.removeAll()
        urlsToRoute.forEach(route)
    }
}
