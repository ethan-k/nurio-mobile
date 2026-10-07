import Foundation
import UserNotifications

enum NotificationPermissionStatus: String, Equatable {
    case granted
    case denied
    case notDetermined = "not_determined"

    static func from(_ status: UNAuthorizationStatus) -> NotificationPermissionStatus {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }
}
