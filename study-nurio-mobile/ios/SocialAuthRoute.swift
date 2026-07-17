import Foundation

enum SocialAuthProvider: Equatable {
    case kakao
    case google
    case naver

    init?(path: String) {
        switch path {
        case "/auth/kakao":
            self = .kakao
        case "/auth/google_oauth2":
            self = .google
        case "/auth/naver":
            self = .naver
        default:
            return nil
        }
    }
}

struct SocialAuthRoute: Equatable {
    let provider: SocialAuthProvider
    let url: URL

    static func resolve(startPath: String, baseURL: URL) -> SocialAuthRoute? {
        guard
            let baseScheme = baseURL.scheme?.lowercased(),
            baseScheme == "http" || baseScheme == "https",
            let baseHost = baseURL.host,
            baseURL.user == nil,
            baseURL.password == nil,
            let url = URL(string: startPath, relativeTo: baseURL)?.absoluteURL,
            let scheme = url.scheme?.lowercased(),
            scheme == baseScheme,
            let host = url.host,
            host.caseInsensitiveCompare(baseHost) == .orderedSame,
            effectivePort(for: url, scheme: scheme) == effectivePort(for: baseURL, scheme: baseScheme),
            url.user == nil,
            url.password == nil,
            let percentEncodedPath = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )?.percentEncodedPath,
            let provider = SocialAuthProvider(path: percentEncodedPath)
        else {
            return nil
        }

        return SocialAuthRoute(provider: provider, url: url)
    }

    private static func effectivePort(for url: URL, scheme: String) -> Int {
        if let port = url.port {
            return port
        }

        return scheme == "http" ? 80 : 443
    }
}
