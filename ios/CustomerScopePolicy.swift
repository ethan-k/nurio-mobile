import Foundation

enum CustomerScopePolicy {
    private static let blockedPrefixes = [
        "/admin",
        "/tutoring",
        "/tutors",
    ]

    static func isBlocked(_ url: URL, appHost: String? = AppEnvironment.baseURL.host?.lowercased()) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }

        let host = url.host?.lowercased() ?? ""
        let path = LocalePath.stripLocalePrefix(url.path).lowercased()

        if host.hasPrefix("tutors.") {
            return true
        }

        if let appHost, host == appHost || host.hasSuffix(".\(appHost)") {
            return blockedPrefixes.contains(where: { prefix in
                path == prefix || path.hasPrefix("\(prefix)/")
            })
        }

        return false
    }

    /// nurio study is a separate product; its links leave the customer app for Safari.
    static func opensInSystemBrowser(_ url: URL, appHost: String? = AppEnvironment.baseURL.host?.lowercased()) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let appHost
        else {
            return false
        }

        return url.host?.lowercased() == "study.\(appHost)"
    }
}
