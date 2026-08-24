import CryptoKit
import FirebaseCrashlytics
import Foundation

protocol PaymentCrashReporting {
    func setCustomValue(_ value: Any, forKey key: String) throws
    func log(_ message: String) throws
    func record(error: Error) throws
}

private final class FirebasePaymentCrashReporter: PaymentCrashReporting {
    private let crashlytics: Crashlytics

    init(crashlytics: Crashlytics = .crashlytics()) {
        self.crashlytics = crashlytics
    }

    func setCustomValue(_ value: Any, forKey key: String) throws {
        crashlytics.setCustomValue(value, forKey: key)
    }

    func log(_ message: String) throws {
        crashlytics.log(message)
    }

    func record(error: Error) throws {
        crashlytics.record(error: error)
    }
}

enum PaymentFailureKind: String {
    case none
    case configuration
    case sdkLoad = "sdk_load"
    case sdkRequest = "sdk_request"
    case attemptRefresh = "attempt_refresh"
    case nativeRequest = "native_request"
    case malformedIntent = "malformed_intent"
    case externalAppUnavailable = "external_app_unavailable"
    case externalAppSecurity = "external_app_security"
    case malformedCallback = "malformed_callback"
    case rendererTerminated = "renderer_terminated"

    var code: Int {
        switch self {
        case .none: 0
        case .configuration: 1
        case .sdkLoad: 2
        case .sdkRequest: 3
        case .attemptRefresh: 4
        case .nativeRequest: 5
        case .malformedIntent: 6
        case .externalAppUnavailable: 7
        case .externalAppSecurity: 8
        case .malformedCallback: 9
        case .rendererTerminated: 10
        }
    }
}

final class PaymentCrashContext {
    private let reporter: PaymentCrashReporting
    private let appSurface: String

    private(set) var isActive = false
    private var stage = "none"
    private var orderKind = "unknown"
    private var reference = "none"
    private var handoff = "none"
    private var failureKind = PaymentFailureKind.none

    init(reporter: PaymentCrashReporting, appSurface: String) {
        self.reporter = reporter
        self.appSurface = appSurface
    }

    func reset() {
        isActive = false
        stage = "none"
        orderKind = "unknown"
        reference = "none"
        handoff = "none"
        failureKind = .none
        applyKeys()
    }

    func track(
        stage stageValue: String?,
        orderKind orderKindValue: String?,
        paymentReference: String?,
        handoff handoffValue: String?,
        failureKind failureKindValue: String?,
        reportNonfatal: Bool
    ) {
        guard Self.allowedStages.contains(stageValue ?? "") else { return }
        guard let stageValue else { return }

        if stageValue == "flow_finished" {
            safeLog("payment:flow_finished")
            reset()
            return
        }

        isActive = true
        stage = stageValue
        if let orderKindValue, Self.allowedOrderKinds.contains(orderKindValue) {
            orderKind = orderKindValue
        } else {
            orderKind = "unknown"
        }
        if let paymentReference, !paymentReference.isEmpty {
            reference = hashReference(paymentReference)
        }
        if let handoffValue, Self.allowedHandoffs.contains(handoffValue) {
            handoff = handoffValue
        } else {
            handoff = "none"
        }
        failureKind = PaymentFailureKind(rawValue: failureKindValue ?? "") ?? .none
        applyKeys()
        safeLog("payment:\(stageValue)")

        if reportNonfatal, failureKind != .none {
            safeRecord(failureKind)
        }
    }

    func markExternalAppHandoff() {
        track(
            stage: "external_app_handoff",
            orderKind: orderKind,
            paymentReference: nil,
            handoff: "external_app",
            failureKind: PaymentFailureKind.none.rawValue,
            reportNonfatal: false
        )
    }

    func markCallbackReceived(paymentReference: String?) {
        track(
            stage: "callback_received",
            orderKind: orderKind,
            paymentReference: paymentReference,
            handoff: "native_callback",
            failureKind: PaymentFailureKind.none.rawValue,
            reportNonfatal: false
        )
    }

    func logRetryColdBoot() {
        guard isActive else { return }
        safeLog("payment:retry_cold_boot")
    }

    func reportTechnicalFailure(_ failure: PaymentFailureKind) {
        isActive = true
        failureKind = failure
        applyKeys()
        safeLog("payment_failure:\(failure.rawValue)")
        safeRecord(failure)
    }

    func reportNativeRequestFailure() {
        guard isActive else { return }
        reportTechnicalFailure(.nativeRequest)
    }

    func hashReference(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func applyKeys() {
        safeSet(appSurface, forKey: "app_surface")
        safeSet("ios", forKey: "native_platform")
        safeSet(isActive, forKey: "payment_flow_active")
        safeSet(stage, forKey: "payment_stage")
        safeSet(orderKind, forKey: "payment_order_kind")
        safeSet(reference, forKey: "payment_reference")
        safeSet(isActive ? "portone_inicis" : "none", forKey: "payment_provider")
        safeSet(handoff, forKey: "payment_handoff")
        safeSet(failureKind.rawValue, forKey: "payment_failure_kind")
    }

    private func safeSet(_ value: Any, forKey key: String) {
        bestEffort { try reporter.setCustomValue(value, forKey: key) }
    }

    private func safeLog(_ message: String) {
        bestEffort { try reporter.log(message) }
    }

    private func safeRecord(_ failure: PaymentFailureKind) {
        let error = NSError(
            domain: "com.nurio.payment",
            code: failure.code,
            userInfo: [NSLocalizedDescriptionKey: "payment_failure:\(failure.rawValue)"]
        )
        bestEffort { try reporter.record(error: error) }
    }

    private func bestEffort(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            // Crash reporting is optional and must never affect payment behavior.
        }
    }

    private static let allowedStages: Set<String> = [
        "checkout_presented",
        "sdk_ready",
        "payment_requested",
        "attempt_refreshed",
        "gateway_handoff",
        "external_app_handoff",
        "callback_received",
        "completion_verifying",
        "retry_cold_boot",
        "flow_finished",
    ]

    private static let allowedOrderKinds: Set<String> = [
        "ticket",
        "pass_package",
        "deposit",
        "study_group",
        "event_add_on",
        "unknown",
    ]

    private static let allowedHandoffs: Set<String> = [
        "webview",
        "external_app",
        "native_callback",
        "none",
    ]
}

enum PaymentCrashTelemetry {
    private static var context: PaymentCrashContext?

    static func configure(appSurface: String) {
        let configuredContext = PaymentCrashContext(
            reporter: FirebasePaymentCrashReporter(),
            appSurface: appSurface
        )
        context = configuredContext
        configuredContext.reset()
    }

    static func track(
        stage: String?,
        orderKind: String?,
        paymentReference: String?,
        handoff: String?,
        failureKind: String?,
        reportNonfatal: Bool
    ) {
        context?.track(
            stage: stage,
            orderKind: orderKind,
            paymentReference: paymentReference,
            handoff: handoff,
            failureKind: failureKind,
            reportNonfatal: reportNonfatal
        )
    }

    static func markExternalAppHandoff() {
        context?.markExternalAppHandoff()
    }

    static func markCallbackReceived(paymentReference: String?) {
        context?.markCallbackReceived(paymentReference: paymentReference)
    }

    static func logRetryColdBoot() {
        context?.logRetryColdBoot()
    }

    static func reportTechnicalFailure(_ failure: PaymentFailureKind) {
        context?.reportTechnicalFailure(failure)
    }

    static func reportNativeRequestFailure() {
        context?.reportNativeRequestFailure()
    }
}
