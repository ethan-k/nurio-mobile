import AVFoundation
import LiveKit
import UIKit

enum AiTutorCallStatus: String, CaseIterable {
    case microphone
    case provisioning
    case connecting
    case waiting
    case live
    case reconnecting
    case ending
    case error
    case microphoneDenied = "microphone_denied"

    var localizationKey: String { "ai_tutor_call_status_\(rawValue)" }

    var localizedText: String {
        NSLocalizedString(localizationKey, comment: "")
    }
}

enum AiTutorCallCountdown {
    /// Remaining call time as `m:ss`, clamped at zero.
    static func format(remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

@MainActor
final class AiTutorLiveCallLauncher: AiTutorCallLaunching {
    func launch(
        endpoints: AiTutorCallEndpoints,
        presenter: UIViewController,
        onFinished: @escaping @MainActor () -> Void
    ) -> AnyObject {
        let api = AiTutorCallAPI(
            endpoints: endpoints,
            baseURL: AppEnvironment.baseURL,
            transport: URLSessionAiTutorTransport(),
            cookieStore: WebViewCookieStore(),
            clock: SystemAiTutorClock()
        )
        let call = AiTutorLiveCall(api: api, onFinished: onFinished)
        call.start(presenter: presenter)
        return call
    }
}

/// One class review voice call: microphone permission, join polling, the
/// LiveKit room, audio session, countdown, and the hand-back to the Rails
/// review page. Owned by `AiTutorCallCoordinator`, not by any view.
@MainActor
final class AiTutorLiveCall {
    private let api: AiTutorCallAPI
    private let onFinished: @MainActor () -> Void
    private let room: Room
    private var relay: AiTutorRoomEventRelay?
    private var viewController: AiTutorCallViewController?
    private var runTask: Task<Void, Never>?
    private var countdownTimer: Timer?
    private var deadline: Date?
    private var status: AiTutorCallStatus = .microphone
    private var isConnected = false
    private var isMuted = false
    private var isEnding = false
    private var isFinished = false
    private var isAudioSessionActive = false

    init(api: AiTutorCallAPI, onFinished: @escaping @MainActor () -> Void) {
        self.api = api
        self.onFinished = onFinished
        self.room = Room()
    }

    func start(presenter: UIViewController) {
        let viewController = AiTutorCallViewController(topic: api.endpoints.topic)
        viewController.onMuteTapped = { [weak self] in self?.toggleMute() }
        viewController.onEndTapped = { [weak self] in self?.end() }
        self.viewController = viewController

        Self.topmost(from: presenter).present(viewController, animated: true)
        UIApplication.shared.isIdleTimerDisabled = true

        let relay = AiTutorRoomEventRelay { [weak self] event in
            self?.handle(event)
        }
        self.relay = relay
        room.add(delegate: relay)

        update(.microphone)
        runTask = Task { [weak self] in
            await self?.run()
        }
    }

    // MARK: - Flow

    private func run() async {
        switch await Self.requestMicrophoneAccess() {
        case .granted:
            break
        case .denied:
            handleMicrophoneUnavailable(showSettingsRecovery: true)
            return
        case .restricted:
            handleMicrophoneUnavailable(showSettingsRecovery: false)
            return
        }

        guard !isEnding else { return }
        update(.provisioning)

        let outcome: AiTutorJoinOutcome
        do {
            outcome = try await api.join()
        } catch {
            guard !isEnding else { return }
            NSLog("Nurio Study AI tutor join failed: \(error)")
            update(.error)
            return
        }

        guard !isEnding else { return }

        switch outcome {
        case let .ended(reviewURL):
            isEnding = true
            update(.ending)
            finish(reviewURL: reviewURL)
        case let .ready(credentials, deadline):
            if let deadline { startCountdown(until: deadline) }
            await connect(with: credentials)
        }
    }

    private func connect(with credentials: AiTutorLiveKitCredentials) async {
        update(.connecting)

        do {
            try activateAudioSession()
            try await room.connect(url: credentials.url, token: credentials.participantToken)
            guard !isEnding else { return }
            isConnected = true
            _ = try await room.localParticipant.setMicrophone(enabled: !isMuted)
            guard !isEnding else { return }
            viewController?.setMuteEnabled(true)
            update(isAgentPresent ? .live : .waiting)
        } catch {
            guard !isEnding else { return }
            NSLog("Nurio Study AI tutor room connect failed: \(error)")
            if isConnected {
                end()
            } else {
                deactivateAudioSession()
                update(.error)
            }
        }
    }

    func end() {
        guard !isEnding else { return }
        isEnding = true
        runTask?.cancel()
        stopCountdown()
        update(.ending)
        viewController?.setControlsEnabled(false)

        Task { [weak self] in
            guard let self else { return }
            await self.room.localParticipant.unpublishAll()
            await self.room.disconnect()
            self.deactivateAudioSession()
            let reviewURL = await self.api.end()
            self.finish(reviewURL: reviewURL)
        }
    }

    private func handleMicrophoneUnavailable(showSettingsRecovery: Bool) {
        isEnding = true
        stopCountdown()
        update(.microphoneDenied)
        viewController?.setControlsEnabled(false)

        let endSession: @MainActor () -> Void = { [weak self] in
            Task { [weak self] in
                guard let self else { return }
                let reviewURL = await self.api.end()
                self.finish(reviewURL: reviewURL)
            }
        }

        guard showSettingsRecovery, let viewController else {
            endSession()
            return
        }
        viewController.presentMicrophoneSettingsRecovery(onDismiss: endSession)
    }

    private func finish(reviewURL: URL) {
        guard !isFinished else { return }
        isFinished = true
        stopCountdown()
        deactivateAudioSession()
        if let relay { room.remove(delegate: relay) }
        UIApplication.shared.isIdleTimerDisabled = false

        let complete: @MainActor () -> Void = { [onFinished] in
            AppRouteCoordinator.shared.replaceCurrentVisit(with: reviewURL)
            onFinished()
        }

        if let viewController, viewController.presentingViewController != nil {
            self.viewController = nil
            viewController.dismiss(animated: true) { complete() }
        } else {
            viewController = nil
            complete()
        }
    }

    // MARK: - Controls

    private func toggleMute() {
        guard isConnected, !isEnding else { return }
        isMuted.toggle()
        viewController?.setMuted(isMuted)
        let enabled = !isMuted

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.room.localParticipant.setMicrophone(enabled: enabled)
            } catch {
                NSLog("Nurio Study AI tutor mute toggle failed: \(error)")
                self.isMuted = !enabled
                self.viewController?.setMuted(self.isMuted)
            }
        }
    }

    // MARK: - Room events

    private var isAgentPresent: Bool {
        room.remoteParticipants.values.contains { $0.kind == .agent }
    }

    private func handle(_ event: AiTutorRoomEventRelay.Event) {
        guard !isEnding else { return }

        switch event {
        case .agentJoined:
            if isConnected, status != .reconnecting { update(.live) }
        case .agentLeft:
            if isConnected, status == .live, !isAgentPresent { update(.waiting) }
        case .reconnecting:
            if isConnected { update(.reconnecting) }
        case .reconnected:
            if isConnected { update(isAgentPresent ? .live : .waiting) }
        case .disconnected:
            if isConnected { end() }
        }
    }

    // MARK: - Countdown

    private func startCountdown(until deadline: Date) {
        self.deadline = deadline
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        tick()
    }

    private func tick() {
        guard let deadline else { return }
        let remaining = deadline.timeIntervalSinceNow
        viewController?.setCountdown(AiTutorCallCountdown.format(remaining: remaining))
        if remaining <= 0 { end() }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Audio

    private func activateAudioSession() throws {
        AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: Self.audioSessionOptions)
        try session.setActive(true)
        isAudioSessionActive = true
    }

    private func deactivateAudioSession() {
        guard isAudioSessionActive else { return }
        isAudioSessionActive = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("Nurio Study AI tutor audio session deactivation failed: \(error)")
        }
    }

    static var audioSessionOptions: AVAudioSession.CategoryOptions {
#if compiler(>=6.2)
        [ .defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP ]
#else
        [ .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP ]
#endif
    }

    private enum MicrophoneAccess {
        case granted
        case denied
        case restricted
    }

    private static func requestMicrophoneAccess() async -> MicrophoneAccess {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio) ? .granted : .denied
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    // MARK: - Helpers

    private func update(_ status: AiTutorCallStatus) {
        self.status = status
        viewController?.setStatus(status.localizedText)
    }

    private static func topmost(from presenter: UIViewController) -> UIViewController {
        var top = presenter
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// Forwards the LiveKit room events the call screen cares about to the main
/// actor. LiveKit holds delegates weakly, so `AiTutorLiveCall` retains it.
final class AiTutorRoomEventRelay: NSObject, RoomDelegate, @unchecked Sendable {
    enum Event {
        case agentJoined
        case agentLeft
        case reconnecting
        case reconnected
        case disconnected
    }

    private let handler: @MainActor (Event) -> Void

    init(handler: @escaping @MainActor (Event) -> Void) {
        self.handler = handler
    }

    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        if participant.kind == .agent { emit(.agentJoined) }
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        if participant.kind == .agent { emit(.agentLeft) }
    }

    func room(_ room: Room, didStartReconnectWithMode reconnectMode: ReconnectMode) {
        emit(.reconnecting)
    }

    func room(_ room: Room, didCompleteReconnectWithMode reconnectMode: ReconnectMode) {
        emit(.reconnected)
    }

    func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        emit(.disconnected)
    }

    private func emit(_ event: Event) {
        let handler = handler
        Task { @MainActor in handler(event) }
    }
}
