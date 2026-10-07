import UserNotifications
import XCTest
@testable import Nurio

final class NotificationPermissionStatusTests: XCTestCase {
    func testAuthorizedProvisionalAndEphemeralMapToGranted() {
        XCTAssertEqual(NotificationPermissionStatus.from(.authorized), .granted)
        XCTAssertEqual(NotificationPermissionStatus.from(.provisional), .granted)
        XCTAssertEqual(NotificationPermissionStatus.from(.ephemeral), .granted)
    }

    func testDeniedMapsToDenied() {
        XCTAssertEqual(NotificationPermissionStatus.from(.denied), .denied)
    }

    func testNotDeterminedMapsToNotDetermined() {
        XCTAssertEqual(NotificationPermissionStatus.from(.notDetermined), .notDetermined)
    }

    func testRawValuesMatchWebContract() {
        XCTAssertEqual(NotificationPermissionStatus.granted.rawValue, "granted")
        XCTAssertEqual(NotificationPermissionStatus.denied.rawValue, "denied")
        XCTAssertEqual(NotificationPermissionStatus.notDetermined.rawValue, "not_determined")
    }
}
