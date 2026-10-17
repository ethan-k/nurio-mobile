import Foundation

enum NotificationDestination {
    private static let blockedPrefixes = [
        "/admin",
        "/tutoring",
        "/tutors",
    ]

    static func resolve(path: String?, url: String?, baseURL: URL) -> URL {
        guard let base = validBaseComponents(baseURL) else { return baseURL }
        let root = baseURL

        return resolveCandidate(path, base: base)
            ?? resolveCandidate(url, base: base)
            ?? root
    }

    /// True when the push points at the screen the visible web view already shows.
    /// Only the path is compared: the push and the page may differ in query
    /// parameters such as `lang` without being different screens.
    static func isShowing(path: String?, url: String?, visibleURL: URL?, baseURL: URL) -> Bool {
        guard
            let visibleURL,
            let base = validBaseComponents(baseURL),
            let destination = resolveCandidate(path, base: base) ?? resolveCandidate(url, base: base),
            visibleURL.host?.lowercased() == destination.host?.lowercased()
        else { return false }

        return normalizedPath(visibleURL) == normalizedPath(destination)
    }

    private static func normalizedPath(_ url: URL) -> String {
        let path = url.path
        guard path.count > 1, path.hasSuffix("/") else { return path.isEmpty ? "/" : path }
        return String(path.dropLast())
    }

    private static func resolveCandidate(_ candidate: String?, base: URLComponents) -> URL? {
        guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
              let components = URLComponents(string: value),
              components.fragment == nil,
              components.user == nil,
              components.password == nil else {
            return nil
        }

        let isRelativePath = components.scheme == nil && components.host == nil
        let isSameOriginURL = components.scheme?.lowercased() == "https" &&
            components.host?.lowercased() == base.host?.lowercased() &&
            effectivePort(components) == effectivePort(base)

        guard isRelativePath || isSameOriginURL else { return nil }

        let encodedPath = components.percentEncodedPath
        let hasDotSegment = encodedPath
            .split(separator: "/", omittingEmptySubsequences: false)
            .contains { segment in segment == "." || segment == ".." }
        guard encodedPath.hasPrefix("/"),
              !encodedPath.hasPrefix("//"),
              !encodedPath.contains("%"),
              !hasDotSegment,
              !isBlocked(encodedPath) else {
            return nil
        }

        return normalizedURL(path: encodedPath, query: components.percentEncodedQuery, base: base)
    }

    private static func validBaseComponents(_ baseURL: URL) -> URLComponents? {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.query == nil,
              components.path.isEmpty || components.path == "/",
              effectivePort(components) == 443 else {
            return nil
        }

        return components
    }

    private static func normalizedURL(path: String, query: String?, base: URLComponents) -> URL? {
        var normalized = URLComponents()
        normalized.scheme = "https"
        normalized.host = base.host?.lowercased()
        normalized.percentEncodedPath = path
        normalized.percentEncodedQuery = query
        return normalized.url
    }

    private static func effectivePort(_ components: URLComponents) -> Int {
        components.port ?? 443
    }

    private static func isBlocked(_ path: String) -> Bool {
        let normalized = path.lowercased()
        return blockedPrefixes.contains { prefix in
            normalized == prefix || normalized.hasPrefix("\(prefix)/")
        }
    }
}
