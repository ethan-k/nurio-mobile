import Foundation
import HotwireNative
import UIKit

/// WKWebView never surfaces the on-screen keyboard to the page: the visual
/// viewport keeps its full height and the keyboard simply draws over the
/// bottom of it, so fixed-to-viewport layouts (the event chat shell) cannot
/// know how far to lift their composer. This component measures how much of
/// the window the keyboard covers and replies to the page on every change;
/// the web side re-broadcasts each reply as a `native-keyboard:inset` window
/// event that layout controllers consume.
@MainActor
final class KeyboardInsetsComponent: BridgeComponent {
    override class var name: String { "keyboard-insets" }

    private var observers: [NSObjectProtocol] = []
    private var lastHeight: CGFloat = 0

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func onReceive(message: Message) {
        guard message.event == "connect" else { return }

        startObservingIfNeeded()
        reply(to: "connect", with: InsetPayload(height: lastHeight))
    }

    private func startObservingIfNeeded() {
        guard observers.isEmpty else { return }

        let names: [Notification.Name] = [
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardWillHideNotification,
        ]

        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let hidden = notification.name == UIResponder.keyboardWillHideNotification
                let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue

                Task { @MainActor in
                    self?.keyboardChanged(endFrame: endFrame, hidden: hidden)
                }
            }
        }
    }

    private func keyboardChanged(endFrame: CGRect?, hidden: Bool) {
        let height = hidden ? 0 : overlapHeight(of: endFrame)
        guard height != lastHeight else { return }

        lastHeight = height
        reply(to: "connect", with: InsetPayload(height: height))
    }

    /// The frame is intersected with the window rather than trusted outright:
    /// an undocked or floating iPad keyboard, or a frame animating offscreen,
    /// covers none of the window and must report zero.
    private func overlapHeight(of endFrame: CGRect?) -> CGFloat {
        guard let endFrame, let window else { return 0 }

        let frameInWindow = window.convert(endFrame, from: UIScreen.main.coordinateSpace)
        let overlap = window.bounds.intersection(frameInWindow)
        return overlap.isNull ? 0 : overlap.height
    }

    private var window: UIWindow? {
        (delegate?.destination as? UIViewController)?.viewIfLoaded?.window
    }
}

private extension KeyboardInsetsComponent {
    struct InsetPayload: Encodable {
        let height: CGFloat
    }
}
