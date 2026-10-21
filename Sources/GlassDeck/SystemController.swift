import AppKit

/// Wraps the actual macOS system state manipulation.
///
/// Most toggles shell out to system defaults / AppleScript because those are
/// the only public, App-Sandbox-friendly ways to flip many system prefs.
///
/// Every action reports back through one of the two notifications below, so a
/// denied permission can never again look like a dead button.
enum SystemController {

    // MARK: - Reporting

    /// Posted on the main thread after a user action succeeded.
    /// `userInfo["label"]` carries the human-readable action name.
    static let commandSucceeded = Notification.Name("GlassDeckCommandSucceeded")

    /// Posted on the main thread when a command exits non-zero.
    /// `userInfo`: `label`, `code`, `message`, and `permission` (Bool).
    static let commandFailed = Notification.Name("GlassDeckCommandFailed")

    private static func post(_ name: Notification.Name, label: String, extra: [String: Any] = [:]) {
        var info: [String: Any] = ["label": label]
        extra.forEach { info[$0.key] = $0.value }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil, userInfo: info)
        }
    }

    private static func reportSuccess(_ label: String) {
        post(commandSucceeded, label: label)
    }

    private static func reportFailure(_ label: String, code: Int32, message: String) {
        let combined = message.lowercased()
        let isPermission = combined.contains("-1743")
            || combined.contains("not authorized")
            || combined.contains("not permitted")
            || combined.contains("operation not permitted")
        var detail = message
        if isPermission {
            detail = L.t(.automationDeniedHint)
        } else if detail.isEmpty {
            detail = "exit \(code)"
        } else if detail.count > 220 {
            detail = String(detail.prefix(220))
        }
        post(commandFailed, label: label, extra: ["code": code, "message": detail, "permission": isPermission])
    }

    // MARK: - Process helpers

    /// Runs the given commands in order on a background queue and reports a
    /// single success / failure for the whole group. `stdout` is sent to the
    /// null device — a `Pipe` nobody reads would block once it filled up.
    private static func runSequence(_ commands: [[String]], label: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            for args in commands {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = args
                let errPipe = Pipe()
                process.standardError = errPipe
                process.standardOutput = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    reportFailure(label, code: -1, message: error.localizedDescription)
                    return
                }
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    reportFailure(label, code: process.terminationStatus, message: message)
                    return
                }
            }
            reportSuccess(label)
        }
    }

    private static func run(_ args: [String], label: String) {
        runSequence([args], label: label)
    }

    /// Runs synchronously and returns stdout. Only for fast reads.
    private static func runSync(_ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func defaultsRead(_ key: String, domain: String) -> String? {
        return runSync(["/usr/bin/defaults", "read", domain, key])
    }

    private static func osascript(_ source: String, label: String) {
        run(["/usr/bin/osascript", "-e", source], label: label)
    }

    // MARK: - Dark Mode

    /// Reads the system setting, not the app's own appearance. The old version
    /// used `NSApp.effectiveAppearance`, which describes this window — so after
    /// flipping the switch it always snapped straight back.
    static var isDarkMode: Bool {
        return runSync(["/usr/bin/defaults", "read", "-g", "AppleInterfaceStyle"]) == "Dark"
    }

    /// Dark mode is a System Events setting, so this needs Automation
    /// permission. It is granted once and remembered by macOS.
    static func setDarkMode(_ on: Bool) {
        osascript("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)",
                  label: L.t(.darkMode))
    }

    // MARK: - Hidden Files (Finder)

    static var showHiddenFiles: Bool {
        let v = defaultsRead("AppleShowAllFiles", domain: "com.apple.finder")
        return v == "YES" || v == "1" || v == "true"
    }

    static func setShowHiddenFiles(_ on: Bool) {
        runSequence([
            ["/usr/bin/defaults", "write", "com.apple.finder", "AppleShowAllFiles", on ? "YES" : "NO"],
            ["/usr/bin/killall", "Finder"],
        ], label: L.t(.hiddenFiles))
    }

    // MARK: - Show Path Bar in Finder

    static var showPathBar: Bool {
        let v = defaultsRead("ShowPathbar", domain: "com.apple.finder")
        return v == "YES" || v == "1" || v == "true"
    }

    static func setShowPathBar(_ on: Bool) {
        runSequence([
            ["/usr/bin/defaults", "write", "com.apple.finder", "ShowPathbar", on ? "YES" : "NO"],
            ["/usr/bin/killall", "Finder"],
        ], label: L.t(.pathBar))
    }

    // MARK: - Hide Desktop Icons

    static var hideDesktopIcons: Bool {
        let v = defaultsRead("CreateDesktop", domain: "com.apple.finder")
        return v == "false" || v == "0"
    }

    static func setHideDesktopIcons(_ on: Bool) {
        // CreateDesktop = false hides icons
        runSequence([
            ["/usr/bin/defaults", "write", "com.apple.finder", "CreateDesktop", on ? "false" : "true"],
            ["/usr/bin/killall", "Finder"],
        ], label: L.t(.desktopIcons))
    }

    // MARK: - Keep Awake (caffeinate)

    static func setKeepAwake(_ on: Bool) {
        if on {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            process.arguments = ["-d", "-i", "-m", "-s"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                KeepAwakeManager.shared.process = process
                reportSuccess(L.t(.keepAwake))
            } catch {
                reportFailure(L.t(.keepAwake), code: -1, message: error.localizedDescription)
            }
        } else {
            KeepAwakeManager.shared.stop()
            reportSuccess(L.t(.keepAwake))
        }
    }

    static var isKeepAwake: Bool {
        return KeepAwakeManager.shared.isRunning
    }

    // MARK: - Mute

    static var isMuted: Bool {
        let out = runSync(["/usr/bin/osascript", "-e", "output muted of (get volume settings)"])
        return out == "true"
    }

    static func setMuted(_ on: Bool) {
        // `set volume` is a Standard Additions command — no Automation grant needed.
        osascript("set volume output muted \(on)", label: L.t(.mute))
    }

    // MARK: - Auto-Hide Dock

    static var autoHideDock: Bool {
        let v = defaultsRead("autohide", domain: "com.apple.dock")
        return v == "1" || v == "true"
    }

    static func setAutoHideDock(_ on: Bool) {
        runSequence([
            ["/usr/bin/defaults", "write", "com.apple.dock", "autohide", "-bool", on ? "true" : "false"],
            ["/usr/bin/killall", "Dock"],
        ], label: L.t(.autoHideDock))
    }

    // MARK: - Empty Trash

    static func emptyTrash() {
        osascript("tell application \"Finder\" to empty trash", label: L.t(.emptyTrash))
    }

    // MARK: - Empty Clipboard

    static func emptyClipboard() {
        NSPasteboard.general.clearContents()
        reportSuccess(L.t(.emptyClipboard))
    }

    // MARK: - Screen Saver (start now)

    static func startScreenSaver() {
        run(["/usr/bin/open", "-a", "ScreenSaverEngine"], label: L.t(.screenSaver))
    }

    // MARK: - Auto-Hide Menu Bar

    /// "Automatically hide and show the menu bar" — the real, visible setting.
    ///
    /// The old implementation wrote `AppleMenuBarVisibleInFullscreen` into the
    /// Finder domain, which does nothing outside full screen. That toggle could
    /// never have worked.
    static var hideMenuBar: Bool {
        let v = defaultsRead("_HIHideMenuBar", domain: "NSGlobalDomain")
        return v == "1" || v == "true"
    }

    static func setHideMenuBar(_ on: Bool) {
        runSequence([
            ["/usr/bin/defaults", "write", "NSGlobalDomain", "_HIHideMenuBar", "-bool", on ? "true" : "false"],
            ["/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", "-u"],
        ], label: L.t(.hideMenuBar))
        // The menu bar itself is drawn by SystemUIServer; bouncing it applies
        // the change instantly instead of after the next login.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.6) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p.arguments = ["SystemUIServer"]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    // MARK: - Natural Scrolling

    static var naturalScrolling: Bool {
        let v = defaultsRead("com.apple.swipescrolldirection", domain: "NSGlobalDomain")
        return v == "true" || v == "1"
    }

    static func setNaturalScrolling(_ on: Bool) {
        runSequence([
            ["/usr/bin/defaults", "write", "NSGlobalDomain", "com.apple.swipescrolldirection",
             "-bool", on ? "true" : "false"],
            ["/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", "-u"],
        ], label: L.t(.naturalScrolling))
    }

    // MARK: - Finder Status Bar

    static var showStatusBar: Bool {
        let v = defaultsRead("ShowStatusBar", domain: "com.apple.finder")
        return v == "true" || v == "1"
    }

    static func setShowStatusBar(_ on: Bool) {
        runSequence([
            ["/usr/bin/defaults", "write", "com.apple.finder", "ShowStatusBar", "-bool", on ? "true" : "false"],
            ["/usr/bin/killall", "Finder"],
        ], label: L.t(.showStatusBar))
    }

    // MARK: - File Extensions

    static var showAllExtensions: Bool {
        let v = defaultsRead("AppleShowAllExtensions", domain: "NSGlobalDomain")
        return v == "true" || v == "1"
    }

    static func setShowAllExtensions(_ on: Bool) {
        runSequence([
            ["/usr/bin/defaults", "write", "NSGlobalDomain", "AppleShowAllExtensions", "-bool", on ? "true" : "false"],
            ["/usr/bin/killall", "Finder"],
        ], label: L.t(.showAllExtensions))
    }

    // MARK: - Maintenance

    /// Flush the DNS resolver cache and restart mDNSResponder.
    static func flushDNSCache() {
        runSequence([
            ["/usr/bin/dscacheutil", "-flushcache"],
            ["/usr/bin/killall", "-HUP", "mDNSResponder"],
        ], label: L.t(.dnsCache))
    }

    static func restartFinder() {
        run(["/usr/bin/killall", "Finder"], label: L.t(.restartFinder))
    }

    /// Best-effort local IPv4 address (Wi-Fi first, then Ethernet).
    static func localIP() -> String? {
        for iface in ["en0", "en1", "en2"] {
            if let ip = runSync(["/usr/sbin/ipconfig", "getifaddr", iface]), !ip.isEmpty {
                return ip
            }
        }
        return nil
    }

    /// Put the display to sleep, which locks the Mac when "require password"
    /// is enabled. CGSession is gone on recent macOS, so pmset is the way.
    static func lockScreen() {
        run(["/usr/bin/pmset", "displaysleepnow"], label: L.t(.lockScreen))
    }
}

/// Manages the long-running `caffeinate` process for the Keep Awake toggle.
final class KeepAwakeManager {
    static let shared = KeepAwakeManager()
    var process: Process?

    /// True only while the child is genuinely alive — a caffeinate that exited
    /// (unplugged, display slept) must not read back as "on".
    var isRunning: Bool {
        return process?.isRunning ?? false
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
