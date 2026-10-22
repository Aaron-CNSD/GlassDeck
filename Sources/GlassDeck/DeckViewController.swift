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
    private var statusBanner: StatusBanner!

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
        panel.startAmbientSheen()
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

        // Status line: every action reports here instead of popping an alert,
        // so a failed switch is visible without blocking the panel.
        statusBanner = StatusBanner()
        statusBanner.isHidden = true

        // Pre-build all tab views
        contentViews[.toggles] = buildTogglesView()
        contentViews[.monitor] = buildMonitorView()
        contentViews[.windows] = buildWindowsView()
        contentViews[.cleaner] = buildCleanerView()
        contentViews[.tools] = buildToolsView()
        contentViews[.launch] = buildLaunchView()

        // Assemble
        let root = NSStackView(views: [header, segmented, contentContainer, statusBanner])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            segmented.widthAnchor.constraint(equalTo: root.widthAnchor),
            contentContainer.widthAnchor.constraint(equalTo: root.widthAnchor),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            statusBanner.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])

        showTab(.toggles)

        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handleCommandFailed(_:)),
                                              name: SystemController.commandFailed,
                                              object: nil)
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handleCommandSucceeded(_:)),
                                              name: SystemController.commandSucceeded,
                                              object: nil)
    }

    // MARK: - Status reporting

    @objc private func handleCommandSucceeded(_ note: Notification) {
        guard let label = note.userInfo?["label"] as? String else { return }
        showStatus("\(L.t(.done)): \(label)", isError: false)
    }

    @objc private func handleCommandFailed(_ note: Notification) {
        guard let info = note.userInfo,
              let label = info["label"] as? String else { return }
        let message = info["message"] as? String ?? L.t(.failed)
        let needsPermission = info["permission"] as? Bool ?? false
        showStatus("\(label) — \(message)", isError: true,
                   actionTitle: needsPermission ? L.t(.openSettings) : nil,
                   action: needsPermission ? { PermissionCenter.openAutomationSettings() } : nil)
    }

    private func showStatus(_ text: String, isError: Bool,
                            actionTitle: String? = nil,
                            action: (() -> Void)? = nil) {
        statusBanner.show(text, isError: isError, actionTitle: actionTitle, action: action)
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
    /// The glass capsule wrapping each row, so search can hide whole cards.
    private var toggleCapsules: [NSView] = []
    /// Toggle descriptors, index-aligned with `toggleCapsules`.
    private var toggleItems: [Toggle] = []
    private var searchField: NSSearchField!
    private var emptyHint: NSTextField!

    private func buildTogglesView() -> NSView {
        let toggles = ToggleLibrary.all
        toggleItems = toggles

        let list = NSStackView()
        list.orientation = .vertical
        list.spacing = 8
        list.alignment = .leading
        list.translatesAutoresizingMaskIntoConstraints = false

        for toggle in toggles {
            let row = ToggleRowView(toggle: toggle)
            row.onFailure = { [weak self] title in
                self?.showStatus("\(title) — \(L.t(.failed))", isError: true,
                                 actionTitle: L.t(.permissionCheck),
                                 action: { self?.showDiagnostics() })
            }
            toggleRows.append(row)
            let capsule = wrapInCapsule(row)
            toggleCapsules.append(capsule)
            list.addArrangedSubview(capsule)
            capsule.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }

        let scroll = makeScrollableList(list)

        // Search: with a dozen switches, scanning the list is the slow part.
        let search = NSSearchField()
        search.placeholderString = L.t(.searchPlaceholder)
        search.target = self
        search.action = #selector(searchChanged(_:))
        search.controlSize = .regular
        search.font = NSFont.systemFont(ofSize: 12)
        search.translatesAutoresizingMaskIntoConstraints = false
        searchField = search

        // Scenes: one click instead of four flips.
        let scenes = buildScenesRow()

        let hint = NSTextField(labelWithString: L.t(.noMatches))
        hint.font = NSFont.systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center
        hint.isHidden = true
        hint.translatesAutoresizingMaskIntoConstraints = false
        emptyHint = hint

        let stack = NSStackView(views: [search, scenes, hint, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        for child in [search, scenes, hint, scroll] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        // Let the list absorb all leftover height.
        scroll.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .vertical)
        scroll.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: .vertical)

        return stack
    }

    /// A row of equal-width scene buttons under the search field.
    private func buildScenesRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        for scene in SceneLibrary.all {
            let button = NSButton(title: scene.title, target: self, action: #selector(sceneTapped(_:)))
            if let image = NSImage(systemSymbolName: scene.symbol, accessibilityDescription: scene.title) {
                button.image = image
                button.imagePosition = .imageLeading
                button.imageScaling = .scaleProportionallyDown
            }
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.controlSize = .small
            button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            button.contentTintColor = .controlAccentColor
            button.identifier = NSUserInterfaceItemIdentifier(scene.id)
            button.toolTip = scene.title
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            row.addArrangedSubview(button)
        }

        return row
    }

    @objc private func sceneTapped(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let scene = SceneLibrary.scene(id: id) else { return }

        SceneLibrary.apply(scene) { [weak self] changed in
            guard let self = self else { return }
            let detail = changed == 0 ? scene.title : "\(scene.title) · \(changed)"
            self.showStatus("\(L.t(.sceneApplied)) — \(detail)", isError: false)
            self.refreshToggles()
        }
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        applyToggleFilter(sender.stringValue)
    }

    private func applyToggleFilter(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var visible = 0

        for (index, toggle) in toggleItems.enumerated() where index < toggleCapsules.count {
            let haystack = (toggle.title + " " + toggle.id).lowercased()
            let matches = q.isEmpty || haystack.contains(q)
            toggleCapsules[index].isHidden = !matches
            if matches { visible += 1 }
        }

        emptyHint?.isHidden = visible > 0
    }

    /// Puts a vertical stack inside a scroll view so it starts at the TOP.
    ///
    /// `NSStackView` is not flipped, so using it directly as `documentView`
    /// makes the scroll view start at the bottom — the first rows end up
    /// hidden above the visible area. A flipped container fixes the origin.
    private func makeScrollableList(_ stack: NSStackView) -> NSScrollView {
        stack.translatesAutoresizingMaskIntoConstraints = false

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = doc

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
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
        showStatus(L.t(.scan), isError: false)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let results = DiskCleaner.scan()
            let text = results
                .filter { $0.bytes > 0 }
                .map { "\($0.name): \(ByteFormatter.string($0.bytes))" }
                .joined(separator: "\n")
            DispatchQueue.main.async {
                self?.updateCleanResult(text.isEmpty ? L.t(.nothingToClean) : text)
            }
        }
    }

    private func cleanAll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let freed = DiskCleaner.cleanAll()
            DispatchQueue.main.async {
                self?.updateCleanResult("\(L.t(.freed)) \(ByteFormatter.string(freed))")
            }
        }
    }

    private func updateCleanResult(_ text: String) {
        if let label = findView(withID: "cleanResult") as? NSTextField {
            label.stringValue = text
        }
    }

    // MARK: - Tab: Tools

    private var toolsContainer: NSView!
    private var toolsScroll: NSScrollView!
    private var diagnosticsScroll: NSView?
    private var diagRows: NSStackView?

    private func buildToolsView() -> NSView {
        toolsContainer = NSView()
        toolsContainer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Self-check goes first: it is the answer to "why did nothing happen?".
        let check = makeActionButton(title: L.t(.permissionCheck), symbol: "stethoscope") { [weak self] in
            self?.showDiagnostics()
        }
        stack.addArrangedSubview(check)

        let screenshot = makeActionButton(title: L.t(.screenshot), symbol: "camera") { [weak self] in
            DevTools.captureScreenshot { error in
                guard let error = error else { return }
                self?.showStatus(error, isError: true,
                                 actionTitle: L.t(.openSettings),
                                 action: { PermissionCenter.openScreenRecordingSettings() })
            }
        }
        let record = makeActionButton(title: L.t(.screenRecord), symbol: "record.circle") { [weak self] in
            DevTools.recordScreen { error in
                guard let error = error else { return }
                self?.showStatus(error, isError: true,
                                 actionTitle: L.t(.openSettings),
                                 action: { PermissionCenter.openScreenRecordingSettings() })
            }
        }
        let ocr = makeActionButton(title: L.t(.ocr), symbol: "text.viewfinder") { [weak self] in
            DevTools.ocrClipboard { text in
                DispatchQueue.main.async {
                    if let text = text {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        self?.showStatus(L.t(.ocrCopied), isError: false)
                    } else {
                        self?.showStatus(L.t(.ocrNoImage), isError: true)
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
        let dns = makeActionButton(title: L.t(.dnsCache), symbol: "network.slash") {
            SystemController.flushDNSCache()
        }
        let finder = makeActionButton(title: L.t(.restartFinder), symbol: "arrow.clockwise") {
            SystemController.restartFinder()
        }
        let copyIP = makeActionButton(title: L.t(.copyIP), symbol: "number") { [weak self] in
            if let ip = SystemController.localIP() {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ip, forType: .string)
                self?.showStatus("\(L.t(.copied)): \(ip)", isError: false)
            } else {
                self?.showStatus("\(L.t(.copyIP)) — \(L.t(.failed))", isError: true)
            }
        }
        let lock = makeActionButton(title: L.t(.lockScreen), symbol: "lock.display") {
            SystemController.lockScreen()
        }

        let buttons = [screenshot, record, ocr,
                       emptyTrash, emptyClipboard, screenSaver,
                       dns, finder, copyIP, lock]
        buttons.forEach { stack.addArrangedSubview($0) }

        let scroll = makeScrollableList(stack)
        toolsScroll = scroll

        toolsContainer.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: toolsContainer.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: toolsContainer.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: toolsContainer.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: toolsContainer.bottomAnchor),
        ])

        return toolsContainer
    }

    // MARK: - Diagnostics

    private func showDiagnostics() {
        if currentTab != .tools {
            segmented.selectedSegment = Tab.tools.rawValue
            showTab(.tools)
        }
        let view = buildDiagnosticsView()
        diagnosticsScroll?.removeFromSuperview()
        diagnosticsScroll = view
        toolsScroll?.isHidden = true
        toolsContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: toolsContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: toolsContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: toolsContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: toolsContainer.bottomAnchor),
        ])
        refreshDiagnostics()
    }

    private func hideDiagnostics() {
        diagnosticsScroll?.removeFromSuperview()
        diagnosticsScroll = nil
        diagRows = nil
        toolsScroll?.isHidden = false
    }

    private func buildDiagnosticsView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        let back = NSButton(title: L.t(.back), target: nil, action: nil)
        back.bezelStyle = .inline
        back.isBordered = false
        back.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let backHandler = ActionHandler { [weak self] in self?.hideDiagnostics() }
        back.target = backHandler
        back.action = #selector(ActionHandler.run)
        objc_setAssociatedObject(back, "h", backHandler, .OBJC_ASSOCIATION_RETAIN)

        let recheck = NSButton(title: L.t(.recheck), target: nil, action: nil)
        recheck.bezelStyle = .inline
        recheck.isBordered = false
        recheck.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let recheckHandler = ActionHandler { [weak self] in self?.refreshDiagnostics() }
        recheck.target = recheckHandler
        recheck.action = #selector(ActionHandler.run)
        objc_setAssociatedObject(recheck, "h", recheckHandler, .OBJC_ASSOCIATION_RETAIN)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerRow.addArrangedSubview(back)
        headerRow.addArrangedSubview(spacer)
        headerRow.addArrangedSubview(recheck)
        stack.addArrangedSubview(headerRow)
        headerRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let hint = NSTextField(labelWithString: L.t(.permissionCheckHint))
        hint.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 0
        stack.addArrangedSubview(hint)
        hint.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.spacing = 6
        rows.alignment = .leading
        rows.identifier = NSUserInterfaceItemIdentifier("diagRows")
        stack.addArrangedSubview(rows)
        rows.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])

        diagRows = rows
        // No probing here: the view is not in the hierarchy yet. The caller
        // kicks off `refreshDiagnostics()` once it has been added.
        return container
    }

    private func refreshDiagnostics() {
        guard let rows = diagRows else { return }
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let loading = NSTextField(labelWithString: L.t(.cleaning))
        loading.font = NSFont.systemFont(ofSize: 12)
        loading.textColor = .secondaryLabelColor
        rows.addArrangedSubview(loading)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let results = Diagnostics.runAll()
            DispatchQueue.main.async {
                guard let self = self,
                      let rows = self.diagRows else { return }
                rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
                for result in results {
                    let view = self.makeDiagnosticRow(result)
                    rows.addArrangedSubview(view)
                    view.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
                }
            }
        }
    }

    private func makeDiagnosticRow(_ result: DiagnosticResult) -> NSView {
        let symbol: String
        let color: NSColor
        switch result.level {
        case .ok: symbol = "checkmark.circle.fill"; color = .systemGreen
        case .warn: symbol = "exclamationmark.triangle.fill"; color = .systemOrange
        case .fail: symbol = "xmark.octagon.fill"; color = .systemRed
        }

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        icon.contentTintColor = color
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let title = NSTextField(labelWithString: result.title)
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        title.textColor = .labelColor

        let detail = NSTextField(labelWithString: result.detail)
        detail.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byWordWrapping
        detail.maximumNumberOfLines = 0

        let text = NSStackView(views: [title, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [icon, text])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 8

        if let fix = result.fix {
            let button = NSButton(title: L.t(.openSettings), target: nil, action: nil)
            button.bezelStyle = .inline
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            button.contentTintColor = .controlAccentColor
            let handler = ActionHandler {
                switch fix {
                case .automation: PermissionCenter.openAutomationSettings()
                case .screenRecording: PermissionCenter.openScreenRecordingSettings()
                }
            }
            button.target = handler
            button.action = #selector(ActionHandler.run)
            objc_setAssociatedObject(button, "h", handler, .OBJC_ASSOCIATION_RETAIN)
            row.addArrangedSubview(button)
        }

        let capsule = wrapInCapsule(row)
        return capsule
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
        NotificationCenter.default.removeObserver(self)
    }
}

/// Objective-C-compatible action wrapper.
final class ActionHandler: NSObject {
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func run() { action() }
}

/// An ordinary container whose origin is top-left. Used as the document view
/// of a scroll view so its content is not bottom-anchored.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// A one-line, non-blocking status strip. Replaces the old modal alert, which
/// interrupted the panel and hid the actual cause of a failure.
final class StatusBanner: NSView {

    private let label = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "", target: nil, action: nil)
    private var action: (() -> Void)?
    private var hideTimer: Timer?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true

        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        label.textColor = .labelColor
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        actionButton.bezelStyle = .inline
        actionButton.isBordered = false
        actionButton.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        actionButton.contentTintColor = .controlAccentColor
        actionButton.target = self
        actionButton.action = #selector(fireAction)
        actionButton.isHidden = true

        let row = NSStackView(views: [label, actionButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ text: String, isError: Bool, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        label.stringValue = text
        label.textColor = isError ? .systemRed : .secondaryLabelColor
        layer?.backgroundColor = (isError
            ? NSColor.systemRed.withAlphaComponent(0.12)
            : NSColor.white.withAlphaComponent(0.08)).cgColor

        self.action = action
        if let actionTitle = actionTitle {
            actionButton.title = actionTitle
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }

        isHidden = false

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: isError ? 8 : 3, repeats: false) { [weak self] _ in
            self?.isHidden = true
        }
    }

    @objc private func fireAction() {
        action?()
    }
}
