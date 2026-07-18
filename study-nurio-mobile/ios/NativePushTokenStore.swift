import Foundation

enum NativePushRegistrationError: String, CaseIterable {
    case firebaseNotConfigured = "firebase_not_configured"
    case notificationPermissionDenied = "notification_permission_denied"
    case notificationPermissionFailed = "notification_permission_failed"
    case tokenUnavailable = "token_unavailable"

    static func authorizationError(granted: Bool, requestFailed: Bool) -> Self? {
        if requestFailed {
            return .notificationPermissionFailed
        }

        return granted ? nil : .notificationPermissionDenied
    }
}

@MainActor
final class NativePushTokenStore {
    static let shared = NativePushTokenStore()

    private var token: String?

    init(token: String? = nil) {
        update(token: token ?? "")
    }

    func update(token: String) {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        self.token = normalized
    }

    func tokenData(error: NativePushRegistrationError? = nil) -> TokenData {
        if let error {
            return TokenData(token: nil, platform: "ios", error: error.rawValue)
        }

        if let token {
            return TokenData(token: token, platform: "ios", error: nil)
        }

        return TokenData(
            token: nil,
            platform: "ios",
            error: NativePushRegistrationError.tokenUnavailable.rawValue
        )
    }
}

extension NativePushTokenStore {
    struct TokenData: Encodable, Equatable {
        let token: String?
        let platform: String
        let error: String?
    }
}
