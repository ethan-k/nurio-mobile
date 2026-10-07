import HotwireNative
import UIKit
import UserNotifications

enum NotificationPermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            self = .granted
        case .denied:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .denied
        }
    }

    var messageData: NotificationPermissionMessageData {
        switch self {
        case .granted: NotificationPermissionMessageData(status: "granted")
        case .denied: NotificationPermissionMessageData(status: "denied")
        case .notDetermined: NotificationPermissionMessageData(status: "not_determined")
        }
    }
}

struct NotificationPermissionMessageData: Encodable, Equatable {
    let status: String
}

@MainActor
final class NotificationPermissionComponent: BridgeComponent {
    override class var name: String { "notification-permission" }

    override func onReceive(message: Message) {
        switch message.event {
        case "status":
            fetchStatus { self.reply(to: "status", with: $0.messageData) }
        case "request":
            request()
        case "open_settings":
            openSettings()
            fetchStatus { self.reply(to: "open_settings", with: $0.messageData) }
        default:
            break
        }
    }

    private func fetchStatus(_ completion: @escaping @MainActor (NotificationPermissionStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = NotificationPermissionStatus(settings.authorizationStatus)
            Task { @MainActor in completion(status) }
        }
    }

    private func request() {
        fetchStatus { status in
            guard status == .notDetermined else {
                self.reply(to: "request", with: status.messageData)
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [ .alert, .badge, .sound ]) { granted, _ in
                Task { @MainActor in
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    self.fetchStatus { self.reply(to: "request", with: $0.messageData) }
                }
            }
        }
    }

    private func openSettings() {
        let urlString: String
        if #available(iOS 16.0, *) {
            urlString = UIApplication.openNotificationSettingsURLString
        } else {
            urlString = UIApplication.openSettingsURLString
        }

        guard let url = URL(string: urlString) ?? URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }
}
