import AVFoundation
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

        return LocalePath.stripLocalePrefix(path).range(of: translatorPathPattern, options: .regularExpression) != nil
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

    fileprivate static func hasTrustedHTTPSOrigin(_ url: URL, baseURL: URL) -> Bool {
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

enum CameraCapturePolicy {
    fileprivate static let confirmPathPattern = #"^/events/[0-9]+/human_bingo/confirm/?$"#

    static func shouldGrantCameraCapture(
        type: WKMediaCaptureType,
        originProtocol: String,
        originHost: String,
        originPort: Int,
        isMainFrame: Bool,
        frameURL: URL?,
        webViewURL: URL?,
        baseURL: URL
    ) -> Bool {
        guard type == .camera,
              isMainFrame,
              MicrophoneCapturePolicy.isTrustedMicrophoneOrigin(
                  protocol: originProtocol,
                  host: originHost,
                  port: originPort,
                  baseURL: baseURL
              ),
              let frameURL,
              let webViewURL else {
            return false
        }

        return isTrustedConfirmURL(frameURL, baseURL: baseURL)
            && isTrustedConfirmURL(webViewURL, baseURL: baseURL)
    }

    private static func isTrustedConfirmURL(_ url: URL, baseURL: URL) -> Bool {
        guard MicrophoneCapturePolicy.hasTrustedHTTPSOrigin(url, baseURL: baseURL),
              let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath else {
            return false
        }

        return LocalePath.stripLocalePrefix(path).range(of: confirmPathPattern, options: .regularExpression) != nil
    }

    enum Disposition {
        case grant
        case deny
        case denyAndShowSettings
    }

    static func disposition(for permission: AVAuthorizationStatus) -> Disposition {
        switch permission {
        case .authorized, .notDetermined:
            return .grant
        case .denied:
            return .denyAndShowSettings
        case .restricted:
            return .deny
        @unknown default:
            return .deny
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

final class CameraCaptureRecoveryMessageHandler: NSObject, WKScriptMessageHandler {
    private static let messageName = "nurioBingoCameraDenied"

    static func install(in controller: WKUserContentController) {
        controller.add(CameraCaptureRecoveryMessageHandler(), name: messageName)
        // WebKit can reject OS-denied camera requests before calling the UI delegate.
        controller.addUserScript(WKUserScript(
            source: #"""
            (() => {
                const devices = navigator.mediaDevices;
                if (!devices?.getUserMedia) return;
                const getUserMedia = devices.getUserMedia;
                const confirmPath = new RegExp("\#(CameraCapturePolicy.confirmPathPattern)");
                devices.getUserMedia = function (constraints) {
                    const request = getUserMedia.apply(this, arguments);
                    const path = location.pathname.replace(/^\/(?:en|ko)(?=\/)/i, "");
                    if (!constraints?.video || constraints.audio || !confirmPath.test(path)) {
                        return request;
                    }
                    return request.catch(error => {
                        if (error.name === "NotAllowedError") {
                            window.webkit.messageHandlers.\#(messageName).postMessage(null);
                        }
                        throw error;
                    });
                };
            })();
            """#,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName,
              let webView = message.webView,
              let delegate = webView.uiDelegate as? MicrophoneCaptureWKUIController else {
            return
        }

        delegate.recoverFromCameraDenial(in: webView, frame: message.frameInfo)
    }
}

/// Hotwire's UI controller with capture policies for First Spark and Human Bingo.
final class MicrophoneCaptureWKUIController: WKUIController {
    private let trustedBaseURL: URL
    private let microphonePermission: () -> MicrophoneCapturePolicy.SystemMicrophonePermission
    private let showMicrophoneSettingsRecovery: () -> Void
    private let showCameraSettingsRecovery: () -> Void

    init(
        delegate: WKUIControllerDelegate,
        trustedBaseURL: URL,
        microphonePermission: @escaping () -> MicrophoneCapturePolicy.SystemMicrophonePermission,
        showMicrophoneSettingsRecovery: @escaping () -> Void,
        showCameraSettingsRecovery: @escaping () -> Void
    ) {
        self.trustedBaseURL = trustedBaseURL
        self.microphonePermission = microphonePermission
        self.showMicrophoneSettingsRecovery = showMicrophoneSettingsRecovery
        self.showCameraSettingsRecovery = showCameraSettingsRecovery
        super.init(delegate: delegate)
    }

    fileprivate func recoverFromCameraDenial(in webView: WKWebView, frame: WKFrameInfo) {
        guard isTrustedCameraRequest(origin: frame.securityOrigin, frame: frame, webView: webView),
              AVCaptureDevice.authorizationStatus(for: .video) == .denied else {
            return
        }

        showCameraSettingsRecovery()
    }

    private func isTrustedCameraRequest(origin: WKSecurityOrigin, frame: WKFrameInfo, webView: WKWebView) -> Bool {
        CameraCapturePolicy.shouldGrantCameraCapture(
            type: .camera,
            originProtocol: origin.`protocol`,
            originHost: origin.host,
            originPort: origin.port,
            isMainFrame: frame.isMainFrame,
            frameURL: frame.request.url,
            webViewURL: webView.url,
            baseURL: trustedBaseURL
        )
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        if type == .camera {
            guard isTrustedCameraRequest(origin: origin, frame: frame, webView: webView) else {
                decisionHandler(.deny)
                return
            }

            let disposition = CameraCapturePolicy.disposition(for: AVCaptureDevice.authorizationStatus(for: .video))
            decisionHandler(disposition == .grant ? .grant : .deny)
            if disposition == .denyAndShowSettings {
                showCameraSettingsRecovery()
            }
            return
        }

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
