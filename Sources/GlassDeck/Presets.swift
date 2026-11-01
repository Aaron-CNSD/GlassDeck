import AppKit

/// A snapshot of the whole switch board, saved under a name the user chose.
///
/// Scenes (`Scenes.swift`) are the four set-ups the app ships with. A preset is
/// the same data shape — toggle id → desired state — with a different author:
/// the person in front of the screen. Which means it needs a name, a date, and
/// a way to be deleted once the experiment is over.
struct Preset: Codable, Equatable {

    var id: String
    var name: String
    /// toggle id → state. Ids that are no longer in `ToggleLibrary` are skipped
    /// on apply, so an old preset never resurrects a switch that was removed.
    var states: [String: Bool]
    var createdAt: Date

    /// How many switches this preset speaks for.
    var switchCount: Int { states.count }
}

/// Persists presets to `UserDefaults` and nothing else.
///
/// Deliberately not a general settings store: the only thing it knows how to do
/// is keep an ordered, bounded list of named snapshots on disk.
final class PresetStore {

    static let shared = PresetStore()

    /// Posted after every add / remove so any open surface can rebuild itself.
    static let changed = Notification.Name("GlassDeckPresetsChanged")

    /// Twelve named set-ups is already more than anyone reaches for, and the
    /// cap keeps the list scrollable and the stored JSON tiny.
    static let limit = 12

    private static let defaultsKey = "GlassDeck.presets.v1"

    private(set) var presets: [Preset] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.presets = Self.decode(defaults.data(forKey: Self.defaultsKey))
    }

    // MARK: - Reads

    func preset(id: String) -> Preset? {
        presets.first { $0.id == id }
    }

    var isFull: Bool { presets.count >= Self.limit }

    /// "Preset 3" — skipping any number already taken, so a deleted name can be
    /// reused without the counter restarting on top of a live preset.
    static func suggestedName(existing: [Preset]) -> String {
        let taken = Set(existing.map { $0.name.lowercased() })
        var index = existing.count + 1
        var candidate = String(format: L.t(.presetDefaultName), index)
        while taken.contains(candidate.lowercased()) {
            index += 1
            candidate = String(format: L.t(.presetDefaultName), index)
        }
        return candidate
    }

    // MARK: - Writes

    /// Stores `states` under `name`.
    ///
    /// A preset that already answers to that name is updated in place instead of
    /// duplicated — pressing save twice after a nudge should not grow the list
    /// with two nearly identical entries.
    @discardableResult
    func save(name: String, states: [String: Bool]) -> Preset? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? Self.suggestedName(existing: presets) : trimmed

        if let index = presets.firstIndex(where: {
            $0.name.compare(finalName, options: .caseInsensitive) == .orderedSame
        }) {
            presets[index].states = states
            presets[index].createdAt = Date()
            commit()
            return presets[index]
        }

        guard !isFull else { return nil }

        let preset = Preset(id: UUID().uuidString,
                            name: finalName,
                            states: states,
                            createdAt: Date())
        presets.append(preset)
        commit()
        return preset
    }

    func remove(id: String) {
        guard presets.contains(where: { $0.id == id }) else { return }
        presets.removeAll { $0.id == id }
        commit()
    }

    func rename(id: String, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = presets.firstIndex(where: { $0.id == id }) else { return false }
        presets[index].name = trimmed
        commit()
        return true
    }

    private func commit() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    private static func decode(_ data: Data?) -> [Preset] {
        guard let data = data else { return [] }
        return (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }

    // MARK: - Live state

    /// Reads every switch and hands back the board as it stands right now.
    ///
    /// Each read shells out to `defaults` / `osascript`, so the whole sweep runs
    /// on a background queue and the answer comes back on the main one.
    static func capture(completion: @escaping ([String: Bool]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var states: [String: Bool] = [:]
            for toggle in ToggleLibrary.all {
                states[toggle.id] = toggle.currentState()
            }
            DispatchQueue.main.async { completion(states) }
        }
    }

    /// Applies `preset`, reporting how many switches actually changed.
    ///
    /// Same read-then-write split as `SceneLibrary.apply`: only switches whose
    /// live value differs are touched, so applying a preset that already matches
    /// costs nothing and Safari does not get relaunched for no reason.
    static func apply(_ preset: Preset, completion: @escaping (Int) -> Void) {
        let targets = preset.states

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
