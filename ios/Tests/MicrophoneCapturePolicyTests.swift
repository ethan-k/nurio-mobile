import WebKit
import XCTest
@testable import Nurio

final class MicrophoneCapturePolicyTests: XCTestCase {
    private let baseURL = URL(string: "https://nurio.kr")!
    private let translatorURL = URL(string: "https://nurio.kr/events/42/first_spark/translator")!

    private func shouldGrant(
        type: WKMediaCaptureType = .microphone,
        originProtocol: String = "https",
        originHost: String = "nurio.kr",
        originPort: Int = 443,
        isMainFrame: Bool = true,
        frameURL: URL? = URL(string: "https://nurio.kr/events/42/first_spark/translator"),
        webViewURL: URL?,
        baseURL: URL? = nil
    ) -> Bool {
        MicrophoneCapturePolicy.shouldGrantMicrophoneCapture(
            type: type,
            originProtocol: originProtocol,
            originHost: originHost,
            originPort: originPort,
            isMainFrame: isMainFrame,
            frameURL: frameURL,
            webViewURL: webViewURL,
            baseURL: baseURL ?? self.baseURL
        )
    }

    func testGrantsMicrophoneOnTheFirstSparkTranslator() {
        [
            "https://nurio.kr/events/42/first_spark/translator",
            "https://nurio.kr/events/42/first_spark/translator/",
            "https://nurio.kr/events/7/first_spark/translator?lang=ko",
        ].forEach { location in
            XCTAssertTrue(shouldGrant(webViewURL: URL(string: location)!), location)
        }
        XCTAssertTrue(shouldGrant(originHost: "NURIO.KR", originPort: 0, frameURL: nil, webViewURL: translatorURL))
    }

    func testDeniesOtherPathsOnTheTrustedOrigin() {
        [
            "https://nurio.kr/",
            "https://nurio.kr/events/42",
            "https://nurio.kr/events/42/first_spark",
            "https://nurio.kr/events/42/first_spark/translator/turns",
            "https://nurio.kr/events/42/first_spark/translator/finish",
            "https://nurio.kr/events/abc/first_spark/translator",
            "https://nurio.kr/practice/42",
        ].forEach { location in
            XCTAssertFalse(shouldGrant(webViewURL: URL(string: location)!), location)
        }
        XCTAssertFalse(shouldGrant(webViewURL: nil))
    }

    func testDeniesHTTP() {
        XCTAssertFalse(shouldGrant(originProtocol: "http", originPort: 80, webViewURL: translatorURL))
        XCTAssertFalse(
            shouldGrant(webViewURL: URL(string: "http://nurio.kr/events/42/first_spark/translator")!)
        )

        let httpBaseURL = URL(string: "http://localhost:3000")!
        XCTAssertFalse(
            shouldGrant(
                originProtocol: "http",
                originHost: "localhost",
                originPort: 3000,
                frameURL: nil,
                webViewURL: URL(string: "http://localhost:3000/events/42/first_spark/translator")!,
                baseURL: httpBaseURL
            )
        )
    }

    func testDeniesIframeRequests() {
        XCTAssertFalse(shouldGrant(isMainFrame: false, webViewURL: translatorURL))
        XCTAssertFalse(
            shouldGrant(
                frameURL: URL(string: "https://evil.example/events/42/first_spark/translator")!,
                webViewURL: translatorURL
            )
        )
    }

    func testDeniesCameraCapture() {
        XCTAssertFalse(shouldGrant(type: .camera, webViewURL: translatorURL))
        XCTAssertFalse(shouldGrant(type: .cameraAndMicrophone, webViewURL: translatorURL))
    }

    func testDeniesUntrustedOrigins() {
        XCTAssertFalse(shouldGrant(originHost: "evil.example", webViewURL: translatorURL))
        XCTAssertFalse(shouldGrant(originPort: 8443, webViewURL: translatorURL))
        XCTAssertFalse(
            shouldGrant(webViewURL: URL(string: "https://evil.example/events/42/first_spark/translator")!)
        )
        XCTAssertFalse(
            shouldGrant(webViewURL: URL(string: "https://study.nurio.kr/events/42/first_spark/translator")!)
        )
    }

    func testDispositionGrantsOnlyAvailableTrustedRequests() {
        for permission in [MicrophoneCapturePolicy.SystemMicrophonePermission.authorized, .notDetermined] {
            XCTAssertEqual(
                MicrophoneCapturePolicy.microphoneCaptureDisposition(trustedRequest: true, systemPermission: permission),
                .init(grantsCapture: true, showsSettingsRecovery: false)
            )
        }
        XCTAssertEqual(
            MicrophoneCapturePolicy.microphoneCaptureDisposition(trustedRequest: true, systemPermission: .denied),
            .init(grantsCapture: false, showsSettingsRecovery: true)
        )
        XCTAssertEqual(
            MicrophoneCapturePolicy.microphoneCaptureDisposition(trustedRequest: true, systemPermission: .restricted),
            .init(grantsCapture: false, showsSettingsRecovery: false)
        )
    }

    func testUntrustedRequestsStaySilentAndClosed() {
        for permission in MicrophoneCapturePolicy.SystemMicrophonePermission.allCases {
            XCTAssertEqual(
                MicrophoneCapturePolicy.microphoneCaptureDisposition(trustedRequest: false, systemPermission: permission),
                .init(grantsCapture: false, showsSettingsRecovery: false)
            )
        }
    }

    func testSettingsRecoveryAllowsOnlyOneAlertAtATime() {
        let state = MicrophoneSettingsRecoveryState()

        XCTAssertTrue(state.beginPresentation())
        XCTAssertFalse(state.beginPresentation())
        state.finishPresentation()
        XCTAssertTrue(state.beginPresentation())
    }

    func testMicrophonePurposeStringIsDeclaredAndLocalized() throws {
        let expectedCopy = [
            "en": "nurio uses the microphone to translate what you say during First Spark conversations.",
            "ko": "퍼스트 스파크 대화 중 말한 내용을 번역하기 위해 마이크를 사용합니다.",
        ]

        let declared = try XCTUnwrap(Bundle.main.infoDictionary?["NSMicrophoneUsageDescription"] as? String)
        XCTAssertEqual(declared, expectedCopy["en"])

        for (localization, copy) in expectedCopy {
            let url = try XCTUnwrap(
                Bundle.main.url(
                    forResource: "InfoPlist",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: localization
                ),
                localization
            )
            let strings = try XCTUnwrap(NSDictionary(contentsOf: url))
            XCTAssertEqual(strings["NSMicrophoneUsageDescription"] as? String, copy)
        }
    }

    func testSettingsRecoveryCopyIsLocalizedInEnglishAndKorean() throws {
        let keys = [
            "microphone_permission_settings_title",
            "microphone_permission_settings_message",
            "microphone_permission_settings_cancel",
            "microphone_permission_settings_open",
        ]

        for localization in ["en", "ko"] {
            let url = try XCTUnwrap(
                Bundle.main.url(
                    forResource: "Localizable",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: localization
                ),
                localization
            )
            let strings = try XCTUnwrap(NSDictionary(contentsOf: url))
            for key in keys {
                XCTAssertFalse(((strings[key] as? String) ?? "").isEmpty, "\(localization): \(key)")
            }
        }
    }
}
