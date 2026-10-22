import Foundation

extension Notification.Name {
    static let liveActivityTokensDidChange = Notification.Name("NurioLiveActivityTokensDidChange")
}

extension Data {
    var lowercaseHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

/// The `live-activity-tokens` reply: every Live Activity push token the device
/// currently holds, plus the FCM token that identifies the device to the server.
struct LiveActivityTokenPayload: Encodable, Equatable {
    struct Entry: Codable, Equatable {
        static let pushToStartKind = "push_to_start"
        static let activityKind = "activity"

        let kind: String
        let token: String
        let eventId: Int?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind, forKey: .kind)
            try container.encode(token, forKey: .token)
            try container.encodeIfPresent(eventId, forKey: .eventId)
        }
    }

    let fcmToken: String?
    let tokens: [Entry]

    private enum CodingKeys: String, CodingKey {
        case fcmToken
        case tokens
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Always present: the web posts `null` explicitly when FCM has no token yet.
        try container.encode(fcmToken, forKey: .fcmToken)
        try container.encode(tokens, forKey: .tokens)
    }
}

/// Persists Live Activity push tokens across launches so the web can re-post
/// them on any page. Activity tokens are keyed by the ActivityKit activity id.
@MainActor
final class LiveActivityTokenStore {
    static let shared = LiveActivityTokenStore()

    private struct ActivityToken: Codable, Equatable {
        let token: String
        let eventId: Int
    }

    private static let pushToStartKey = "liveActivity.pushToStartToken"
    private static let activityTokensKey = "liveActivity.activityTokens"

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter

    init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    func updatePushToStartToken(_ token: Data) {
        let hex = token.lowercaseHexString
        guard defaults.string(forKey: Self.pushToStartKey) != hex else { return }

        defaults.set(hex, forKey: Self.pushToStartKey)
        notifyChange()
    }

    func updateActivityToken(_ token: Data, activityId: String, eventId: Int) {
        var tokens = activityTokens()
        let entry = ActivityToken(token: token.lowercaseHexString, eventId: eventId)
        guard tokens[activityId] != entry else { return }

        tokens[activityId] = entry
        save(tokens)
    }

    func removeActivity(id activityId: String) {
        var tokens = activityTokens()
        guard tokens.removeValue(forKey: activityId) != nil else { return }

        save(tokens)
    }

    /// Drops tokens for activities that no longer exist (ended while the app was not running).
    func retainActivities(ids activityIds: Set<String>) {
        let tokens = activityTokens()
        let retained = tokens.filter { activityIds.contains($0.key) }
        guard retained.count != tokens.count else { return }

        save(retained)
    }

    func payload(fcmToken: String?) -> LiveActivityTokenPayload {
        var entries: [LiveActivityTokenPayload.Entry] = []
        if let pushToStart = defaults.string(forKey: Self.pushToStartKey), !pushToStart.isEmpty {
            entries.append(.init(kind: LiveActivityTokenPayload.Entry.pushToStartKind, token: pushToStart, eventId: nil))
        }

        let activityEntries = activityTokens()
            .sorted { $0.key < $1.key }
            .map { LiveActivityTokenPayload.Entry(kind: LiveActivityTokenPayload.Entry.activityKind, token: $0.value.token, eventId: $0.value.eventId) }
        entries.append(contentsOf: activityEntries)

        let normalizedFcmToken = (fcmToken?.isEmpty ?? true) ? nil : fcmToken
        return LiveActivityTokenPayload(fcmToken: normalizedFcmToken, tokens: entries)
    }

    private func activityTokens() -> [String: ActivityToken] {
        guard let data = defaults.data(forKey: Self.activityTokensKey),
              let tokens = try? JSONDecoder().decode([String: ActivityToken].self, from: data) else {
            return [:]
        }
        return tokens
    }

    private func save(_ tokens: [String: ActivityToken]) {
        defaults.set(try? JSONEncoder().encode(tokens), forKey: Self.activityTokensKey)
        notifyChange()
    }

    private func notifyChange() {
        notificationCenter.post(name: .liveActivityTokensDidChange, object: self)
    }
}
