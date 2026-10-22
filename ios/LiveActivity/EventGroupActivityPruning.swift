import Foundation

/// Decides which event-group Live Activities to end. Kept free of ActivityKit so
/// the rules are unit-testable: at most one activity per event (the newest
/// survives) and nothing past its end time.
enum EventGroupActivityPruning {
    struct Snapshot: Equatable {
        let id: String
        let eventId: Int
        let staleDate: Date?
        /// Position in `Activity.activities`; a larger value means started later.
        let order: Int
    }

    static func idsToEnd(_ snapshots: [Snapshot], now: Date) -> [String] {
        let expired = snapshots.filter { isExpired($0, now: now) }
        let live = snapshots.filter { !isExpired($0, now: now) }
        let duplicates = Dictionary(grouping: live, by: \.eventId).values.flatMap { group in
            group.sorted { $0.order > $1.order }.dropFirst()
        }

        return (expired + duplicates).sorted { $0.order < $1.order }.map(\.id)
    }

    /// The activity to keep for `eventId` (the newest), if any.
    static func survivor(for eventId: Int, in snapshots: [Snapshot]) -> Snapshot? {
        snapshots.filter { $0.eventId == eventId }.max { $0.order < $1.order }
    }

    static func isExpired(_ snapshot: Snapshot, now: Date) -> Bool {
        guard let staleDate = snapshot.staleDate else { return false }
        return staleDate <= now
    }
}
