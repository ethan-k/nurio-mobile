import Foundation
import WebKit

/// Payload of the `ai-tutor-call` bridge component's `start` message.
struct AiTutorCallStartData: Decodable, Equatable {
    let joinUrl: String
    let endUrl: String
    let reviewUrl: String
    let topic: String?
    let csrfToken: String?
}

/// The class review call's Rails endpoints, resolved against the app origin.
/// Paths that resolve to any other origin are rejected so session cookies are
/// never sent off the study host.
struct AiTutorCallEndpoints: Equatable {
    let joinURL: URL
    let endURL: URL
    let reviewURL: URL
    let topic: String
    let csrfToken: String

    static func resolve(_ data: AiTutorCallStartData, baseURL: URL) -> AiTutorCallEndpoints? {
        guard let joinURL = sameOriginURL(data.joinUrl, baseURL: baseURL),
              let endURL = sameOriginURL(data.endUrl, baseURL: baseURL),
              let reviewURL = sameOriginURL(data.reviewUrl, baseURL: baseURL) else {
            return nil
        }

        return AiTutorCallEndpoints(
            joinURL: joinURL,
            endURL: endURL,
            reviewURL: reviewURL,
            topic: data.topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            csrfToken: data.csrfToken ?? ""
        )
    }

    static func sameOriginURL(_ path: String, baseURL: URL) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let resolved = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL,
              resolved.user == nil,
              resolved.password == nil,
              resolved.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              resolved.host?.lowercased() == baseURL.host?.lowercased(),
              effectivePort(of: resolved) == effectivePort(of: baseURL) else {
            return nil
        }

        return resolved
    }

    private static func effectivePort(of url: URL) -> Int? {
        if let port = url.port { return port }
        switch url.scheme?.lowercased() {
        case "https": return 443
        case "http": return 80
        default: return nil
        }
    }
}

struct AiTutorLiveKitCredentials: Decodable, Equatable {
    let url: String
    let room: String
    let participantToken: String

    enum CodingKeys: String, CodingKey {
        case url
        case room
        case participantToken = "participant_token"
    }
}

enum AiTutorJoinOutcome: Equatable {
    case ready(AiTutorLiveKitCredentials, deadline: Date?)
    case ended(reviewURL: URL)
}

enum AiTutorCallAPIError: Error, Equatable {
    case provisioningTimedOut
    case rejected(Int)
    case invalidResponse
    case transport
}

protocol AiTutorHTTPTransport: AnyObject {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Bridges the Hotwire web view's cookie jar to native requests: the call API
/// authenticates with the same Rails session cookie the WKWebView holds.
@MainActor
protocol AiTutorCookieStore: AnyObject {
    func cookies(for url: URL) async -> [HTTPCookie]
    func store(_ cookies: [HTTPCookie]) async
}

protocol AiTutorClock: AnyObject {
    func now() -> Date
    func sleep(seconds: TimeInterval) async throws
}

/// Timings shared with the web call (`ai_tutor_call_controller.js`).
enum AiTutorCallTiming {
    static let pollInterval: TimeInterval = 1.5
    static let provisioningTimeout: TimeInterval = 30
    static let endAttempts = 3
    static let endRetryDelay: TimeInterval = 1
}

/// Join-poll and end logic for the class review call (Rails
/// `Study::AiTutorSessionsController#join` / `#finish`). Mirrors the web
/// call's timings so both clients behave the same.
@MainActor
final class AiTutorCallAPI {
    let endpoints: AiTutorCallEndpoints
    private let baseURL: URL
    private let transport: AiTutorHTTPTransport
    private let cookieStore: AiTutorCookieStore
    private let clock: AiTutorClock
    private let pollInterval: TimeInterval
    private let provisioningTimeout: TimeInterval
    private let endAttempts: Int
    private let endRetryDelay: TimeInterval

    init(
        endpoints: AiTutorCallEndpoints,
        baseURL: URL,
        transport: AiTutorHTTPTransport,
        cookieStore: AiTutorCookieStore,
        clock: AiTutorClock,
        pollInterval: TimeInterval = AiTutorCallTiming.pollInterval,
        provisioningTimeout: TimeInterval = AiTutorCallTiming.provisioningTimeout,
        endAttempts: Int = AiTutorCallTiming.endAttempts,
        endRetryDelay: TimeInterval = AiTutorCallTiming.endRetryDelay
    ) {
        self.endpoints = endpoints
        self.baseURL = baseURL
        self.transport = transport
        self.cookieStore = cookieStore
        self.clock = clock
        self.pollInterval = pollInterval
        self.provisioningTimeout = provisioningTimeout
        self.endAttempts = max(1, endAttempts)
        self.endRetryDelay = endRetryDelay
    }

    /// Posts to the join endpoint until the tutor room is ready (200), the
    /// session has already ended (410), or provisioning exceeds the timeout.
    func join() async throws -> AiTutorJoinOutcome {
        let startedAt = clock.now()

        while true {
            let (data, response) = try await post(endpoints.joinURL)

            switch response.statusCode {
            case 410:
                return .ended(reviewURL: reviewURL(from: data))
            case 200..<300:
                let body = try decode(JoinBody.self, from: data)
                let deadline = body.deadlineAt.flatMap(Self.parseDate)
                if let livekit = body.livekit {
                    return .ready(livekit, deadline: deadline)
                }
                guard response.statusCode == 202 || body.status == "provisioning" else {
                    throw AiTutorCallAPIError.invalidResponse
                }
            default:
                throw AiTutorCallAPIError.rejected(response.statusCode)
            }

            if clock.now().timeIntervalSince(startedAt) >= provisioningTimeout {
                throw AiTutorCallAPIError.provisioningTimedOut
            }

            do {
                try await clock.sleep(seconds: pollInterval)
            } catch {
                throw AiTutorCallAPIError.transport
            }
        }
    }

    /// Ends the session, retrying transient failures. Always returns where the
    /// learner should land: the server's review URL, or the page's own.
    func end() async -> URL {
        for attempt in 1...endAttempts {
            if let (data, response) = try? await post(endpoints.endURL),
               (200..<300).contains(response.statusCode) || response.statusCode == 410 {
                return reviewURL(from: data)
            }

            if attempt < endAttempts {
                try? await clock.sleep(seconds: endRetryDelay)
            }
        }

        return endpoints.reviewURL
    }

    func makeRequest(url: URL, cookies: [HTTPCookie]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !endpoints.csrfToken.isEmpty {
            request.setValue(endpoints.csrfToken, forHTTPHeaderField: "X-CSRF-Token")
        }
        for (field, value) in HTTPCookie.requestHeaderFields(with: cookies) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = Data("{}".utf8)
        return request
    }

    private func post(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        let cookies = await cookieStore.cookies(for: url)
        let request = makeRequest(url: url, cookies: cookies)

        let result: (Data, HTTPURLResponse)
        do {
            result = try await transport.send(request)
        } catch {
            throw AiTutorCallAPIError.transport
        }

        let responseCookies = Self.cookies(from: result.1, url: url)
        if !responseCookies.isEmpty {
            await cookieStore.store(responseCookies)
        }
        return result
    }

    private func reviewURL(from data: Data) -> URL {
        guard let body = try? JSONDecoder().decode(ReviewBody.self, from: data),
              let path = body.reviewUrl,
              let url = AiTutorCallEndpoints.sameOriginURL(path, baseURL: baseURL) else {
            return endpoints.reviewURL
        }
        return url
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AiTutorCallAPIError.invalidResponse
        }
    }

    private static func cookies(from response: HTTPURLResponse, url: URL) -> [HTTPCookie] {
        var fields: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                fields[key] = value
            }
        }
        return HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
    }

    static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [ .withInternetDateTime, .withFractionalSeconds ]
        return formatter.date(from: value)
    }

    private struct JoinBody: Decodable {
        let status: String?
        let deadlineAt: String?
        let livekit: AiTutorLiveKitCredentials?

        enum CodingKeys: String, CodingKey {
            case status
            case deadlineAt = "deadline_at"
            case livekit
        }
    }

    private struct ReviewBody: Decodable {
        let reviewUrl: String?

        enum CodingKeys: String, CodingKey {
            case reviewUrl = "review_url"
        }
    }
}

/// Picks the cookies a browser would send for `url` (RFC 6265 domain, path,
/// secure and expiry matching).
enum AiTutorCookieMatcher {
    static func cookies(_ cookies: [HTTPCookie], for url: URL, now: Date = Date()) -> [HTTPCookie] {
        guard let host = url.host?.lowercased() else { return [] }
        let path = url.path.isEmpty ? "/" : url.path
        let isSecure = url.scheme?.lowercased() == "https"

        return cookies.filter { cookie in
            if cookie.isSecure && !isSecure { return false }
            if let expiresDate = cookie.expiresDate, expiresDate <= now { return false }
            return domainMatches(cookie.domain.lowercased(), host: host)
                && pathMatches(cookie.path, requestPath: path)
        }
    }

    private static func domainMatches(_ domain: String, host: String) -> Bool {
        if domain.hasPrefix(".") {
            let bare = String(domain.dropFirst())
            return host == bare || host.hasSuffix(domain)
        }
        return host == domain
    }

    private static func pathMatches(_ cookiePath: String, requestPath: String) -> Bool {
        let cookiePath = cookiePath.isEmpty ? "/" : cookiePath
        guard requestPath.hasPrefix(cookiePath) else { return false }
        if requestPath.count == cookiePath.count || cookiePath.hasSuffix("/") { return true }
        let index = requestPath.index(requestPath.startIndex, offsetBy: cookiePath.count)
        return requestPath[index] == "/"
    }
}

/// Reads and writes the default `WKWebsiteDataStore`, which is where the
/// Hotwire Navigator's web views keep the Rails session cookie.
@MainActor
final class WebViewCookieStore: AiTutorCookieStore {
    private let cookieStore: WKHTTPCookieStore

    init(cookieStore: WKHTTPCookieStore? = nil) {
        self.cookieStore = cookieStore ?? WKWebsiteDataStore.default().httpCookieStore
    }

    func cookies(for url: URL) async -> [HTTPCookie] {
        let all = await cookieStore.allCookies()
        return AiTutorCookieMatcher.cookies(all, for: url)
    }

    func store(_ cookies: [HTTPCookie]) async {
        for cookie in cookies {
            await cookieStore.setCookie(cookie)
        }
    }
}

/// Cookie-less URLSession transport: cookies are attached explicitly from the
/// web view store, and redirects (e.g. to the sign-in page) surface as
/// rejections instead of being followed.
final class URLSessionAiTutorTransport: AiTutorHTTPTransport {
    private let session: URLSession
    private let redirectDelegate: NativeAuthRedirectRejectingDelegate

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 15
        let redirectDelegate = NativeAuthRedirectRejectingDelegate()
        self.session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
        self.redirectDelegate = redirectDelegate
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AiTutorCallAPIError.invalidResponse
        }
        return (data, httpResponse)
    }
}

final class SystemAiTutorClock: AiTutorClock {
    func now() -> Date { Date() }

    func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}
