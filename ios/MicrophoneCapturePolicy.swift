import Foundation
import HotwireNative
import WebKit

/// Decides which web pages may capture the microphone. Only the First Spark table
/// translator, loaded in the main frame of the configured https origin, qualifies.
enum MicrophoneCapturePolicy {
    private static let translatorPathPattern = #"^/events/[0-9]+/first_spark/translator/?$"#

    enum SystemMicrophonePermission: CaseIterable {
        case authorized
        case notDetermined
        case denied
        case restricted
    }

    struct MicrophoneCaptureDisposition: Equatable {
        let grantsCapture: Bool
        let showsSettingsRecovery: Bool
    }

    static func isTranslatorURL(_ url: URL) -> Bool {
        guard let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath else {
            return false
        }

        return path.range(of: translatorPathPattern, options: .regularExpression) != nil
    }

    static func isTrustedMicrophoneOrigin(
        protocol originProtocol: String,
        host: String,
        port: Int,
        baseURL: URL
    ) -> Bool {
        guard let requestedOrigin = Origin(
            scheme: originProtocol,
            host: host,
            port: port == 0 ? nil : port
        ), let trustedOrigin = Origin(url: baseURL) else {
            return false
        }

        return requestedOrigin == trustedOrigin && requestedOrigin.isHTTPS
    }

    static func shouldGrantMicrophoneCapture(
        type: WKMediaCaptureType,
        originProtocol: String,
        originHost: String,
        originPort: Int,
        isMainFrame: Bool,
        frameURL: URL?,
        webViewURL: URL?,
        baseURL: URL
    ) -> Bool {
        guard type == .microphone,
              isMainFrame,
              isTrustedMicrophoneOrigin(
                  protocol: originProtocol,
                  host: originHost,
                  port: originPort,
                  baseURL: baseURL
              ),
              let webViewURL,
              isTranslatorURL(webViewURL),
              hasTrustedHTTPSOrigin(webViewURL, baseURL: baseURL) else {
            return false
        }

        return frameURL.map { hasTrustedHTTPSOrigin($0, baseURL: baseURL) } ?? true
    }

    static func microphoneCaptureDisposition(
        trustedRequest: Bool,
        systemPermission: SystemMicrophonePermission
    ) -> MicrophoneCaptureDisposition {
        guard trustedRequest else {
            return MicrophoneCaptureDisposition(grantsCapture: false, showsSettingsRecovery: false)
        }

        switch systemPermission {
        case .authorized, .notDetermined:
            return MicrophoneCaptureDisposition(grantsCapture: true, showsSettingsRecovery: false)
        case .denied:
            return MicrophoneCaptureDisposition(grantsCapture: false, showsSettingsRecovery: true)
        case .restricted:
            return MicrophoneCaptureDisposition(grantsCapture: false, showsSettingsRecovery: false)
        }
    }

    private static func hasTrustedHTTPSOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard let requestedOrigin = Origin(url: url),
              let trustedOrigin = Origin(url: baseURL) else {
            return false
        }

        return requestedOrigin == trustedOrigin && requestedOrigin.isHTTPS
    }

    private struct Origin: Equatable {
        let scheme: String
        let host: String
        let port: Int?

        var isHTTPS: Bool { scheme == "https" }

        init?(url: URL) {
            guard url.user == nil, url.password == nil, let scheme = url.scheme, let host = url.host else {
                return nil
            }
            self.init(scheme: scheme, host: host, port: url.port)
        }

        init?(scheme: String, host: String, port: Int?) {
            let normalizedScheme = scheme.lowercased()
            let normalizedHost = host.lowercased()
            guard !normalizedScheme.isEmpty, !normalizedHost.isEmpty else { return nil }

            self.scheme = normalizedScheme
            self.host = normalizedHost
            self.port = Self.isDefaultPort(port, scheme: normalizedScheme) ? nil : port
        }

        private static func isDefaultPort(_ port: Int?, scheme: String) -> Bool {
            (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
        }
    }
}

final class MicrophoneSettingsRecoveryState {
    private(set) var isPresenting = false

    func beginPresentation() -> Bool {
        guard !isPresenting else { return false }
        isPresenting = true
        return true
    }

    func finishPresentation() {
        isPresenting = false
    }
}

/// Hotwire's UI controller plus a microphone capture decision for the First Spark translator.
final class MicrophoneCaptureWKUIController: WKUIController {
    private let trustedBaseURL: URL
    private let microphonePermission: () -> MicrophoneCapturePolicy.SystemMicrophonePermission
    private let showMicrophoneSettingsRecovery: () -> Void

    init(
        delegate: WKUIControllerDelegate,
        trustedBaseURL: URL,
        microphonePermission: @escaping () -> MicrophoneCapturePolicy.SystemMicrophonePermission,
        showMicrophoneSettingsRecovery: @escaping () -> Void
    ) {
        self.trustedBaseURL = trustedBaseURL
        self.microphonePermission = microphonePermission
        self.showMicrophoneSettingsRecovery = showMicrophoneSettingsRecovery
        super.init(delegate: delegate)
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let trustedRequest = MicrophoneCapturePolicy.shouldGrantMicrophoneCapture(
            type: type,
            originProtocol: origin.`protocol`,
            originHost: origin.host,
            originPort: origin.port,
            isMainFrame: frame.isMainFrame,
            frameURL: frame.request.url,
            webViewURL: webView.url,
            baseURL: trustedBaseURL
        )
        let systemPermission = trustedRequest ? microphonePermission() : .restricted
        let disposition = MicrophoneCapturePolicy.microphoneCaptureDisposition(
            trustedRequest: trustedRequest,
            systemPermission: systemPermission
        )

        decisionHandler(disposition.grantsCapture ? .grant : .deny)
        if disposition.showsSettingsRecovery {
            showMicrophoneSettingsRecovery()
        }
    }
}
