import AppKit

/// Wraps the actual macOS system state manipulation.
///
/// Most toggles shell out to system defaults / AppleScript because those are
/// the only public, App-Sandbox-friendly ways to flip many system prefs.
enum SystemController {

    // MARK: - Helpers

    private static func run(_ args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        try? process.run()
        process.waitUntilExit()
    }

    private static func defaultsRead(_ key: String, domain: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", domain, key]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func defaultsWrite(_ key: String, value: String, domain: String) {
        run(["/usr/bin/defaults", "write", domain, key, value])
    }

    private static func osascript(_ source: String) {
        run(["/usr/bin/osascript", "-e", source])
    }

    // MARK: - Dark Mode

    static var isDarkMode: Bool {
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func setDarkMode(_ on: Bool) {
        let mode = on ? "dark" : "light"
        osascript("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
        _ = mode
    }

    // MARK: - Hidden Files (Finder)

    static var showHiddenFiles: Bool {
        return defaultsRead("AppleShowAllFiles", domain: "com.apple.finder") == "YES" ||
               defaultsRead("AppleShowAllFiles", domain: "com.apple.finder") == "1"
    }

    static func setShowHiddenFiles(_ on: Bool) {
        defaultsWrite("AppleShowAllFiles", value: on ? "YES" : "NO", domain: "com.apple.finder")
        run(["/usr/bin/killall", "Finder"])
    }

    // MARK: - Show Path Bar in Finder

    static var showPathBar: Bool {
        return defaultsRead("ShowPathbar", domain: "com.apple.finder") == "YES" ||
               defaultsRead("ShowPathbar", domain: "com.apple.finder") == "1"
    }

    static func setShowPathBar(_ on: Bool) {
        defaultsWrite("ShowPathbar", value: on ? "YES" : "NO", domain: "com.apple.finder")
        run(["/usr/bin/killall", "Finder"])
    }

    // MARK: - Hide Desktop Icons

    static var hideDesktopIcons: Bool {
        return defaultsRead("CreateDesktop", domain: "com.apple.finder") == "false" ||
               defaultsRead("CreateDesktop", domain: "com.apple.finder") == "0"
    }

    static func setHideDesktopIcons(_ on: Bool) {
        // CreateDesktop = false hides icons
        defaultsWrite("CreateDesktop", value: on ? "false" : "true", domain: "com.apple.finder")
        run(["/usr/bin/killall", "Finder"])
    }

    // MARK: - Keep Awake (caffeinate)

    static func setKeepAwake(_ on: Bool) {
        if on {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            process.arguments = ["-d", "-i", "-m", "-s"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            // Store the process reference so we can kill it later.
            KeepAwakeManager.shared.process = process
        } else {
            KeepAwakeManager.shared.stop()
        }
    }

    static var isKeepAwake: Bool {
        return KeepAwakeManager.shared.process != nil
    }

    // MARK: - Mute

    static var isMuted: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "output muted of (get volume settings)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return out == "true"
    }

    static func setMuted(_ on: Bool) {
        osascript("set volume output muted \(on)")
    }

    // MARK: - Auto-Hide Dock

    static var autoHideDock: Bool {
        return defaultsRead("autohide", domain: "com.apple.dock") == "1" ||
               defaultsRead("autohide", domain: "com.apple.dock") == "true"
    }

    static func setAutoHideDock(_ on: Bool) {
        defaultsWrite("autohide", value: on ? "1" : "0", domain: "com.apple.dock")
        run(["/usr/bin/killall", "Dock"])
    }

    // MARK: - Empty Trash

    static func emptyTrash() {
        osascript("tell application \"Finder\" to empty trash")
    }

    // MARK: - Empty Clipboard

    static func emptyClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
    }

    // MARK: - Screen Saver (start now)

    static func startScreenSaver() {
        run(["/usr/bin/open", "-a", "ScreenSaverEngine"])
    }

    // MARK: - Hide Notch / Menu Bar

    static var hideMenuBar: Bool {
        return defaultsRead("_HIHideMenuBar", domain: "com.apple.finder") == "true" ||
               defaultsRead("AppleMenuBarVisibleInFullscreen", domain: "NSGlobalDomain") == "0"
    }

    static func setHideMenuBar(_ on: Bool) {
        defaultsWrite("AppleMenuBarVisibleInFullscreen", value: on ? "0" : "1", domain: "NSGlobalDomain")
        run(["/usr/bin/killall", "Finder"])
    }

    // MARK: - Natural Scrolling

    static var naturalScrolling: Bool {
        let v = defaultsRead("com.apple.swipescrolldirection", domain: "NSGlobalDomain")
        return v == "true" || v == "1"
    }

    static func setNaturalScrolling(_ on: Bool) {
        defaultsWrite("com.apple.swipescrolldirection", value: on ? "true" : "false", domain: "NSGlobalDomain")
        run(["/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", "-u"])
    }
}

/// Manages the long-running `caffeinate` process for the Keep Awake toggle.
final class KeepAwakeManager {
    static let shared = KeepAwakeManager()
    var process: Process?

    func stop() {
        process?.terminate()
        process = nil
    }
}
