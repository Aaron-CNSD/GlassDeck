import AppKit

/// One line in the self-check sheet.
struct DiagnosticResult {
    enum Level {
        case ok
        case warn
        case fail
    }

    /// What the user can do about a problem row.
    enum Fix {
        case automation      // System Settings › Privacy › Automation
        case screenRecording // System Settings › Privacy › Screen Recording
    }

    let title: String
    let detail: String
    let level: Level
    let fix: Fix?
}

/// Runs real probes against the system and reports why a feature would or
/// would not work. Everything here is side-effect free: the preference probes
/// write a throwaway key, read it back, and delete it again.
enum Diagnostics {

    private static func run(_ launchPath: String, _ args: [String]) -> (code: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return (-1, "") }
        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return (p.terminationStatus, String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    /// Write → read → delete a probe key. Returns true only if the whole round
    /// trip worked, which is exactly what every Finder/Dock toggle needs.
    private static func canWritePreferences(domain: String) -> Bool {
        let key = "GlassDeckProbe"
        let token = "probe-\(Int(Date().timeIntervalSince1970))"
        let write = run("/usr/bin/defaults", ["write", domain, key, "-string", token])
        guard write.code == 0 else { return false }
        let read = run("/usr/bin/defaults", ["read", domain, key])
        _ = run("/usr/bin/defaults", ["delete", domain, key])
        return read.code == 0 && read.out == token
    }

    /// Full check list. Blocking (spawns processes) — call off the main thread.
    static func runAll() -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []

        // 1. Required command line tools
        let required = [
            "/usr/bin/defaults", "/usr/bin/killall", "/usr/bin/osascript",
            "/usr/sbin/screencapture", "/usr/bin/caffeinate", "/usr/bin/pmset",
        ]
        let missing = required.filter { !FileManager.default.isExecutableFile(atPath: $0) }
        if missing.isEmpty {
            results.append(DiagnosticResult(
                title: L.t(.checkCommands),
                detail: L.t(.checkCommandsOK),
                level: .ok,
                fix: nil
            ))
        } else {
            results.append(DiagnosticResult(
                title: L.t(.checkCommands),
                detail: missing.joined(separator: ", "),
                level: .fail,
                fix: nil
            ))
        }

        // 2. Preference domains — Finder switches, Dock switch, extension toggle
        results.append(prefsRow(domain: "com.apple.finder", title: L.t(.checkFinderPrefs)))
        results.append(prefsRow(domain: "com.apple.dock", title: L.t(.checkDockPrefs)))
        results.append(prefsRow(domain: "NSGlobalDomain", title: L.t(.checkGlobalPrefs)))

        // 3. Automation → System Events (dark mode)
        results.append(automationRow(
            bundleID: PermissionCenter.systemEventsBundleID,
            title: L.t(.checkSystemEvents)
        ))

        // 4. Automation → Finder (empty trash)
        results.append(automationRow(
            bundleID: PermissionCenter.finderBundleID,
            title: L.t(.checkFinderAutomation)
        ))

        // 5. Screen Recording (screenshot + screen recording)
        let canRecord = PermissionCenter.screenRecording()
        results.append(DiagnosticResult(
            title: L.t(.checkScreenRecording),
            detail: canRecord ? L.t(.granted) : L.t(.needsPermission),
            level: canRecord ? .ok : .warn,
            fix: canRecord ? nil : .screenRecording
        ))

        // 6. activateSettings — needed to apply scroll direction / menu bar prefs
        let activate = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        let hasActivate = FileManager.default.isExecutableFile(atPath: activate)
        results.append(DiagnosticResult(
            title: L.t(.checkActivateSettings),
            detail: hasActivate ? L.t(.granted) : L.t(.needsPermission),
            level: hasActivate ? .ok : .warn,
            fix: nil
        ))

        return results
    }

    private static func prefsRow(domain: String, title: String) -> DiagnosticResult {
        let ok = canWritePreferences(domain: domain)
        return DiagnosticResult(
            title: title,
            detail: ok ? L.t(.granted) : L.t(.prefsHint),
            level: ok ? .ok : .fail,
            fix: nil
        )
    }

    private static func automationRow(bundleID: String, title: String) -> DiagnosticResult {
        switch PermissionCenter.automation(bundleID: bundleID, prompt: false) {
        case .granted:
            return DiagnosticResult(title: title, detail: L.t(.granted), level: .ok, fix: nil)
        case .needsConsent:
            return DiagnosticResult(title: title, detail: L.t(.needsPermission), level: .warn, fix: .automation)
        case .denied:
            return DiagnosticResult(title: title, detail: L.t(.denied), level: .fail, fix: .automation)
        case .unknown:
            // Either the target app is not running yet, or macOS has not been
            // asked. Not a problem: the first real action triggers the prompt.
            return DiagnosticResult(title: title, detail: L.t(.firstUseHint), level: .warn, fix: nil)
        }
    }
}
