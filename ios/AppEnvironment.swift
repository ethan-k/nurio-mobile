import Foundation

enum AppEnvironment {
    static let callbackScheme = "nurio"
    static let pathConfigurationResourceName = "ios_v1"

    static var baseURL: URL {
        guard let url = resolveBaseURL(
            configuredValue: Bundle.main.object(forInfoDictionaryKey: "NurioBaseURL") as? String,
            overrideValue: ProcessInfo.processInfo.environment["NURIO_BASE_URL"]
        ) else {
            preconditionFailure("NurioBaseURL must contain a valid HTTP(S) server URL. Check the selected build configuration.")
        }
        return url
    }

    static func resolveBaseURL(configuredValue: String?, overrideValue: String?) -> URL? {
#if DEBUG
        if let overrideURL = validatedBaseURL(overrideValue) {
            return overrideURL
        }
#endif
        return validatedBaseURL(configuredValue)
    }

    private static func validatedBaseURL(_ value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            return nil
        }
        return url
    }

    static var coldStartURL: URL {
        coldStartURL(for: baseURL)
    }

    static func coldStartURL(for baseURL: URL) -> URL {
        baseURL
    }

    static var eventsURL: URL {
        eventsURL(for: baseURL)
    }

    static func eventsURL(for baseURL: URL) -> URL {
        baseURL.appendingPathComponent("events")
    }

    static var signInURL: URL {
        baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
    }

    static let oauthPaths: Set<String> = [
        "/auth/google_oauth2",
        "/auth/kakao",
        "/auth/naver",
        "/auth/apple",
    ]
}
