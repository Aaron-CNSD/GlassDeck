import CoreGraphics
import Foundation

/// Display control: list available resolutions and switch the main display.
/// Uses public CGDisplay APIs + CoreGraphics display mode APIs.
enum DisplayController {

    struct Mode: Equatable {
        let width: Int
        let height: Int
        let refreshRate: Double
        let isNative: Bool

        var label: String {
            "\(width)×\(height) @ \(Int(refreshRate))Hz\(isNative ? " (native)" : "")"
        }
    }

    /// All modes available on the main display.
    static func availableModes() -> [Mode] {
        guard let mainID = CGMainDisplayID() as CGDirectDisplayID? else { return [] }
        guard let modes = CGDisplayCopyAllDisplayModes(mainID, nil) as? [CGDisplayMode] else { return [] }

        var result: [Mode] = []
        var seen = Set<String>()
        for mode in modes {
            let w = mode.width
            let h = mode.height
            let rr = mode.refreshRate
            let key = "\(w)x\(h)@\(rr)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let isNative = (mode.ioFlags & UInt32(kDisplayModeNativeFlag)) != 0
            result.append(Mode(width: w, height: h, refreshRate: rr, isNative: isNative))
        }

        // Sort by pixel count then refresh rate
        result.sort {
            let a = $0.width * $0.height
            let b = $1.width * $1.height
            if a != b { return a > b }
            return $0.refreshRate > $1.refreshRate
        }
        return result
    }

    /// Current mode of the main display.
    static func currentMode() -> Mode? {
        guard let mainID = CGMainDisplayID() as CGDirectDisplayID? else { return nil }
        guard let mode = CGDisplayCopyDisplayMode(mainID) else { return nil }
        let isNative = (mode.ioFlags & UInt32(kDisplayModeNativeFlag)) != 0
        return Mode(width: mode.width, height: mode.height,
                    refreshRate: mode.refreshRate, isNative: isNative)
    }

    /// Switch the main display to the given mode.
    static func switchTo(_ mode: Mode) {
        guard let mainID = CGMainDisplayID() as CGDirectDisplayID? else { return }
        guard let modes = CGDisplayCopyAllDisplayModes(mainID, nil) as? [CGDisplayMode] else { return }
        guard let target = modes.first(where: {
            $0.width == mode.width && $0.height == mode.height && $0.refreshRate == mode.refreshRate
        }) else { return }

        var config: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&config)
        CGConfigureDisplayWithDisplayMode(config, mainID, target, nil)
        CGCompleteDisplayConfiguration(config, .forSession)
    }
}
