import AppKit
import ObjectiveC

/// The main control deck: a Liquid Glass panel with segmented tabs,
/// each holding a category of controls.
final class DeckViewController: NSViewController {

    private enum Tab: Int, CaseIterable {
        case toggles, monitor, windows, cleaner, tools, launch
        var title: String {
            switch self {
            case .toggles: return L.t(.tabSwitches)
            case .monitor: return L.t(.tabMonitor)
            case .windows: return L.t(.tabWindows)
            case .cleaner: return L.t(.tabCleaner)
            case .tools: return L.t(.tabTools)
            case .launch: return L.t(.tabLaunch)
            }
        }
        var symbol: String {
            switch self {
            case .toggles: return "switch.2"
            case .monitor: return "gauge"
            case .windows: return "macwindow"
            case .cleaner: return "trash"
            case .tools: return "wrench.and.screwdriver"
            case .launch: return "bolt"
            }
        }
    }

    private var currentTab: Tab = .toggles
    private var segmented: NSSegmentedControl!
    private var contentContainer: NSView!
    private var contentViews: [Tab: NSView] = [:]
    private var monitorTimer: Timer?

    override func loadView() {
        let panel = GlassPanel()
        panel.translatesAutoresizingMaskIntoConstraints = false

        self.view = NSView()
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            panel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])

        buildContent(in: panel.contentView)
    }

    private func buildContent(in container: NSView) {
        // Header
        let header = NSStackView()
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        let title = NSTextField(labelWithString: L.t(.appName))
        title.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        title.textColor = .labelColor

        let subtitle = NSTextField(labelWithString: L.t(.appTagline))
        subtitle.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabelColor

        header.addArrangedSubview(title)
        header.addArrangedSubview(subtitle)

        // Segmented control for tabs
        segmented = NSSegmentedControl(labels: Tab.allCases.map { $0.title },
                                       trackingMode: .selectOne,
                                       target: self,
                                       action: #selector(tabChanged(_:)))
        segmented.selectedSegment = 0
        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.controlSize = .regular

        // Content container
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        // Pre-build all tab views
        contentViews[.toggles] = buildTogglesView()
        contentViews[.monitor] = buildMonitorView()
        contentViews[.windows] = buildWindowsView()
        contentViews[.cleaner] = buildCleanerView()
        contentViews[.tools] = buildToolsView()
        contentViews[.launch] = buildLaunchView()

        // Assemble
        let root = NSStackView(views: [header, segmented, contentContainer])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            root.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16),
            segmented.widthAnchor.constraint(equalTo: root.widthAnchor),
            contentContainer.widthAnchor.constraint(equalTo: root.widthAnchor),
            contentContainer.heightAnchor.constraint(equalToConstant: 380),
        ])

        showTab(.toggles)
    }

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        guard let tab = Tab(rawValue: sender.selectedSegment) else { return }
        showTab(tab)
    }

    private func showTab(_ tab: Tab) {
        currentTab = tab
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        guard let view = contentViews[tab] else { return }
        contentContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        // Fade-in transition for a silkier tab switch.
        view.alphaValue = 0
        view.layer?.opacity = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = 1
        }
    }

    // MARK: - Tab: Toggles

    private var toggleRows: [ToggleRowView] = []

    private func buildTogglesView() -> NSView {
        let toggles: [Toggle] = [
            Toggle(id: "darkmode", title: L.t(.darkMode), symbol: "moon.fill",
                   isOn: { SystemController.isDarkMode },
                   setState: { SystemController.setDarkMode($0) }),
            Toggle(id: "hiddenfiles", title: L.t(.hiddenFiles), symbol: "eye.slash.fill",
                   isOn: { SystemController.showHiddenFiles },
                   setState: { SystemController.setShowHiddenFiles($0) }),
            Toggle(id: "pathbar", title: L.t(.pathBar), symbol: "point.topleft.down.curvedto.point.bottomright.up",
                   isOn: { SystemController.showPathBar },
                   setState: { SystemController.setShowPathBar($0) }),
            Toggle(id: "desktopicons", title: L.t(.desktopIcons), symbol: "desktopcomputer",
                   isOn: { SystemController.hideDesktopIcons },
                   setState: { SystemController.setHideDesktopIcons($0) }),
            Toggle(id: "keepawake", title: L.t(.keepAwake), symbol: "moon.zzz.fill",
                   isOn: { SystemController.isKeepAwake },
                   setState: { SystemController.setKeepAwake($0) }),
            Toggle(id: "mute", title: L.t(.mute), symbol: "speaker.slash.fill",
                   isOn: { SystemController.isMuted },
                   setState: { SystemController.setMuted($0) }),
            Toggle(id: "autohidedock", title: L.t(.autoHideDock), symbol: "dock.rectangle",
                   isOn: { SystemController.autoHideDock },
                   setState: { SystemController.setAutoHideDock($0) }),
            Toggle(id: "menubar", title: L.t(.hideMenuBar), symbol: "rectangle.topthird.inset.filled",
                   isOn: { SystemController.hideMenuBar },
                   setState: { SystemController.setHideMenuBar($0) }),
            Toggle(id: "scroll", title: L.t(.naturalScrolling), symbol: "arrow.up.arrow.down",
                   isOn: { SystemController.naturalScrolling },
                   setState: { SystemController.setNaturalScrolling($0) }),
        ]

        let list = NSStackView()
        list.orientation = .vertical
        list.spacing = 8
        list.alignment = .leading
        list.translatesAutoresizingMaskIntoConstraints = false

        for toggle in toggles {
            let row = ToggleRowView(toggle: toggle)
            toggleRows.append(row)
            let capsule = wrapInCapsule(row)
            list.addArrangedSubview(capsule)
            capsule.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }

        let scroll = NSScrollView()
        scroll.documentView = list
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        list.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true

        return scroll
    }

    private func wrapInCapsule(_ row: NSView) -> GlassPanel {
        let capsule = GlassPanel()
        capsule.glassCornerRadius = 16
        let inner = capsule.contentView
        inner.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: inner.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: inner.trailingAnchor),
            row.topAnchor.constraint(equalTo: inner.topAnchor),
            row.bottomAnchor.constraint(equalTo: inner.bottomAnchor),
        ])
        capsule.addGlassHoverAnimation()
        return capsule
    }

    // MARK: - Tab: Monitor

    private var cpuLabel: NSTextField!
    private var memLabel: NSTextField!
    private var netLabel: NSTextField!

    private func buildMonitorView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        cpuLabel = metricLabel(title: L.t(.cpu))
        memLabel = metricLabel(title: L.t(.memory))
        netLabel = metricLabel(title: L.t(.network))

        let cpuRow = makeMetricRow(symbol: "cpu", title: L.t(.cpu), valueLabel: cpuLabel)
        let memRow = makeMetricRow(symbol: "memorychip", title: L.t(.memory), valueLabel: memLabel)
        let netRow = makeMetricRow(symbol: "arrow.up.arrow.down", title: L.t(.network), valueLabel: netLabel)

        [cpuRow, memRow, netRow].forEach {
            let capsule = wrapInCapsule($0)
            stack.addArrangedSubview(capsule)
            capsule.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        startMonitorSampling()
        return stack
    }

    private func metricLabel(title: String) -> NSTextField {
        let label = NSTextField(labelWithString: "—")
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .right
        return label
    }

    private func makeMetricRow(symbol: String, title: String, valueLabel: NSTextField) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            icon.image = img
            icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            icon.contentTintColor = .controlAccentColor
        }
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(icon)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(valueLabel)

        let container = NSView()
        container.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        return container
    }

    private func startMonitorSampling() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let cpu = SystemMonitor.cpuUsage
            let used = SystemMonitor.usedMemory
            let total = SystemMonitor.totalMemory
            let net = SystemMonitor.networkThroughput()

            DispatchQueue.main.async {
                self.cpuLabel?.stringValue = String(format: "%.0f%%", cpu * 100)
                self.memLabel?.stringValue = "\(ByteFormatter.string(used)) / \(ByteFormatter.string(total))"
                self.netLabel?.stringValue = "↓ \(ByteFormatter.rate(net.rx))  ↑ \(ByteFormatter.rate(net.tx))"
            }
        }
        monitorTimer?.tolerance = 0.2
    }

    // MARK: - Tab: Windows

    private func buildWindowsView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let refreshButton = makeActionButton(title: L.t(.refresh), symbol: "arrow.clockwise") { [weak self] in
            self?.rebuildWindowsList()
        }
        stack.addArrangedSubview(refreshButton)
        refreshButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let listContainer = NSView()
        listContainer.translatesAutoresizingMaskIntoConstraints = false
        listContainer.identifier = NSUserInterfaceItemIdentifier("windowsList")
        stack.addArrangedSubview(listContainer)
        listContainer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        listContainer.heightAnchor.constraint(equalToConstant: 300).isActive = true

        rebuildWindowsList()
        return stack
    }

    private func rebuildWindowsList() {
        guard let container = findView(withID: "windowsList") else { return }

        let apps = WindowController.runningApps()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        for app in apps.prefix(20) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8

            let nameLabel = NSTextField(labelWithString: app.name)
            nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            nameLabel.textColor = .labelColor
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let frontButton = NSButton(title: "", target: nil, action: nil)
            frontButton.image = NSImage(systemSymbolName: "arrow.up.forward.app",
                                        accessibilityDescription: L.t(.bringToFront))
            frontButton.bezelStyle = .inline
            frontButton.toolTip = L.t(.bringToFront)
            let frontHandler = ActionHandler { WindowController.activate(pid: app.pid) }
            frontButton.target = frontHandler
            frontButton.action = #selector(ActionHandler.run)
            objc_setAssociatedObject(frontButton, "h", frontHandler, .OBJC_ASSOCIATION_RETAIN)

            let quitButton = NSButton(title: "", target: nil, action: nil)
            quitButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                       accessibilityDescription: L.t(.forceQuit))
            quitButton.bezelStyle = .inline
            quitButton.contentTintColor = .systemRed
            quitButton.toolTip = L.t(.forceQuit)
            let quitHandler = ActionHandler { WindowController.forceQuit(pid: app.pid) }
            quitButton.target = quitHandler
            quitButton.action = #selector(ActionHandler.run)
            objc_setAssociatedObject(quitButton, "h", quitHandler, .OBJC_ASSOCIATION_RETAIN)

            row.addArrangedSubview(nameLabel)
            row.addArrangedSubview(frontButton)
            row.addArrangedSubview(quitButton)

            let capsule = wrapInCapsule(row)
            stack.addArrangedSubview(capsule)
            capsule.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        container.subviews.forEach { $0.removeFromSuperview() }
        let scroll = NSScrollView()
        scroll.documentView = stack
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        container.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func findView(withID id: String) -> NSView? {
        func search(_ view: NSView) -> NSView? {
            if view.identifier?.rawValue == id { return view }
            for sub in view.subviews {
                if let found = search(sub) { return found }
            }
            return nil
        }
        return search(self.view)
    }

    // MARK: - Tab: Cleaner

    private func buildCleanerView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scanButton = makeActionButton(title: L.t(.scan), symbol: "magnifyingglass") { [weak self] in
            self?.scanCache()
        }
        let cleanButton = makeActionButton(title: L.t(.cleanAll), symbol: "trash.fill") { [weak self] in
            self?.cleanAll()
        }
        stack.addArrangedSubview(scanButton)
        stack.addArrangedSubview(cleanButton)

        let resultLabel = NSTextField(labelWithString: L.t(.scanHint))
        resultLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.lineBreakMode = .byWordWrapping
        resultLabel.maximumNumberOfLines = 0
        resultLabel.identifier = NSUserInterfaceItemIdentifier("cleanResult")
        stack.addArrangedSubview(resultLabel)

        scanButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        cleanButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        resultLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return stack
    }

    private func scanCache() {
        let results = DiskCleaner.scan()
        let text = results
            .filter { $0.bytes > 0 }
            .map { "\($0.name): \(ByteFormatter.string($0.bytes))" }
            .joined(separator: "\n")
        updateCleanResult(text.isEmpty ? L.t(.nothingToClean) : text)
    }

    private func cleanAll() {
        let freed = DiskCleaner.cleanAll()
        updateCleanResult("\(L.t(.freed)) \(ByteFormatter.string(freed))")
    }

    private func updateCleanResult(_ text: String) {
        if let label = findView(withID: "cleanResult") as? NSTextField {
            label.stringValue = text
        }
    }

    // MARK: - Tab: Tools

    private func buildToolsView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let screenshot = makeActionButton(title: L.t(.screenshot), symbol: "camera") {
            DevTools.captureScreenshot()
        }
        let record = makeActionButton(title: L.t(.screenRecord), symbol: "record.circle") {
            DevTools.recordScreen()
        }
        let ocr = makeActionButton(title: L.t(.ocr), symbol: "text.viewfinder") { [weak self] in
            DevTools.ocrClipboard { text in
                DispatchQueue.main.async {
                    if let text = text {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        self?.showToast(L.t(.ocrCopied))
                    } else {
                        self?.showToast(L.t(.ocrNoImage))
                    }
                }
            }
        }
        stack.addArrangedSubview(screenshot)
        stack.addArrangedSubview(record)
        stack.addArrangedSubview(ocr)

        // Quick system actions
        let emptyTrash = makeActionButton(title: L.t(.emptyTrash), symbol: "trash") {
            SystemController.emptyTrash()
        }
        let emptyClipboard = makeActionButton(title: L.t(.emptyClipboard), symbol: "doc.on.clipboard") {
            SystemController.emptyClipboard()
        }
        let screenSaver = makeActionButton(title: L.t(.screenSaver), symbol: "sparkles.tv") {
            SystemController.startScreenSaver()
        }
        stack.addArrangedSubview(emptyTrash)
        stack.addArrangedSubview(emptyClipboard)
        stack.addArrangedSubview(screenSaver)

        [screenshot, record, ocr, emptyTrash, emptyClipboard, screenSaver].forEach {
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func showToast(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    // MARK: - Tab: Launch

    private func buildLaunchView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        for item in QuickLaunch.load() {
            let symbol = item.kind == .url ? "safari" : (item.kind == .command ? "terminal" : "doc")
            let button = makeActionButton(title: item.label, symbol: symbol) {
                QuickLaunch.launch(item)
            }
            stack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    // MARK: - Helpers

    private func makeActionButton(title: String, symbol: String, action: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.bezelStyle = .texturedRounded
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        let handler = ActionHandler(action: action)
        button.target = handler
        button.action = #selector(ActionHandler.run)
        objc_setAssociatedObject(button, "handler", handler, .OBJC_ASSOCIATION_RETAIN)
        return button
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshToggles()
    }

    private func refreshToggles() {
        // Reading system state shells out (osascript / defaults), which can
        // block for tens of ms each. Do it off the main thread so the panel
        // opens instantly, then bounce back to apply the authoritative state.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let states = self.toggleRows.map { row -> Bool in
                row.currentToggleState()
            }
            DispatchQueue.main.async {
                for (row, state) in zip(self.toggleRows, states) {
                    row.applyState(state)
                }
            }
        }
    }

    deinit {
        monitorTimer?.invalidate()
    }
}

/// Objective-C-compatible action wrapper.
final class ActionHandler: NSObject {
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func run() { action() }
}
