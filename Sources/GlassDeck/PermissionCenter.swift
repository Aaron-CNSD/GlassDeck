import AppKit
import Carbon
import CoreGraphics

/// Whether this app may drive another app with Apple Events.
///
/// This is the single most common reason a switch in Glass Deck "does nothing":
/// macOS silently drops the Apple Event and `osascript` exits non-zero. Nothing
/// in the UI used to tell you that, so every automation-backed feature looked
/// broken. We now ask the system directly.
enum AutomationPermission {
    /// The user (or the system) already allowed it.
    case granted
    /// Never asked yet, or asked and not answered. The system will prompt.
    case needsConsent
    /// The user explicitly denied it in System Settings.
    case denied
    /// The target app is not running, so its status is unknown (-600).
    case unknown

    var isDenied: Bool { self == .denied }
}

enum PermissionCenter {

    // MARK: - Automation (Apple Events)

    /// Query — optionally request — permission to send Apple Events to `bundleID`.
    ///
    /// - Parameter prompt: when true and the state is `.needsConsent`, the system
    ///   shows its "wants to control" dialog. This call blocks until the user
    ///   answers, so never run it on the main thread.
    static func automation(bundleID: String, prompt: Bool = false) -> AutomationPermission {
        var target = AEDesc()
        let bytes = Array(bundleID.utf8)
        let created = bytes.withUnsafeBufferPointer { buf -> OSErr in
            guard let base = buf.baseAddress else { return OSErr(-1) }
            return AECreateDesc(DescType(typeApplicationBundleID), base, bytes.count, &target)
        }
        guard created == noErr else { return .unknown }
        defer { AEDisposeDesc(&target) }

        let status = AEDeterminePermissionToAutomateTarget(
            &target,
            AEEventClass(typeWildCard),
            AEEventID(typeWildCard),
            prompt
        )

        switch status {
        case noErr:                        return .granted
        case -1744:                        return .needsConsent   // errAEEventWouldRequireUserConsent
        case -1743:                        return .denied         // errAEEventNotPermitted
        default:                           return .unknown        // -600 procNotFound etc.
        }
    }

    static let systemEventsBundleID = "com.apple.systemevents"
    static let finderBundleID = "com.apple.finder"

    // MARK: - Screen Recording

    /// True when screencapture / screen recording is allowed for this app.
    static func screenRecording() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Ask the system to add this app to the Screen Recording list. The result
    /// is not immediate — the user has to flip the switch in System Settings.
    @discardableResult
    static func requestScreenRecording() -> Bool {
        return CGRequestScreenCaptureAccess()
    }

    // MARK: - System Settings deep links

    /// Opens the exact privacy pane, so the fix is one click away instead of
    /// "go find it yourself".
    static func openPrivacyPane(_ anchor: String) {
        let url = "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        if let u = URL(string: url) {
            NSWorkspace.shared.open(u)
        }
    }

    static func openAutomationSettings() { openPrivacyPane("Privacy_Automation") }
    static func openScreenRecordingSettings() { openPrivacyPane("Privacy_ScreenCapture") }
}
