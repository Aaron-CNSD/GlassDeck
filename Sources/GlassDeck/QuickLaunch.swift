import AppKit

/// Quick launcher: favorite URLs, commands, and files, launched with one click.
/// Persists favorites to UserDefaults (simple, no external deps).
enum QuickLaunch {

    struct Item: Codable, Equatable {
        enum Kind: String, Codable {
            case url, command, file
        }
        let kind: Kind
        let label: String
        let value: String
    }

    private static let key = "glassdeck.quicklaunch.items"

    static func load() -> [Item] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([Item].self, from: data) else {
            return defaultItems()
        }
        return items
    }

    static func save(_ items: [Item]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func defaultItems() -> [Item] {
        return [
            Item(kind: .url, label: "GitHub", value: "https://github.com"),
            Item(kind: .command, label: "Flush DNS", value: "sudo dscacheutil -flushcache"),
            Item(kind: .url, label: "Google", value: "https://google.com"),
        ]
    }

    /// Execute a launch item.
    static func launch(_ item: Item) {
        switch item.kind {
        case .url:
            if let url = URL(string: item.value) {
                NSWorkspace.shared.open(url)
            }
        case .command:
            let script = """
            tell application "Terminal"
                activate
                do script "\(item.value.replacingOccurrences(of: "\"", with: "\\\""))"
            end tell
            """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        case .file:
            NSWorkspace.shared.open(URL(fileURLWithPath: item.value))
        }
    }
}
