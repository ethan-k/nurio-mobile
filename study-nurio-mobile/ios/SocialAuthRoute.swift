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
            let url = URL(string: startPath, relativeTo: baseURL)?.absoluteURL,
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host,
            let baseHost = baseURL.host,
            host.caseInsensitiveCompare(baseHost) == .orderedSame,
            let provider = SocialAuthProvider(path: url.path)
        else {
            return nil
        }

        return SocialAuthRoute(provider: provider, url: url)
    }
}
