import AppKit

/// A single togglable system control.
struct Toggle {
    let id: String
    let title: String
    let symbol: String
    /// Returns the current on/off state.
    let isOn: () -> Bool
    /// Performs the toggle; receives the new intended state.
    let setState: (Bool) -> Void

    func currentState() -> Bool { isOn() }
}
