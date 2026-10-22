import FirebaseMessaging
import Foundation
import HotwireNative

/// Hands the web every Live Activity push token plus the FCM token, so the
/// server can start and update event-group Live Activities over APNs. While
/// connected, a newly issued token triggers a fresh reply to the same `connect`.
@MainActor
final class LiveActivityTokensComponent: BridgeComponent {
    override class var name: String { "live-activity-tokens" }

    private var tokenObserver: NSObjectProtocol?

    override func onReceive(message: Message) {
        guard message.event == "connect" else { return }

        observeTokenChanges()
        replyWithTokens()
    }

    private func observeTokenChanges() {
        guard tokenObserver == nil else { return }

        tokenObserver = NotificationCenter.default.addObserver(
            forName: .liveActivityTokensDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.replyWithTokens() }
        }
    }

    private func replyWithTokens() {
        if let token = NativePushTokenStore.shared.tokenData().token {
            reply(to: "connect", with: LiveActivityTokenStore.shared.payload(fcmToken: token))
            return
        }

        Messaging.messaging().token { token, _ in
            Task { @MainActor in
                if let token, !token.isEmpty {
                    NativePushTokenStore.shared.update(token: token)
                }
                self.reply(to: "connect", with: LiveActivityTokenStore.shared.payload(fcmToken: token))
            }
        }
    }

    deinit {
        if let tokenObserver {
            NotificationCenter.default.removeObserver(tokenObserver)
        }
    }
}
