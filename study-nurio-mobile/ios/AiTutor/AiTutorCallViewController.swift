import UIKit

/// Full-screen class review call screen. Purely presentational: every action
/// is forwarded to `AiTutorLiveCall`, which owns the call lifecycle.
@MainActor
final class AiTutorCallViewController: UIViewController {
    var onMuteTapped: (() -> Void)?
    var onEndTapped: (() -> Void)?

    private let topic: String
    private let titleLabel = UILabel()
    private let topicLabel = UILabel()
    private let statusLabel = UILabel()
    private let countdownLabel = UILabel()
    private let muteButton = UIButton(type: .system)
    private let endButton = UIButton(type: .system)
    private var isMuted = false
    private var isPresentingSettingsRecovery = false

    init(topic: String) {
        self.topic = topic
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.09, green: 0.13, blue: 0.20, alpha: 1)
        configureLabels()
        configureButtons()
        layout()
        setMuteEnabled(false)
    }

    // MARK: - Updates from the call

    func setStatus(_ text: String) {
        loadViewIfNeeded()
        statusLabel.text = text
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    func setCountdown(_ text: String) {
        loadViewIfNeeded()
        countdownLabel.text = text
        countdownLabel.accessibilityLabel = String(
            format: NSLocalizedString("ai_tutor_call_remaining_accessibility", comment: ""),
            text
        )
    }

    func setMuted(_ muted: Bool) {
        loadViewIfNeeded()
        isMuted = muted
        muteButton.setTitle(
            NSLocalizedString(muted ? "ai_tutor_call_unmute" : "ai_tutor_call_mute", comment: ""),
            for: .normal
        )
        muteButton.accessibilityTraits = muted ? [ .button, .selected ] : .button
    }

    func setMuteEnabled(_ enabled: Bool) {
        loadViewIfNeeded()
        muteButton.isEnabled = enabled
        muteButton.alpha = enabled ? 1 : 0.5
    }

    func setControlsEnabled(_ enabled: Bool) {
        loadViewIfNeeded()
        setMuteEnabled(enabled)
        endButton.isEnabled = enabled
        endButton.alpha = enabled ? 1 : 0.5
    }

    /// Same Settings recovery prompt the web call path uses
    /// (`SceneController.presentMicrophoneSettingsRecovery`).
    func presentMicrophoneSettingsRecovery(onDismiss: @escaping @MainActor () -> Void) {
        guard !isPresentingSettingsRecovery else { return }
        isPresentingSettingsRecovery = true

        let alert = UIAlertController(
            title: NSLocalizedString("microphone_permission_settings_title", comment: ""),
            message: NSLocalizedString("microphone_permission_settings_message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: NSLocalizedString("microphone_permission_settings_cancel", comment: ""),
                style: .cancel
            ) { [weak self] _ in
                self?.isPresentingSettingsRecovery = false
                onDismiss()
            }
        )
        alert.addAction(
            UIAlertAction(
                title: NSLocalizedString("microphone_permission_settings_open", comment: ""),
                style: .default
            ) { [weak self] _ in
                self?.isPresentingSettingsRecovery = false
                if let settingsURL = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(settingsURL) {
                    UIApplication.shared.open(settingsURL)
                }
                onDismiss()
            }
        )

        presentWhenVisible(alert, remainingAttempts: 10, onFailure: onDismiss)
    }

    /// The denial can arrive while this screen's own presentation animation is
    /// still running; wait for it to settle instead of dropping the alert.
    private func presentWhenVisible(
        _ alert: UIAlertController,
        remainingAttempts: Int,
        onFailure: @escaping @MainActor () -> Void
    ) {
        if viewIfLoaded?.window != nil, !isBeingPresented, presentedViewController == nil {
            present(alert, animated: true)
            return
        }

        guard remainingAttempts > 0 else {
            isPresentingSettingsRecovery = false
            onFailure()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.presentWhenVisible(alert, remainingAttempts: remainingAttempts - 1, onFailure: onFailure)
        }
    }

    // MARK: - Layout

    private func configureLabels() {
        titleLabel.text = NSLocalizedString("ai_tutor_call_title", comment: "")
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = UIColor(white: 1, alpha: 0.7)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        topicLabel.text = topic.isEmpty ? NSLocalizedString("ai_tutor_call_title", comment: "") : topic
        topicLabel.font = UIFontMetrics(forTextStyle: .title1)
            .scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
        topicLabel.textColor = .white
        topicLabel.textAlignment = .center
        topicLabel.numberOfLines = 0
        topicLabel.adjustsFontForContentSizeCategory = true
        topicLabel.accessibilityTraits = .header

        countdownLabel.text = "--:--"
        countdownLabel.font = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: .monospacedDigitSystemFont(ofSize: 44, weight: .semibold))
        countdownLabel.textColor = .white
        countdownLabel.textAlignment = .center
        countdownLabel.adjustsFontForContentSizeCategory = true

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = UIColor(white: 1, alpha: 0.85)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true
    }

    private func configureButtons() {
        style(muteButton, background: UIColor(white: 1, alpha: 0.16))
        setMuted(false)
        muteButton.addAction(UIAction { [weak self] _ in self?.onMuteTapped?() }, for: .touchUpInside)

        style(endButton, background: UIColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 1))
        endButton.setTitle(NSLocalizedString("ai_tutor_call_end", comment: ""), for: .normal)
        endButton.addAction(UIAction { [weak self] _ in self?.onEndTapped?() }, for: .touchUpInside)
    }

    private func style(_ button: UIButton, background: UIColor) {
        button.backgroundColor = background
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor(white: 1, alpha: 0.6), for: .disabled)
        button.titleLabel?.font = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.layer.cornerRadius = 28
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
    }

    private func layout() {
        let header = UIStackView(arrangedSubviews: [ titleLabel, topicLabel ])
        header.axis = .vertical
        header.spacing = 8

        let center = UIStackView(arrangedSubviews: [ countdownLabel, statusLabel ])
        center.axis = .vertical
        center.spacing = 16

        let buttons = UIStackView(arrangedSubviews: [ muteButton, endButton ])
        buttons.axis = .horizontal
        buttons.spacing = 16
        buttons.distribution = .fillEqually

        let content = UIStackView(arrangedSubviews: [ header, center, buttons ])
        content.axis = .vertical
        content.distribution = .equalSpacing
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: guide.topAnchor, constant: 32),
            content.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
        ])
    }
}
