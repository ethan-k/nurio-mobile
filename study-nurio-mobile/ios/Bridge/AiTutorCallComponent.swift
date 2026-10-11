import HotwireNative
import UIKit

/// `ai-tutor-call` bridge component (Rails
/// `app/javascript/controllers/bridge/ai_tutor_call_controller.js`). When the
/// class review page asks to start, the native call screen takes over and the
/// page is told via a `presented` reply so it stops offering its web call.
/// Without a reply the page keeps its WebView call.
@MainActor
final class AiTutorCallComponent: BridgeComponent {
    override class var name: String { "ai-tutor-call" }

    override func onReceive(message: Message) {
        guard message.event == "start" else { return }
        guard let data: AiTutorCallStartData = message.data() else { return }

        let decision = AiTutorCallCoordinator.shared.handleStart(
            data,
            presenter: delegate?.destination as? UIViewController
        )

        guard Self.shouldReplyPresented(to: decision) else { return }
        reply(to: "start", with: PresentedReply())
    }

    static func shouldReplyPresented(to decision: AiTutorCallCoordinator.StartDecision) -> Bool {
        switch decision {
        case .started, .alreadyActive:
            return true
        case .busy, .rejected:
            return false
        }
    }

    struct PresentedReply: Encodable, Equatable {
        var event = "presented"
    }
}
