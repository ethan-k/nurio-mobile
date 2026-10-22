import Foundation
import HotwireNative

/// Mirrors the attendee's current meetup group from the My Group page into a
/// Live Activity. Replies `{ "supported": Bool }` so the page knows whether the
/// Lock Screen / Dynamic Island is showing it.
@MainActor
final class EventGroupLiveActivityComponent: BridgeComponent {
    override class var name: String { "event-group-live-activity" }

    override func onReceive(message: Message) {
        guard message.event == "sync" else { return }
        guard let request: EventGroupSyncRequest = message.data() else {
            reply(to: "sync", with: SyncReply(supported: false))
            return
        }

        Task {
            let supported = await Self.sync(request)
            _ = try? await reply(to: "sync", with: SyncReply(supported: supported))
        }
    }

    private static func sync(_ request: EventGroupSyncRequest) async -> Bool {
        guard #available(iOS 16.2, *) else { return false }

        let manager = EventGroupLiveActivityManager.shared
        guard manager.activitiesEnabled else { return false }

        await manager.sync(request)
        return true
    }
}

private extension EventGroupLiveActivityComponent {
    struct SyncReply: Encodable {
        let supported: Bool
    }
}
