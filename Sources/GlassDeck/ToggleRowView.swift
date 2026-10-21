import AppKit

/// A single row in the deck: a glass capsule containing an SF Symbol,
/// a title, and a glass toggle switch.
final class ToggleRowView: NSView {

    private let toggle: Toggle
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let toggleSwitch = NSSwitch()

    /// Called after the switch changed, for anything the row cannot do itself.
    var onToggle: (() -> Void)?

    /// Called when the system refused to reach the requested state.
    var onFailure: ((String) -> Void)?

    /// The last state the user asked for. Only touched on the main thread.
    private var intent: Bool?
    private var reconcileGeneration = 0

    init(toggle: Toggle) {
        self.toggle = toggle
        super.init(frame: .zero)

        wantsLayer = true

        // Icon
        if let img = NSImage(systemSymbolName: toggle.symbol, accessibilityDescription: toggle.title) {
            iconView.image = img
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            iconView.contentTintColor = .controlAccentColor
        }

        // Title
        titleLabel.stringValue = toggle.title
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        // Switch
        toggleSwitch.target = self
        toggleSwitch.action = #selector(switchChanged(_:))
        toggleSwitch.controlSize = .small
        // Start neutral; the real state arrives asynchronously via `applyState`.
        toggleSwitch.state = .off

        let stack = NSStackView(views: [iconView, titleLabel, toggleSwitch])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setHuggingPriority(.defaultLow, for: .horizontal)

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Read the current state (may shell out; call off the main thread).
    func currentToggleState() -> Bool {
        toggle.currentState()
    }

    /// Apply a previously-read state to the UI (call on the main thread).
    func applyState(_ state: Bool) {
        // Don't stomp on a change the user just made.
        guard intent == nil else { return }
        toggleSwitch.state = state ? .on : .off
    }

    @objc private func switchChanged(_ sender: NSSwitch) {
        let desired = sender.state == .on
        intent = desired
        reconcileGeneration += 1
        let generation = reconcileGeneration

        // The switch already shows the new position — that is the optimistic
        // part. Dim it slightly so it reads as "working on it".
        toggleSwitch.alphaValue = 0.55

        toggle.setState(desired)
        onToggle?()

        reconcile(desired: desired, generation: generation, attempt: 0)
    }

    /// Some changes only land after Finder/Dock/System Events finishes
    /// restarting, which can take a couple of seconds. Earlier versions read the
    /// state back after a fixed 0.15s and immediately reverted the switch when
    /// it had not landed yet — which made most toggles look broken. Now we poll
    /// for up to ~2.5s and only fall back to the real state at the very end.
    private func reconcile(desired: Bool, generation: Int, attempt: Int) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            let actual = self.toggle.currentState()
            DispatchQueue.main.async {
                // The user flipped it again — this round is stale.
                guard self.reconcileGeneration == generation else { return }

                if actual == desired || attempt >= 7 {
                    self.intent = nil
                    self.toggleSwitch.alphaValue = 1
                    self.toggleSwitch.state = actual ? .on : .off
                    if actual != desired {
                        self.onFailure?(self.toggle.title)
                    }
                } else {
                    self.reconcile(desired: desired, generation: generation, attempt: attempt + 1)
                }
            }
        }
    }
}
