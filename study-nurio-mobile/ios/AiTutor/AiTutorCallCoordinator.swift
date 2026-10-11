import UIKit

/// Starts the native class review call screen. Kept behind a protocol so the
/// coordinator's start/duplicate rules are testable without LiveKit.
@MainActor
protocol AiTutorCallLaunching: AnyObject {
    func launch(
        endpoints: AiTutorCallEndpoints,
        presenter: UIViewController,
        onFinished: @escaping @MainActor () -> Void
    ) -> AnyObject
}

/// Owns the single active class review call. The call outlives the web view
/// controller that requested it, so a page re-render or a repeated bridge
/// `start` never creates a second call or drops the running one.
@MainActor
final class AiTutorCallCoordinator {
    enum StartDecision: Equatable {
        /// A new native call was launched; the page must hand over to native.
        case started
        /// The same page asked again while its call is running; keep the
        /// existing call and tell the page native still owns it.
        case alreadyActive
        /// Another session's call is running; leave that page to the web.
        case busy
        /// The request could not be honoured; the web call stays available.
        case rejected
    }

    static let shared = AiTutorCallCoordinator(
        baseURL: AppEnvironment.baseURL,
        launcher: AiTutorLiveCallLauncher()
    )

    private let baseURL: URL
    private let launcher: AiTutorCallLaunching
    private var activeJoinURL: URL?
    private var activeCall: AnyObject?

    init(baseURL: URL, launcher: AiTutorCallLaunching) {
        self.baseURL = baseURL
        self.launcher = launcher
    }

    var isCallActive: Bool { activeCall != nil }

    func handleStart(_ data: AiTutorCallStartData, presenter: UIViewController?) -> StartDecision {
        guard let endpoints = AiTutorCallEndpoints.resolve(data, baseURL: baseURL) else {
            return .rejected
        }

        if activeCall != nil {
            return activeJoinURL == endpoints.joinURL ? .alreadyActive : .busy
        }

        guard let presenter, presenter.viewIfLoaded?.window != nil else {
            return .rejected
        }

        activeJoinURL = endpoints.joinURL
        activeCall = launcher.launch(endpoints: endpoints, presenter: presenter) { [weak self] in
            self?.activeCall = nil
            self?.activeJoinURL = nil
        }
        return .started
    }
}
