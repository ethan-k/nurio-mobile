import Foundation

@MainActor
final class NativePushTokenStore {
    static let shared = NativePushTokenStore()

    private var token: String?
    private let platform = "ios"

    private init() {}

    func update(token: String) {
        self.token = token
    }

    func tokenData(error: String? = nil) -> TokenData {
        if let token, !token.isEmpty {
            return TokenData(token: token, platform: platform, error: nil)
        }

        return TokenData(token: nil, platform: platform, error: error ?? "FCM token unavailable")
    }
}

extension NativePushTokenStore {
    struct TokenData: Encodable {
        let token: String?
        let platform: String
        let error: String?
    }
}
