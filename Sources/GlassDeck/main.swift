import AppKit

// MARK: - Application Entry Point
// GlassDeck — a Liquid Glass macOS menu bar control deck.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
