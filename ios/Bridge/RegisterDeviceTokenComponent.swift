import FirebaseMessaging
import Foundation
import HotwireNative

@MainActor
final class RegisterDeviceTokenComponent: BridgeComponent {
    override class var name: String { "register-device-token" }

    override func onReceive(message: Message) {
        guard message.event == "connect" else { return }

        let cachedTokenData = NativePushTokenStore.shared.tokenData()
        if cachedTokenData.token != nil {
            reply(to: "connect", with: cachedTokenData)
            return
        }

        Messaging.messaging().token { token, error in
            Task { @MainActor in
                if let token, !token.isEmpty {
                    NativePushTokenStore.shared.update(token: token)
                    self.reply(to: "connect", with: NativePushTokenStore.shared.tokenData())
                    return
                }

                self.reply(
                    to: "connect",
                    with: NativePushTokenStore.shared.tokenData(error: error?.localizedDescription)
                )
            }
        }
    }
}
