import AppKit

/// A named bundle of switch positions that can be applied in one shot.
///
/// Scenes exist because the deck now holds a dozen switches, and the common
/// jobs — "I'm presenting", "I need quiet", "put my desktop back" — are always
/// the same three or four flips in the same order. A scene is just data: it
/// names toggle ids and the state each one should end up in.
struct Scene {
    let id: String
    let titleKey: L.Key
    let symbol: String
    /// toggle id → desired state. Ids that are not in `ToggleLibrary` are ignored.
    let states: [String: Bool]

    var title: String { L.t(titleKey) }
}

enum SceneLibrary {

    /// The built-in scenes, in the order they appear in the deck.
    static var all: [Scene] {
        [
            Scene(id: "present",
                  titleKey: .scenePresentation,
                  symbol: "person.crop.rectangle",
                  // Clear the stage: no desktop clutter, no Dock, no menu bar.
                  states: [
                    "desktopicons": true,
                    "autohidedock": true,
                    "menubar": true
                  ]),

            Scene(id: "focus",
                  titleKey: .sceneFocus,
                  symbol: "moon.stars.fill",
                  // Quiet down without touching anything structural.
                  states: [
                    "mute": true,
                    "desktopicons": true
                  ]),

            Scene(id: "tidy",
                  titleKey: .sceneTidy,
                  symbol: "sparkles",
                  // Turn off every switch that adds extra chrome to Finder.
                  states: [
                    "hiddenfiles": false,
                    "pathbar": false,
                    "statusbar": false,
                    "extensions": false
                  ]),

            Scene(id: "alloff",
                  titleKey: .sceneAllOff,
                  symbol: "power",
                  states: everythingOff())
        ]
    }

    static func scene(id: String) -> Scene? {
        all.first { $0.id == id }
    }

    /// Every switch in the library, all off.
    private static func everythingOff() -> [String: Bool] {
        var map: [String: Bool] = [:]
        for toggle in ToggleLibrary.all { map[toggle.id] = false }
        return map
    }

    /// Applies `scene`, reporting how many switches actually changed.
    ///
    /// Reading state shells out to `defaults` / `osascript` and can take tens
    /// of milliseconds per switch, so the reads happen on a background queue.
    /// The writes are already asynchronous inside `SystemController`, so they
    /// are fired from the main queue without blocking.
    static func apply(_ scene: Scene, completion: @escaping (Int) -> Void) {
        let targets = scene.states

        DispatchQueue.global(qos: .userInitiated).async {
            var pending: [(Toggle, Bool)] = []
            for toggle in ToggleLibrary.all {
                guard let desired = targets[toggle.id] else { continue }
                if toggle.currentState() != desired {
                    pending.append((toggle, desired))
                }
            }

            DispatchQueue.main.async {
                for (toggle, desired) in pending {
                    toggle.setState(desired)
                }
                completion(pending.count)
            }
        }
    }
}
