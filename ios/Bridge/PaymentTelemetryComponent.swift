import HotwireNative

@MainActor
final class PaymentTelemetryComponent: BridgeComponent {
    override class var name: String { "payment-telemetry" }

    override func onReceive(message: Message) {
        guard message.event == "track" else { return }
        guard let data: TrackData = message.data() else { return }

        PaymentCrashTelemetry.track(
            stage: data.stage,
            orderKind: data.orderKind,
            paymentReference: data.paymentReference,
            handoff: data.handoff,
            failureKind: data.failureKind,
            reportNonfatal: data.reportNonfatal
        )
    }
}

private extension PaymentTelemetryComponent {
    struct TrackData: Decodable {
        let stage: String?
        let orderKind: String?
        let paymentReference: String?
        let handoff: String?
        let failureKind: String?
        let reportNonfatal: Bool
    }
}
