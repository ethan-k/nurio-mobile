import XCTest
@testable import Nurio

@MainActor
final class LiveActivityTokenStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LiveActivityTokenStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore(notificationCenter: NotificationCenter = NotificationCenter()) -> LiveActivityTokenStore {
        LiveActivityTokenStore(defaults: defaults, notificationCenter: notificationCenter)
    }

    private func json(_ payload: LiveActivityTokenPayload) throws -> NSDictionary {
        let data = try JSONEncoder().encode(payload)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    func testShouldEncodeTokenDataAsLowercaseHex() {
        let data = Data([0x00, 0x0A, 0xAB, 0xFF])

        XCTAssertEqual(data.lowercaseHexString, "000aabff")
    }

    func testShouldReplyWithNullFcmTokenAndNoTokensWhenEmpty() throws {
        let store = makeStore()

        let body = try json(store.payload(fcmToken: nil))

        XCTAssertTrue(body["fcmToken"] is NSNull)
        XCTAssertEqual((body["tokens"] as? NSArray)?.count, 0)
    }

    func testShouldTreatEmptyFcmTokenAsNull() throws {
        let store = makeStore()

        let body = try json(store.payload(fcmToken: ""))

        XCTAssertTrue(body["fcmToken"] is NSNull)
    }

    func testShouldReplyWithPushToStartAndActivityTokensInContractShape() throws {
        let store = makeStore()
        store.updatePushToStartToken(Data([0xDE, 0xAD]))
        store.updateActivityToken(Data([0xBE, 0xEF]), activityId: "activity-1", eventId: 123)

        let body = try json(store.payload(fcmToken: "fcm-abc"))

        XCTAssertEqual(body["fcmToken"] as? String, "fcm-abc")
        let tokens = try XCTUnwrap(body["tokens"] as? [NSDictionary])
        XCTAssertEqual(tokens, [
            ["kind": "push_to_start", "token": "dead"],
            ["kind": "activity", "token": "beef", "eventId": 123],
        ])
    }

    func testShouldPersistTokensAcrossStoreInstances() {
        makeStore().updateActivityToken(Data([0x01]), activityId: "a", eventId: 7)

        let payload = makeStore().payload(fcmToken: nil)

        XCTAssertEqual(payload.tokens, [.init(kind: "activity", token: "01", eventId: 7)])
    }

    func testShouldDropTokensOfEndedActivities() {
        let store = makeStore()
        store.updateActivityToken(Data([0x01]), activityId: "a", eventId: 1)
        store.updateActivityToken(Data([0x02]), activityId: "b", eventId: 2)
        store.updateActivityToken(Data([0x03]), activityId: "c", eventId: 3)

        store.removeActivity(id: "a")
        store.retainActivities(ids: ["b"])

        XCTAssertEqual(store.payload(fcmToken: nil).tokens, [.init(kind: "activity", token: "02", eventId: 2)])
    }

    func testShouldNotifyOnlyWhenATokenActuallyChanges() {
        let center = NotificationCenter()
        let store = makeStore(notificationCenter: center)
        var notifications = 0
        let observer = center.addObserver(forName: .liveActivityTokensDidChange, object: nil, queue: nil) { _ in
            notifications += 1
        }
        defer { center.removeObserver(observer) }

        store.updatePushToStartToken(Data([0x01]))
        store.updatePushToStartToken(Data([0x01]))
        store.updateActivityToken(Data([0x02]), activityId: "a", eventId: 1)
        store.updateActivityToken(Data([0x02]), activityId: "a", eventId: 1)
        store.removeActivity(id: "missing")

        XCTAssertEqual(notifications, 2)
    }
}

final class EventGroupActivityPruningTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func snapshot(_ id: String, event: Int, order: Int, staleDate: Date? = nil) -> EventGroupActivityPruning.Snapshot {
        .init(id: id, eventId: event, staleDate: staleDate, order: order)
    }

    func testShouldKeepNewestActivityPerEventAndEndOlderDuplicates() {
        let snapshots = [
            snapshot("old", event: 1, order: 0),
            snapshot("other", event: 2, order: 1),
            snapshot("middle", event: 1, order: 2),
            snapshot("newest", event: 1, order: 3),
        ]

        XCTAssertEqual(EventGroupActivityPruning.idsToEnd(snapshots, now: now), ["old", "middle"])
    }

    func testShouldEndActivitiesPastTheirEndTime() {
        let snapshots = [
            snapshot("expired", event: 1, order: 0, staleDate: now.addingTimeInterval(-60)),
            snapshot("upcoming", event: 2, order: 1, staleDate: now.addingTimeInterval(60)),
            snapshot("open-ended", event: 3, order: 2),
        ]

        XCTAssertEqual(EventGroupActivityPruning.idsToEnd(snapshots, now: now), ["expired"])
    }

    func testShouldKeepALiveActivityWhenTheNewestDuplicateIsExpired() {
        let snapshots = [
            snapshot("live", event: 1, order: 0, staleDate: now.addingTimeInterval(60)),
            snapshot("expired", event: 1, order: 1, staleDate: now.addingTimeInterval(-60)),
        ]

        XCTAssertEqual(EventGroupActivityPruning.idsToEnd(snapshots, now: now), ["expired"])
    }

    func testShouldPickNewestActivityAsSurvivorForEvent() {
        let snapshots = [
            snapshot("a", event: 1, order: 0),
            snapshot("b", event: 1, order: 2),
            snapshot("c", event: 2, order: 3),
        ]

        XCTAssertEqual(EventGroupActivityPruning.survivor(for: 1, in: snapshots)?.id, "b")
        XCTAssertNil(EventGroupActivityPruning.survivor(for: 9, in: snapshots))
    }
}

final class EventGroupSyncRequestTests: XCTestCase {
    private func decode(_ json: String) throws -> EventGroupSyncRequest {
        try JSONDecoder().decode(EventGroupSyncRequest.self, from: Data(json.utf8))
    }

    func testShouldDecodeSyncMessageWithOffsetEndTime() throws {
        let request = try decode("""
        {"eventId":123,"eventTitle":"Friday Meetup","groupName":"Table 3","topic":"Travel","endsAt":"2026-10-23T22:00:00+09:00"}
        """)

        XCTAssertEqual(request.eventId, 123)
        XCTAssertEqual(request.groupName, "Table 3")
        XCTAssertEqual(request.endsAtDate, Date(timeIntervalSince1970: 1_792_760_400))
    }

    func testShouldDecodeNullGroupAndEndTime() throws {
        let request = try decode("""
        {"eventId":5,"eventTitle":"Meetup","groupName":null,"topic":null,"endsAt":null}
        """)

        XCTAssertNil(request.groupName)
        XCTAssertNil(request.endsAtDate)
        XCTAssertFalse(request.wantsActivity(now: Date()))
    }

    func testShouldWantActivityOnlyWhileGroupIsAssignedAndEventNotEnded() throws {
        let request = try decode("""
        {"eventId":1,"eventTitle":"Meetup","groupName":"Table 1","topic":null,"endsAt":"2026-10-23T22:00:00+09:00"}
        """)
        let endsAt = try XCTUnwrap(request.endsAtDate)

        XCTAssertTrue(request.wantsActivity(now: endsAt.addingTimeInterval(-1)))
        XCTAssertFalse(request.wantsActivity(now: endsAt))
    }
}
