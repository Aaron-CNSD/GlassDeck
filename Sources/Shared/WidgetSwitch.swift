import Foundation

/// A system switch that both the main app and the widget can toggle.
/// The widget runs in a separate process, so it flips these via `defaults`
/// commands — the exact same keys the main app reads, so state stays in sync.
public struct WidgetSwitch: Identifiable {
    public let id: String
    public let symbol: String
    /// The `defaults` domain this switch lives in.
    public let domain: String
    /// The `defaults` key.
    public let key: String
    /// The value written when the switch is "on".
    public let onValue: String
    /// The value written when the switch is "off".
    public let offValue: String

    public init(id: String, symbol: String, domain: String, key: String, onValue: String, offValue: String) {
        self.id = id
        self.symbol = symbol
        self.domain = domain
        self.key = key
        self.onValue = onValue
        self.offValue = offValue
    }

    /// Read the current on/off state by querying `defaults`.
    public var isOn: Bool {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", domain, key]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match against on-value heuristics (booleans, "1", or the onValue string).
        if let out = out {
            let lower = out.lowercased()
            if lower == "1" || lower == "true" || lower == "yes" { return true }
            if lower == "0" || lower == "false" || lower == "no" { return false }
            return lower == onValue.lowercased()
        }
        return false
    }

    /// Flip the switch by writing the target value via `defaults`.
    public func set(_ on: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["write", domain, key, on ? onValue : offValue]
        task.launch()
        task.waitUntilExit()
        // Some switches need the responsible app to notice the change.
        notify()
    }

    private func notify() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        // Notify Finder / SystemUIServer for icon / appearance changes.
        task.arguments = ["Finder"]
        task.launch()
        task.waitUntilExit()
    }
}

/// The curated set of switches exposed in the widget.
public enum WidgetSwitches {
    public static let all: [WidgetSwitch] = [
        WidgetSwitch(id: "darkmode", symbol: "moon.fill",
                     domain: "Apple Global Domain", key: "AppleInterfaceStyle",
                     onValue: "Dark", offValue: "Light"),
        WidgetSwitch(id: "hiddenfiles", symbol: "eye.slash.fill",
                     domain: "com.apple.finder", key: "AppleShowAllFiles",
                     onValue: "true", offValue: "false"),
        WidgetSwitch(id: "pathbar", symbol: "point.topleft.down.curvedto.point.bottomright.up",
                     domain: "com.apple.finder", key: "ShowPathbar",
                     onValue: "true", offValue: "false"),
        WidgetSwitch(id: "desktopicons", symbol: "desktopcomputer",
                     domain: "com.apple.finder", key: "CreateDesktop",
                     onValue: "false", offValue: "true"),
        WidgetSwitch(id: "autohidedock", symbol: "dock.rectangle",
                     domain: "com.apple.dock", key: "autohide",
                     onValue: "true", offValue: "false"),
        WidgetSwitch(id: "scroll", symbol: "arrow.up.arrow.down",
                     domain: "com.apple.swipescrolldirection", key: "scrollDirection",
                     onValue: "true", offValue: "false"),
    ]

    public static func primary(_ count: Int = 6) -> [WidgetSwitch] {
        Array(all.prefix(count))
    }
}
