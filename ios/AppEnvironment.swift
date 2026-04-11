import Foundation

enum AppEnvironment {
    private static let defaultBaseURL = URL(string: "https://nurio.kr")!

    static let callbackScheme = "nurio"
    static let pathConfigurationResourceName = "ios_v1"

    static var baseURL: URL {
        guard
            let override = ProcessInfo.processInfo.environment["NURIO_BASE_URL"],
            let overrideURL = URL(string: override),
            overrideURL.scheme != nil,
            overrideURL.host != nil
        else {
            return defaultBaseURL
        }

        return overrideURL
    }

    static var startURL: URL {
        baseURL.appendingPathComponent("events")
    }

    static var signInURL: URL {
        baseURL.appendingPathComponent("signin")
    }

    static let oauthPaths: Set<String> = [
        "/auth/google_oauth2",
        "/auth/kakao",
        "/auth/naver",
    ]
}
