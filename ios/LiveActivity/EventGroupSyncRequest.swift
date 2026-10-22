import Foundation

/// The `event-group-live-activity` `sync` message data sent by the My Group page.
struct EventGroupSyncRequest: Decodable, Equatable {
    let eventId: Int
    let eventTitle: String
    let groupName: String?
    let topic: String?
    let endsAt: String?

    var endsAtDate: Date? {
        guard let endsAt, !endsAt.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: endsAt) { return date }

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: endsAt)
    }

    /// True when the page wants the activity shown: a group is assigned and the event has not ended.
    func wantsActivity(now: Date) -> Bool {
        guard let groupName, !groupName.isEmpty else { return false }
        guard let endsAtDate else { return true }
        return endsAtDate > now
    }
}
