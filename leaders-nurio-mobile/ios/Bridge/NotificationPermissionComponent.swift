import HotwireNative
import UIKit
import UserNotifications

enum NotificationPermissionStatus: String, Equatable {
    case granted
    case denied
    case notDetermined = "not_determined"

    init(_ authorization: UNAuthorizationStatus) {
        switch authorization {
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

    struct ReplyData: Encodable, Equatable {
        let status: String
    }

    var replyData: ReplyData { ReplyData(status: rawValue) }
}

@MainActor
final class NotificationPermissionComponent: BridgeComponent {
    override class var name: String { "notification-permission" }

    override func onReceive(message: Message) {
        switch message.event {
        case "status":
            replyWithCurrentStatus(to: message.event)
        case "request":
            request()
        case "open_settings":
            openSettings()
            replyWithCurrentStatus(to: message.event)
        default:
            break
        }
    }

    private func replyWithCurrentStatus(to event: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = NotificationPermissionStatus(settings.authorizationStatus)
            Task { @MainActor in
                self.reply(to: event, with: status.replyData)
            }
        }
    }

    private func request() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let current = NotificationPermissionStatus(settings.authorizationStatus)
            guard current == .notDetermined else {
                Task { @MainActor in
                    self.reply(to: "request", with: current.replyData)
                }
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [ .alert, .badge, .sound ]) {
                granted, _ in
                Task { @MainActor in
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    self.replyWithCurrentStatus(to: "request")
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

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
