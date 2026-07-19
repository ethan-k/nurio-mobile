import Foundation
import OSLog
import WebKit

private let localeBootstrapLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "kr.nurio",
    category: "locale-bootstrap"
)

enum NativeLocaleResolver {
    private static let supportedLanguages = Set([ "en", "ko" ])

    static func resolve(_ identifiers: [String]) -> String {
        for identifier in identifiers {
            let normalized = identifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "-")
            let subtags = normalized.split(separator: "-", omittingEmptySubsequences: false)

            guard isWellFormed(subtags), let base = subtags.first else {
                continue
            }

            let language = base.lowercased()
            if supportedLanguages.contains(language) {
                return language
            }
        }

        return "en"
    }

    private static func isWellFormed(_ subtags: [Substring]) -> Bool {
        guard
            !subtags.isEmpty,
            subtags.allSatisfy({ subtag in
                (1...8).contains(subtag.count) &&
                    subtag.utf8.allSatisfy(isASCIILetterOrDigit)
            })
        else {
            return false
        }

        var index = 1
        while index < subtags.count && subtags[index].count > 1 {
            index += 1
        }

        return validateSingletonSequences(in: subtags, startingAt: index)
    }

    private static func validateSingletonSequences(
        in subtags: [Substring],
        startingAt startIndex: Int
    ) -> Bool {
        var index = startIndex

        while index < subtags.count {
            let singleton = subtags[index]
            guard singleton.count == 1 else {
                return false
            }

            index += 1
            if singleton.lowercased() == "x" {
                return index < subtags.count
            }

            let payloadStart = index
            while index < subtags.count && subtags[index].count >= 2 {
                index += 1
            }
            guard index > payloadStart else {
                return false
            }
        }

        return true
    }

    private static func isASCIILetterOrDigit(_ character: UInt8) -> Bool {
        (65...90).contains(character) ||
            (97...122).contains(character) ||
            (48...57).contains(character)
    }
}

protocol LocaleCookieStoring {
    func cookies(completion: @escaping (Result<[HTTPCookie], Error>) -> Void)
    func setCookie(
        _ cookie: HTTPCookie,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

protocol LocaleBootstrapping {
    func bootstrap(completion: @escaping () -> Void)
}

final class WebKitLocaleCookieStore: LocaleCookieStoring {
    private let cookieStore: WKHTTPCookieStore

    init(cookieStore: WKHTTPCookieStore = WKWebsiteDataStore.default().httpCookieStore) {
        self.cookieStore = cookieStore
    }

    func cookies(completion: @escaping (Result<[HTTPCookie], Error>) -> Void) {
        cookieStore.getAllCookies { cookies in
            completion(.success(cookies))
        }
    }

    func setCookie(
        _ cookie: HTTPCookie,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        cookieStore.setCookie(cookie) {
            completion(.success(()))
        }
    }
}

final class NativeLocaleBootstrap: LocaleBootstrapping {
    typealias TimeoutScheduler = (TimeInterval, @escaping () -> Void) -> Void

    private static let timeout: TimeInterval = 1.5
    private static let cookieLifetime: TimeInterval = 365 * 24 * 60 * 60
    private static let localeCookieNames = Set([ "locale", "device_locale" ])

    private let baseURL: URL
    private let languageIdentifiers: () -> [String]
    private let store: LocaleCookieStoring
    private let clock: () -> Date
    private let timeoutScheduler: TimeoutScheduler

    init(
        baseURL: URL,
        languageIdentifiers: @escaping () -> [String] = { Locale.preferredLanguages },
        store: LocaleCookieStoring = WebKitLocaleCookieStore(),
        clock: @escaping () -> Date = Date.init,
        timeoutScheduler: @escaping TimeoutScheduler = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        }
    ) {
        self.baseURL = baseURL
        self.languageIdentifiers = languageIdentifiers
        self.store = store
        self.clock = clock
        self.timeoutScheduler = timeoutScheduler
    }

    func bootstrap(completion: @escaping () -> Void) {
        let state = LocaleBootstrapState()

        timeoutScheduler(Self.timeout) {
            guard state.finishOnTimeout() else {
                return
            }

            localeBootstrapLogger.warning("Locale cookie bootstrap timed out")
            completion()
        }

        store.cookies { [self] result in
            switch result {
            case .failure(let error):
                guard state.finishReading() else {
                    return
                }

                localeBootstrapLogger.warning(
                    "Locale cookie read failed: \(error.localizedDescription, privacy: .public)"
                )
                completion()

            case .success(let cookies):
                if cookies.contains(where: { cookieAppliesToBaseURL($0) }) {
                    guard state.finishReading() else {
                        return
                    }

                    completion()
                    return
                }

                guard let cookie = deviceLocaleCookie() else {
                    guard state.finishReading() else {
                        return
                    }

                    localeBootstrapLogger.warning("Locale cookie construction failed")
                    completion()
                    return
                }

                guard state.beginWriting() else {
                    return
                }

                store.setCookie(cookie) { result in
                    guard state.finishWriting() else {
                        return
                    }

                    if case .failure(let error) = result {
                        localeBootstrapLogger.warning(
                            "Locale cookie write failed: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                    completion()
                }
            }
        }
    }

    private func deviceLocaleCookie() -> HTTPCookie? {
        guard
            let scheme = baseURL.scheme?.lowercased(),
            [ "http", "https" ].contains(scheme),
            let host = baseURL.host,
            !host.isEmpty
        else {
            return nil
        }

        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: "device_locale",
            .value: NativeLocaleResolver.resolve(languageIdentifiers()),
            .domain: host,
            .path: requestPath,
            .expires: clock().addingTimeInterval(Self.cookieLifetime),
            .sameSitePolicy: "Lax"
        ]
        if scheme == "https" {
            properties[.secure] = "TRUE"
        }

        return HTTPCookie(properties: properties)
    }

    private func cookieAppliesToBaseURL(_ cookie: HTTPCookie) -> Bool {
        Self.localeCookieNames.contains(cookie.name) &&
            domain(cookie.domain, appliesTo: baseURL.host) &&
            path(cookie.path, appliesTo: requestPath) &&
            (!cookie.isSecure || baseURL.scheme?.lowercased() == "https")
    }

    private var requestPath: String {
        baseURL.path.isEmpty ? "/" : baseURL.path
    }

    private func domain(_ cookieDomain: String, appliesTo host: String?) -> Bool {
        guard let host else {
            return false
        }

        let normalizedHost = host.lowercased()
        let includesSubdomains = cookieDomain.hasPrefix(".")
        let normalizedDomain = cookieDomain
            .drop(while: { $0 == "." })
            .lowercased()

        guard !normalizedDomain.isEmpty else {
            return false
        }

        if normalizedHost == normalizedDomain {
            return true
        }

        return includesSubdomains && normalizedHost.hasSuffix(".\(normalizedDomain)")
    }

    private func path(_ cookiePath: String, appliesTo requestPath: String) -> Bool {
        let normalizedCookiePath = cookiePath.isEmpty ? "/" : cookiePath

        guard requestPath.hasPrefix(normalizedCookiePath) else {
            return false
        }
        if requestPath == normalizedCookiePath || normalizedCookiePath.hasSuffix("/") {
            return true
        }

        return requestPath.dropFirst(normalizedCookiePath.count).first == "/"
    }
}

private final class LocaleBootstrapState {
    private enum Phase {
        case reading
        case writing
        case finished
    }

    private let lock = NSLock()
    private var phase = Phase.reading

    func beginWriting() -> Bool {
        transition(from: .reading, to: .writing)
    }

    func finishReading() -> Bool {
        transition(from: .reading, to: .finished)
    }

    func finishWriting() -> Bool {
        transition(from: .writing, to: .finished)
    }

    func finishOnTimeout() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard phase != .finished else {
            return false
        }

        phase = .finished
        return true
    }

    private func transition(from expected: Phase, to next: Phase) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard phase == expected else {
            return false
        }

        phase = next
        return true
    }
}
