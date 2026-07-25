import Foundation

enum LeaderScopePolicy {
    private static let blockedPrefixes = [
        "/admin",
    ]

    static func isBlocked(_ url: URL, appHost: String? = AppEnvironment.baseURL.host?.lowercased()) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        guard let appHost, host == appHost else { return true }

        return blockedPrefixes.contains(where: { prefix in
            path == prefix || path.hasPrefix("\(prefix)/")
        })
    }
}
