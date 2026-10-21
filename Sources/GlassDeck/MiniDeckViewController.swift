import AppKit
import ObjectiveC

/// The compact panel: four essential switches, no tabs, no scrolling.
/// Same glass, one quarter of the surface area.
final class MiniDeckViewController: NSViewController {

    private var handlers: [SwitchHandler] = []
    private var rows: [(NSSwitch, Toggle)] = []
    private var statusLabel: NSTextField!
    private var statusTimer: Timer?

    override func loadView() {
        let panel = GlassPanel()
        panel.glassCornerRadius = 26
        panel.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            panel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            panel.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            panel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
        ])
        self.view = root

        let inner = panel.contentView

        let title = NSTextField(labelWithString: L.t(.appName))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let expandButton = NSButton(image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right",
                                                  accessibilityDescription: L.t(.openFullDeck)) ?? NSImage(),
                                    target: nil, action: nil)
        expandButton.isBordered = false
        expandButton.bezelStyle = .accessoryBarAction
        expandButton.toolTip = L.t(.openFullDeck)
        let expandHandler = ActionHandler { [weak self] in self?.expand() }
        expandButton.target = expandHandler
        expandButton.action = #selector(ActionHandler.run)
        objc_setAssociatedObject(expandButton, "handler", expandHandler, .OBJC_ASSOCIATION_RETAIN)

        let header = NSStackView(views: [title, spacer, expandButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6

        let list = NSStackView()
        list.orientation = .vertical
        list.spacing = 6
        list.alignment = .leading

        for toggle in ToggleLibrary.compact {
            let row = makeRow(toggle)
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 2
        statusLabel.isHidden = true

        let footer = NSButton(title: L.t(.openFullDeck), target: nil, action: nil)
        footer.bezelStyle = .inline
        footer.isBordered = false
        footer.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        footer.contentTintColor = .controlAccentColor
        let footerHandler = ActionHandler { [weak self] in self?.expand() }
        footer.target = footerHandler
        footer.action = #selector(ActionHandler.run)
        objc_setAssociatedObject(footer, "handler", footerHandler, .OBJC_ASSOCIATION_RETAIN)

        let rootStack = NSStackView(views: [header, list, statusLabel, footer])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 10
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: 14),
            rootStack.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -14),
            rootStack.topAnchor.constraint(equalTo: inner.topAnchor, constant: 12),
            rootStack.bottomAnchor.constraint(equalTo: inner.bottomAnchor, constant: -12),
            header.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            list.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
        ])

        panel.startAmbientSheen()
    }

    private func makeRow(_ toggle: Toggle) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: toggle.symbol, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)

        let label = NSTextField(labelWithString: toggle.title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let toggleSwitch = NSSwitch()
        toggleSwitch.controlSize = .small
        // Never read system state here: that shells out to `defaults` /
        // `osascript` and would freeze the panel before it even drew.
        toggleSwitch.state = .off

        let handler = SwitchHandler(toggle, control: toggleSwitch)
        handler.onFailure = { [weak self] title in
            self?.showStatus("\(title)：\(L.t(.failed))")
        }
        toggleSwitch.target = handler
        toggleSwitch.action = #selector(SwitchHandler.changed(_:))
        handlers.append(handler)
        rows.append((toggleSwitch, toggle))

        let row = NSStackView(views: [icon, label, spacer, toggleSwitch])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    /// Re-read system state off the main thread, then apply it.
    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let states = self.rows.map { $0.1.currentState() }
            DispatchQueue.main.async {
                for (pair, state) in zip(self.rows, states) {
                    pair.0.state = state ? .on : .off
                }
            }
        }
    }

    private func showStatus(_ text: String) {
        statusLabel.stringValue = text
        statusLabel.isHidden = false
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            self?.statusLabel.isHidden = true
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refresh()
    }

    private func expand() {
        UserDefaults.standard.set(false, forKey: AppDelegate.compactModeKey)
        NotificationCenter.default.post(name: AppDelegate.compactModeChanged, object: nil)
    }
}

/// Bridges an NSSwitch action back to a `Toggle`, and — crucially — verifies
/// the change actually landed instead of trusting the switch position.
final class SwitchHandler: NSObject {
    private let toggle: Toggle
    private let control: NSSwitch

    /// Called when the switch could not reach the requested state.
    var onFailure: ((String) -> Void)?

    private var generation = 0

    init(_ toggle: Toggle, control: NSSwitch) {
        self.toggle = toggle
        self.control = control
    }

    @objc func changed(_ sender: NSSwitch) {
        let desired = sender.state == .on
        generation += 1
        let current = generation

        control.alphaValue = 0.55
        toggle.setState(desired)
        reconcile(desired: desired, generation: current, attempt: 0)
    }

    private func reconcile(desired: Bool, generation: Int, attempt: Int) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            let actual = self.toggle.currentState()
            DispatchQueue.main.async {
                guard self.generation == generation else { return }
                if actual == desired || attempt >= 7 {
                    self.control.alphaValue = 1
                    self.control.state = actual ? .on : .off
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
