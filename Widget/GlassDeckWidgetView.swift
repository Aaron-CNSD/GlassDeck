import WidgetKit
import SwiftUI
import Shared
import AppIntents

/// The widget's switch panel: a grid of tappable system toggles that adapt
/// to the three widget sizes (small / medium / large).
struct SwitchPanelView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SwitchEntry

    private var columns: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 3
        case .systemLarge: return 2
        @unknown default: return 2
        }
    }

    private var visibleSwitches: [WidgetSwitch] {
        switch family {
        case .systemSmall: return Array(entry.switches.prefix(4))
        case .systemMedium: return Array(entry.switches.prefix(6))
        case .systemLarge: return Array(entry.switches.prefix(6))
        @unknown default: return Array(entry.switches.prefix(6))
        }
    }

    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                Text("Quick Switches")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(visibleSwitches) { sw in
                    SwitchCell(sw: sw)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

/// A single tappable switch cell. State is read fresh on every render
/// (widgets are snapshots), and tapping fires the toggle intent.
struct SwitchCell: View {
    let sw: WidgetSwitch

    var body: some View {
        Button(intent: ToggleSwitchIntent(id: sw.id)) {
            let isOn = sw.isOn
            VStack(spacing: 6) {
                Image(systemName: sw.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(shortTitle(sw.id))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.fill.tertiary))
            )
        }
        .buttonStyle(.plain)
    }

    private func shortTitle(_ id: String) -> String {
        switch id {
        case "darkmode": return "Dark"
        case "hiddenfiles": return "Hidden"
        case "pathbar": return "Path"
        case "desktopicons": return "Desktop"
        case "autohidedock": return "Dock"
        case "scroll": return "Scroll"
        default: return id
        }
    }
}

// MARK: - App Intent (tapping a cell opens Glass Deck to apply the toggle)

struct ToggleSwitchIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Switch"
    static var description = IntentDescription("Flip a system switch.")
    /// Widget extensions run sandboxed and cannot spawn `defaults` processes,
    /// so hand control to the main app, which applies the change.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Switch ID")
    var id: String

    init() { self.id = "" }
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        // Record the requested switch so the app can apply it on activation.
        UserDefaults.standard.set(id, forKey: "GlassDeck.pendingWidgetToggle")
        return .result()
    }
}
