import ActivityKit

/// Shared by the app and the NurioLiveActivity extension. The server's APNs
/// payloads name this type (`attributes-type`) and its property names verbatim,
/// so renaming anything here breaks remote start and update.
@available(iOS 16.1, *)
struct EventGroupAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var groupName: String?
        var topic: String?
    }

    var eventId: Int
    var eventTitle: String
}
