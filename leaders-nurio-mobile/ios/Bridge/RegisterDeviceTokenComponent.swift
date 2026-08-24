import FirebaseCore
import FirebaseMessaging
import HotwireNative
import UIKit
import UserNotifications

@MainActor
final class RegisterDeviceTokenComponent: BridgeComponent {
    override class var name: String { "register-device-token" }

    override func onReceive(message: Message) {
        guard message.event == "connect" else { return }
        guard FirebaseApp.app() != nil else {
            reply(to: "connect", with: NativePushTokenStore.shared.tokenData(error: .firebaseNotConfigured))
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.handle(settings.authorizationStatus)
            }
        }
    }

    private func handle(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            registerAndFetchToken()
        case .notDetermined:
            requestAuthorization()
        case .denied:
            reply(
                to: "connect",
                with: NativePushTokenStore.shared.tokenData(error: .notificationPermissionDenied)
            )
        @unknown default:
            reply(
                to: "connect",
                with: NativePushTokenStore.shared.tokenData(error: .notificationPermissionFailed)
            )
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [ .alert, .badge, .sound ]) {
            granted, error in
            Task { @MainActor in
                if let authorizationError = NativePushRegistrationError.authorizationError(
                    granted: granted,
                    requestFailed: error != nil
                ) {
                    self.reply(
                        to: "connect",
                        with: NativePushTokenStore.shared.tokenData(error: authorizationError)
                    )
                    return
                }

                self.registerAndFetchToken()
            }
        }
    }

    private func registerAndFetchToken() {
        UIApplication.shared.registerForRemoteNotifications()

        let cached = NativePushTokenStore.shared.tokenData()
        if cached.token != nil {
            reply(to: "connect", with: cached)
            return
        }

        Messaging.messaging().token { token, _ in
            Task { @MainActor in
                if let token {
                    NativePushTokenStore.shared.update(token: token)
                }
                self.reply(to: "connect", with: NativePushTokenStore.shared.tokenData())
            }
        }
    }
}
