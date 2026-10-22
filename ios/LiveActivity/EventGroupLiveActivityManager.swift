import ActivityKit
import Foundation
import OSLog

private let liveActivityLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "live-activity"
)

/// Owns the event-group Live Activities: starts, updates and ends them for the
/// My Group page, and records every push token so the server can drive them.
@available(iOS 16.2, *)
@MainActor
final class EventGroupLiveActivityManager {
    static let shared = EventGroupLiveActivityManager()

    private let tokenStore: LiveActivityTokenStore
    private var observedActivityIds = Set<String>()
    private var started = false

    private init() {
        tokenStore = LiveActivityTokenStore.shared
    }

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Called once at launch: cleans up leftovers, then observes token streams,
    /// including activities the server starts remotely while the app runs.
    func start() {
        guard !started else { return }
        started = true

        let activities = Activity<EventGroupAttributes>.activities
        tokenStore.retainActivities(ids: Set(activities.map(\.id)))
        Task { await self.endActivities(withIds: EventGroupActivityPruning.idsToEnd(Self.snapshots(), now: Date())) }

        activities.forEach(observe)

        Task {
            for await activity in Activity<EventGroupAttributes>.activityUpdates {
                self.observe(activity)
            }
        }

        if #available(iOS 17.2, *) {
            Task {
                for await token in Activity<EventGroupAttributes>.pushToStartTokenUpdates {
                    self.tokenStore.updatePushToStartToken(token)
                }
            }
        }
    }

    func sync(_ request: EventGroupSyncRequest) async {
        guard activitiesEnabled else { return }

        let snapshots = Self.snapshots()
        let matchingIds = snapshots.filter { $0.eventId == request.eventId }.map(\.id)

        guard request.wantsActivity(now: Date()) else {
            await endActivities(withIds: matchingIds)
            return
        }

        let state = EventGroupAttributes.ContentState(groupName: request.groupName, topic: request.topic)
        let content = ActivityContent(state: state, staleDate: request.endsAtDate)

        if let survivor = EventGroupActivityPruning.survivor(for: request.eventId, in: snapshots),
           let activity = Self.activity(withId: survivor.id) {
            await endActivities(withIds: matchingIds.filter { $0 != survivor.id })
            await activity.update(content)
            return
        }

        do {
            let activity = try Activity.request(
                attributes: EventGroupAttributes(eventId: request.eventId, eventTitle: request.eventTitle),
                content: content,
                pushType: .token
            )
            observe(activity)
        } catch {
            liveActivityLogger.error("Event group Live Activity request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func observe(_ activity: Activity<EventGroupAttributes>) {
        guard observedActivityIds.insert(activity.id).inserted else { return }

        let activityId = activity.id
        let eventId = activity.attributes.eventId

        Task {
            for await token in activity.pushTokenUpdates {
                self.tokenStore.updateActivityToken(token, activityId: activityId, eventId: eventId)
            }
        }

        Task {
            for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                self.tokenStore.removeActivity(id: activityId)
                self.observedActivityIds.remove(activityId)
            }
        }
    }

    private func endActivities(withIds ids: [String]) async {
        for id in ids {
            guard let activity = Self.activity(withId: id) else { continue }

            await activity.end(nil, dismissalPolicy: .immediate)
            tokenStore.removeActivity(id: id)
        }
    }

    private static func activity(withId id: String) -> Activity<EventGroupAttributes>? {
        Activity<EventGroupAttributes>.activities.first { $0.id == id }
    }

    private static func snapshots() -> [EventGroupActivityPruning.Snapshot] {
        Activity<EventGroupAttributes>.activities
            .enumerated()
            .filter { $0.element.activityState == .active || $0.element.activityState == .stale }
            .map { index, activity in
                EventGroupActivityPruning.Snapshot(
                    id: activity.id,
                    eventId: activity.attributes.eventId,
                    staleDate: activity.content.staleDate,
                    order: index
                )
            }
    }
}
