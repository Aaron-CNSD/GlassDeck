import WidgetKit
import SwiftUI
import Shared

// MARK: - Timeline Provider

struct SwitchProvider: TimelineProvider {
    func placeholder(in context: Context) -> SwitchEntry {
        SwitchEntry(date: Date(), switches: WidgetSwitches.primary(6))
    }

    func getSnapshot(in context: Context, completion: @escaping (SwitchEntry) -> Void) {
        completion(SwitchEntry(date: Date(), switches: WidgetSwitches.primary(6)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SwitchEntry>) -> Void) {
        let entry = SwitchEntry(date: Date(), switches: WidgetSwitches.primary(6))
        // Refresh every 30 minutes; state is re-read each render.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Entry

struct SwitchEntry: TimelineEntry {
    let date: Date
    let switches: [WidgetSwitch]
}

// MARK: - Widget

@main
struct GlassDeckWidget: Widget {
    let kind: String = "GlassDeckWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwitchProvider()) { entry in
            SwitchPanelView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Switches")
        .description("Flip common system switches right from your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
