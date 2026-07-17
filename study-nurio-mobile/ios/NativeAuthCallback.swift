import Foundation

enum NativeAuthCallback {
    static func tokenAuthURL(from callbackURL: URL, baseURL: URL) -> URL? {
        guard
            let components = callbackComponents(for: callbackURL),
            let queryItems = components.queryItems,
            let token = singleNonblankValue(named: "token", in: queryItems),
            let state = singleNonblankValue(named: "state", in: queryItems)
        else {
            return nil
        }

        let tokenAuthURL = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("native")
            .appendingPathComponent("token_auth")
        var tokenAuthComponents = URLComponents(url: tokenAuthURL, resolvingAgainstBaseURL: false)
        tokenAuthComponents?.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "state", value: state),
        ]

        return tokenAuthComponents?.url
    }

    static func isCallbackURL(_ url: URL) -> Bool {
        callbackComponents(for: url) != nil
    }

    private static func callbackComponents(for url: URL) -> URLComponents? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == AppEnvironment.callbackScheme,
            let host = components.host,
            host.caseInsensitiveCompare("auth-callback") == .orderedSame,
            components.user == nil,
            components.password == nil,
            components.port == nil,
            components.percentEncodedPath.isEmpty,
            components.fragment == nil
        else {
            return nil
        }

        return components
    }

    private static func singleNonblankValue(
        named name: String,
        in queryItems: [URLQueryItem]
    ) -> String? {
        let values = queryItems.filter { $0.name == name }
        guard
            values.count == 1,
            let value = values[0].value,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return value
    }
}
