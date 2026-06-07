import Foundation
import HotwireNative
import OSLog

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "auth"
)

@MainActor
final class AppRouteCoordinator {
    static let shared = AppRouteCoordinator()

    weak var navigationHandler: NavigationHandler?

    private init() {}

    func handleIncoming(_ url: URL) {
        if NativeAppOpenURL.isAppOpenURL(url) {
            route(NativeAppOpenURL.webURL(from: url, baseURL: AppEnvironment.baseURL) ?? AppEnvironment.startURL)
            return
        }

        if let paymentCompleteURL = NativePaymentCallback.completeURL(from: url, baseURL: AppEnvironment.baseURL) {
            route(paymentCompleteURL)
            return
        }

        if let tokenAuthURL = NativeAuthCallback.tokenAuthURL(from: url, baseURL: AppEnvironment.baseURL) {
            route(tokenAuthURL)
            return
        }

        if let webURL = NativeAppOpenURL.webURL(from: url, baseURL: AppEnvironment.baseURL) {
            route(webURL)
            return
        }

        if NativeAppOpenURL.isBlockedWebURL(url, baseURL: AppEnvironment.baseURL) {
            route(AppEnvironment.startURL)
            return
        }

        route(url)
    }

    private func route(_ url: URL) {
        guard let navigationHandler else {
            authLogger.error("AppRouteCoordinator missing navigation handler")
            return
        }
        navigationHandler.route(url)
    }
}

enum NativeAppOpenURL {
    static func isAppOpenURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == AppEnvironment.callbackScheme && url.host?.lowercased() == "open"
    }

    static func webURL(from url: URL, baseURL: URL) -> URL? {
        if isAppOpenURL(url) {
            guard
                let rawTarget = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "url" })?
                    .value,
                let targetURL = URL(string: rawTarget)
            else {
                return baseURL.appendingPathComponent("events")
            }

            return normalizedWebURL(targetURL, baseURL: baseURL)
        }

        return normalizedWebURL(url, baseURL: baseURL)
    }

    static func isBlockedWebURL(_ url: URL, baseURL: URL) -> Bool {
        guard isRecognizedWebHost(url, baseURL: baseURL) else { return false }

        return CustomerScopePolicy.isBlocked(url, appHost: baseURL.host?.lowercased())
    }

    private static func normalizedWebURL(_ url: URL, baseURL: URL) -> URL? {
        guard isRecognizedWebHost(url, baseURL: baseURL) else { return nil }
        guard !CustomerScopePolicy.isBlocked(url, appHost: baseURL.host?.lowercased()) else { return nil }

        let baseHost = baseURL.host?.lowercased()
        if url.host?.lowercased() == "www.\(baseHost ?? "")" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = baseURL.scheme
            components?.host = baseHost
            return components?.url
        }

        return url
    }

    private static func isRecognizedWebHost(_ url: URL, baseURL: URL) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host?.lowercased(),
            let baseHost = baseURL.host?.lowercased()
        else {
            return false
        }

        return host == baseHost || host == "www.\(baseHost)"
    }
}
