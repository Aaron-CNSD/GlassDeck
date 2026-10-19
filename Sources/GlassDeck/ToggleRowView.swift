import AppKit

/// A single row in the deck: a glass capsule containing an SF Symbol,
/// a title, and a glass toggle switch.
final class ToggleRowView: NSView {

    private let toggle: Toggle
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let toggleSwitch = NSSwitch()

    var onToggle: (() -> Void)?

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

        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Pull the latest state from the system and reflect it in the UI.
    func refresh() {
        toggleSwitch.state = toggle.currentState() ? .on : .off
    }

    /// Read the current state (may shell out; call off the main thread).
    func currentToggleState() -> Bool {
        toggle.currentState()
    }

    /// Apply a previously-read state to the UI (call on the main thread).
    func applyState(_ state: Bool) {
        toggleSwitch.state = state ? .on : .off
    }

    @objc private func switchChanged(_ sender: NSSwitch) {
        let newState = sender.state == .on
        // Apply the state synchronously so the switch feels instant.
        toggle.setState(newState)
        onToggle?()

        // Some system toggles take effect asynchronously (e.g. Finder, Dock).
        // Fire the sync on a background queue so it never blocks the UI thread,
        // then bounce back to the main thread to reflect the authoritative state.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Give the system a moment to settle, then read the real state.
            Thread.sleep(forTimeInterval: 0.15)
            let authoritative = self?.toggle.currentState() ?? newState
            DispatchQueue.main.async {
                self?.toggleSwitch.state = authoritative ? .on : .off
            }
        }
    }
}
