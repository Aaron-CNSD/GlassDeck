import AppKit

/// The central app delegate: owns the menu bar item, the Liquid Glass popover,
/// and the standalone control window.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var controlWindow: NSWindow?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarItem()
        setupPopover()
        // Open the control window automatically so the app is visible on launch.
        DispatchQueue.main.async { [weak self] in
            self?.openControlWindow()
        }
    }

    /// Re-open the window when the Dock icon is clicked.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openControlWindow()
        return true
    }

    // MARK: - Menu Bar Item

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = Self.makeMenuBarIcon()
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = L.t(.appName)
        }
    }

    /// Generate a menu bar glyph matching the app icon: a triangular glass
    /// prism refracting a light beam into a spectrum. Rendered as a template
    /// image so it adapts to light/dark menu bars.
    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            img.unlockFocus()
            return img
        }
        ctx.setShouldAntialias(true)

        // Prism triangle (pointing right-ish, upright)
        let prism = NSBezierPath()
        prism.move(to: NSPoint(x: 7.0, y: 3.0))     // top vertex
        prism.line(to: NSPoint(x: 7.0, y: 15.0))    // bottom-left
        prism.line(to: NSPoint(x: 12.0, y: 9.0))    // right vertex
        prism.close()
        NSColor.black.setFill()
        prism.fill()

        // Incident light beam (left)
        let beam = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 8.0, width: 5.5, height: 2.0),
                                xRadius: 1, yRadius: 1)
        NSColor.black.setFill()
        beam.fill()

        // Refracted spectrum (right) — three short bars, top to bottom
        let spectrumTop = NSBezierPath(roundedRect: NSRect(x: 13.0, y: 11.5, width: 3.5, height: 1.4),
                                       xRadius: 0.7, yRadius: 0.7)
        spectrumTop.fill()

        let spectrumMid = NSBezierPath(roundedRect: NSRect(x: 13.0, y: 8.25, width: 3.5, height: 1.4),
                                       xRadius: 0.7, yRadius: 0.7)
        spectrumMid.fill()

        let spectrumBot = NSBezierPath(roundedRect: NSRect(x: 13.0, y: 5.0, width: 3.5, height: 1.4),
                                       xRadius: 0.7, yRadius: 0.7)
        spectrumBot.fill()

        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    // MARK: - Popover (Menu Bar Panel)

    private func setupPopover() {
        let content = DeckViewController()
        popover.contentViewController = content
        popover.behavior = .transient
        popover.animates = true

        // On macOS 26+, the popover already picks up the Liquid Glass look.
        // Set a sensible content size for the deck.
        content.preferredContentSize = NSSize(width: 380, height: 720)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu(sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Right-click opens a small menu with "Open Control Window",
    /// a Language submenu, and Quit.
    private func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L.t(.openControlWindow),
                                action: #selector(openControlWindow),
                                keyEquivalent: ""))

        // Language submenu
        let languageItem = NSMenuItem(title: L.t(.language), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for lang in L.Lang.allCases {
            let item = NSMenuItem(title: lang.displayName,
                                  action: #selector(selectLanguage(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = lang.code
            item.state = (L.current == lang && L.hasOverride) ? .on : .off
            languageMenu.addItem(item)
        }
        languageMenu.addItem(.separator())
        let followItem = NSMenuItem(title: L.t(.followSystem),
                                    action: #selector(followSystemLanguage(_:)),
                                    keyEquivalent: "")
        followItem.target = self
        followItem.state = L.hasOverride ? .off : .on
        languageMenu.addItem(followItem)
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L.t(.quit),
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // reset so left-click still toggles popover
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String,
              let lang = L.Lang.allCases.first(where: { $0.code == code }) else { return }
        L.setOverride(lang)
        reloadUIForLanguageChange()
    }

    @objc private func followSystemLanguage(_ sender: NSMenuItem) {
        L.setOverride(nil)
        reloadUIForLanguageChange()
    }

    /// Rebuild the control window & popover with the newly selected language.
    private func reloadUIForLanguageChange() {
        // Recreate the popover content with fresh localized strings.
        let content = DeckViewController()
        content.preferredContentSize = NSSize(width: 380, height: 720)
        popover.contentViewController = content

        // Recreate the standalone window too.
        if controlWindow != nil {
            controlWindow?.close()
            controlWindow = nil
        }
        openControlWindow()

        // Update the menu bar tooltip.
        statusItem.button?.toolTip = L.t(.appName)
    }

    // MARK: - Standalone Control Window

    @objc private func openControlWindow() {
        if let window = controlWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vc = DeckViewController()
        vc.preferredContentSize = NSSize(width: 380, height: 720)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L.t(.appName)
        window.isMovableByWindowBackground = true
        window.contentViewController = vc
        window.center()
        window.isReleasedWhenClosed = false

        controlWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
