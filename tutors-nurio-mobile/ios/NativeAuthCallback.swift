import Foundation

enum NativeAuthCallback {
    static func tokenAuthURL(from callbackURL: URL, baseURL: URL) -> URL? {
        guard isCallbackURL(callbackURL) else { return nil }

        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
            let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
            !token.isEmpty,
            !state.isEmpty
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
        url.scheme?.lowercased() == AppEnvironment.callbackScheme && url.host == "auth-callback"
    }
}
