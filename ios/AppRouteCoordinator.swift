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
        if NativePaymentCallback.isCallbackURL(url) {
            let paymentID = NativePaymentCallback.paymentID(from: url)
            PaymentCrashTelemetry.markCallbackReceived(paymentReference: paymentID)
            if paymentID == nil {
                PaymentCrashTelemetry.reportTechnicalFailure(.malformedCallback)
            }
        }

        guard let destination = Self.destinationURL(for: url, baseURL: AppEnvironment.baseURL) else { return }
        route(destination)
    }

    nonisolated static func destinationURL(for url: URL, baseURL: URL) -> URL? {
        if NativeAppOpenURL.isAppOpenURL(url) {
            return NativeAppOpenURL.webURL(from: url, baseURL: baseURL) ?? AppEnvironment.eventsURL(for: baseURL)
        }

        if let paymentCompleteURL = NativePaymentCallback.completeURL(from: url, baseURL: baseURL) {
            return paymentCompleteURL
        }

        if let tokenAuthURL = NativeAuthCallback.tokenAuthURL(from: url, baseURL: baseURL) {
            return tokenAuthURL
        }

        if let webURL = NativeAppOpenURL.webURL(from: url, baseURL: baseURL) {
            return webURL
        }

        if NativeAppOpenURL.isBlockedWebURL(url, baseURL: baseURL) {
            return AppEnvironment.eventsURL(for: baseURL)
        }

        // Payment apps use the bare app scheme to resume the existing gateway.
        // Sending it back to the system navigator opens Nurio again in a loop.
        // Unknown/malformed URLs for our own scheme must never be re-opened either.
        guard url.scheme?.lowercased() != AppEnvironment.callbackScheme else { return nil }
        return url
    }

    private func route(_ url: URL) {
        guard let navigationHandler else {
            authLogger.error("AppRouteCoordinator missing navigation handler")
            return
        }
        if let navigator = navigationHandler as? Navigator {
            PaymentGatewayPresentation.shared.routeAppReturn(url, navigator: navigator)
        } else {
            navigationHandler.route(url)
        }
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
