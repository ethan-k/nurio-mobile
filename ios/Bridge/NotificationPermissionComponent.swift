import Foundation
import HotwireNative
import UIKit
import UserNotifications

@MainActor
final class NotificationPermissionComponent: BridgeComponent {
    override class var name: String { "notification-permission" }

    override func onReceive(message: Message) {
        switch message.event {
        case "status":
            Task { await replyWithCurrentStatus(to: message.event) }
        case "request":
            Task { await handleRequest() }
        case "open_settings":
            Task { await handleOpenSettings() }
        default:
            break
        }
    }

    private func currentStatus() async -> NotificationPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationPermissionStatus.from(settings.authorizationStatus)
    }

    private func replyWithCurrentStatus(to event: String) async {
        let data = StatusData(status: await currentStatus().rawValue)
        _ = try? await reply(to: event, with: data)
    }

    private func handleRequest() async {
        if await currentStatus() == .notDetermined {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        await replyWithCurrentStatus(to: "request")
    }

    private func handleOpenSettings() async {
        if let url = settingsURL() {
            await UIApplication.shared.open(url)
        }
        await replyWithCurrentStatus(to: "open_settings")
    }

    private func settingsURL() -> URL? {
        if #available(iOS 16.0, *),
           let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            return url
        }
        return URL(string: UIApplication.openSettingsURLString)
    }
}

private extension NotificationPermissionComponent {
    struct StatusData: Encodable {
        let status: String
    }
}
