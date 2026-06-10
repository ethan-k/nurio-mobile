import Foundation

enum TutorScopePolicy {
    private static let blockedPrefixes = [
        "/admin",
    ]

    static func isBlocked(_ url: URL, appHost: String? = AppEnvironment.baseURL.host?.lowercased()) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if let appHost, host == appHost || host.hasSuffix(".\(appHost)") {
            return blockedPrefixes.contains(where: { prefix in
                path == prefix || path.hasPrefix("\(prefix)/")
            })
        }

        return false
    }
}
