import Foundation
import OSLog

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "auth"
)

enum NativeAuthCallback {
    static func tokenAuthURL(from callbackURL: URL, baseURL: URL) -> URL? {
        guard isCallbackURL(callbackURL) else {
            authLogger.debug("NativeAuthCallback ignored non-callback url=\(callbackURL.absoluteString, privacy: .public)")
            return nil
        }

        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
            let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
            !token.isEmpty,
            !state.isEmpty
        else {
            authLogger.error("NativeAuthCallback missing token or state in callback url=\(callbackURL.absoluteString, privacy: .public)")
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

        guard let url = tokenAuthComponents?.url else {
            authLogger.error("NativeAuthCallback failed to construct token_auth url")
            return nil
        }

        authLogger.info("NativeAuthCallback built token_auth url=\(url.absoluteString, privacy: .public)")
        return url
    }

    static func isCallbackURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == AppEnvironment.callbackScheme && url.host == "auth-callback"
    }
}
