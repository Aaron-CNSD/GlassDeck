# Glass Deck 🪟✨

**Your Mac, at a glance.** A Liquid Glass control deck for macOS — system toggles, live monitoring, window management, cleanup tools, and desktop widgets, all wrapped in Apple's native refractive glass.

Glass Deck puts your most-used controls into a single, beautiful **Liquid Glass** panel — the same refractive, self-lit glass aesthetic Apple introduced in macOS 26 (Tahoe). Click the menu bar icon (a glass prism), flip a switch, done. It also ships a **desktop widget** so you can flip switches straight from the desktop.

<p align="center">
  <a href="https://aarongame.com">🌐 Website</a> &nbsp;·&nbsp;
  <a href="https://github.com/Aaron-CNSD/GlassDeck/releases">⬇️ Download</a>
</p>

---

## ✨ Why Glass Deck?

There are plenty of "system switch" apps out there (shout-out to [OnlySwitch](https://github.com/jacklandrin/OnlySwitch), the O.G.). Glass Deck is different in a few specific ways:

- **Native `NSGlassEffectView`** on macOS 26+ — real refractive glass with a self-lit rim, rendered by the OS. Not a hand-rolled blur approximation.
- **Graceful fallback** to frosted `NSVisualEffectView` on macOS 14–15.
- **Desktop widgets** (WidgetKit) for quick switch access without opening the app.
- **Five languages** out of the box — English, 简体中文, 繁體中文, 日本語, 한국어.
- **No private APIs.** Everything ships through public AppKit, CoreGraphics, Vision + system commands.

## 🎛️ Features

### System Switches
| Control | Description |
| --- | --- |
| 🌙 Dark Mode | Toggle system-wide dark mode |
| 👁️ Show Hidden Files | Flip Finder's hidden-file visibility |
| 📁 Finder Path Bar | Show/hide the path bar in Finder |
| 🖥️ Hide Desktop Icons | Clean your desktop for screenshots |
| 😴 Keep Awake | Prevent sleep via `caffeinate` |
| 🔇 Mute | Mute/unmute system audio |
| 🚢 Auto-Hide Dock | Auto-hide the Dock |
| 📊 Hide Menu Bar | Hide the menu bar / notch |
| 🖱️ Natural Scrolling | Invert scroll direction |
| 📊 Show Status Bar | Show/hide the Finder status bar |
| 🔤 Show All Extensions | Always show file extensions in Finder |

### Scenes
A scene flips several switches at once. Reachable from the panel **and** the menu bar, so you never have to open the deck for a routine change.

| Scene | What it flips |
| --- | --- |
| 🎬 **Present** | Hide desktop icons · auto-hide Dock · hide menu bar |
| 🌙 **Focus** | Mute · hide desktop icons |
| ✨ **Tidy** | Turn off hidden files, path bar, status bar and extension labels |
| ⏻ **All Off** | Every switch in the deck, off |

The switch list also has an inline **search field**, because scrolling a dozen capsules to find "Natural Scrolling" got old.

### Advanced Tools
| Tab | What it does |
| --- | --- |
| 📈 **Monitor** | Live CPU / memory / network throughput (public `host_statistics` API) |
| 🪟 **Windows** | List running apps, bring to front, or **force quit** — a button macOS doesn't give you |
| 🗑️ **Cleaner** | Scan & clear Xcode DerivedData, Homebrew / CocoaPods / SwiftPM caches, and report freed space |
| 🛠️ **Tools** | Screenshot, screen record, and **clipboard OCR** (Vision framework, returns text to clipboard) |
| ⚡ **Launch** | Pin your favorite URLs / commands / files for one-click launch |

### Desktop Widgets (3 sizes)
A WidgetKit widget with **system small / medium / large** variants — a grid of switches you can flip directly from the desktop, synced with the app via `defaults`.

## 🌍 Localization

Glass Deck auto-detects your system language and supports:

| Code | Language |
| --- | --- |
| `en` | English |
| `zh-Hans` | 简体中文 |
| `zh-Hant` | 繁體中文 |
| `ja` | 日本語 |
| `ko` | 한국어 |

## 🚀 Requirements

- macOS **14.0** or later (Liquid Glass fully activates on **macOS 26+**)
- Apple Silicon or Intel
- Xcode 15+ (or just the Swift toolchain — see below)

## 📦 Installation

### Option 1 — Open in Xcode (full app + widget)

```bash
git clone https://github.com/yourname/GlassDeck.git
cd GlassDeck
# If you have XcodeGen installed:
xcodegen generate
open GlassDeck.xcodeproj
# Otherwise open the Swift package:
open Package.swift
```

Press **⌘R** to build & run. The menu bar icon (glass prism) appears top-right.

> ⚠️ **Widgets require Xcode.** The WidgetKit extension (`.appex`) cannot be built with `swift build` — it needs a full Xcode app-extension target. The `project.yml` (XcodeGen) already declares it; run `xcodegen generate` to produce the project, then ⌘R.

### Option 2 — Command line (app only, no widget)

```bash
cd GlassDeck
./build-app.sh
open build/Glass\ Deck.app
```

## 🏗️ Project Structure

```
GlassDeck/
├── Sources/
│   ├── GlassDeck/               # Main app (AppKit)
│   │   ├── main.swift           # Entry point
│   │   ├── AppDelegate.swift    # Menu bar item + popover + window
│   │   ├── GlassPanel.swift     # Liquid Glass surface (NSGlassEffectView)
│   │   ├── Localization.swift   # 5-language string tables
│   │   ├── SystemController.swift   # System state manipulation
│   │   ├── SystemMonitor.swift      # CPU / memory / network
│   │   ├── WindowController.swift   # Window list / activate / force quit
│   │   ├── DiskCleaner.swift        # Cache scanning & cleanup
│   │   ├── DisplayController.swift  # Resolution / refresh rate
│   │   ├── QuickLaunch.swift        # Pinned shortcuts
│   │   ├── DevTools.swift           # Screenshot / record / OCR
│   │   ├── Toggle.swift / ToggleRowView.swift
│   │   └── DeckViewController.swift # The control deck layout
│   └── Shared/
│       └── WidgetSwitch.swift   # Switch model shared with the widget
├── Widget/                       # WidgetKit extension (3 sizes)
│   ├── GlassDeckWidget.swift
│   ├── GlassDeckWidgetView.swift
│   └── Info.plist
├── Resources/
│   └── AppIcon.appiconset/      # App icon (glass prism)
├── GlassDeck.xcodeproj/         # Xcode project (optional)
├── project.yml                  # XcodeGen spec (main app + widget + shared)
├── Package.swift                # Swift Package (CLI build path)
├── build-app.sh                 # CLI .app assembler
└── LICENSE
```

## 🧠 How the Glass Works

```swift
// GlassPanel.swift (simplified)
if #available(macOS 26.0, *) {
    let glass = NSGlassEffectView()      // real Liquid Glass
    glass.cornerRadius = 24
    glass.tintColor = .controlAccentColor
    glass.contentView = myContent        // content goes HERE, not on the glass
} else {
    let effect = NSVisualEffectView()    // frosted fallback
    effect.material = .hudWindow
    effect.blendingMode = .behindWindow
}
```

The key rule (straight from Apple's guidance): **put content into `contentView`, never `addSubview` directly onto the glass** — that's the only place guaranteed to sit inside the glass layer.

## 🌐 Website

The landing page lives in `website/` and is served from **[aarongame.com](https://aarongame.com)** by a Cloudflare Worker (`aarongame`) with static assets.

```bash
npx wrangler deploy --config deploy/wrangler.jsonc
```

`deploy/worker.js` serves the static files and 301s any retired URL to the homepage, so old inbound links keep their value instead of dying as 404s.

> Note: don't add a `_redirects` file here — on Workers static assets its rules are evaluated *before* asset matching, which redirects the whole site into a loop.

## 🤝 Contributing

Pull requests welcome. Toggles are dead-simple to add — just append a `Toggle` entry in `DeckViewController.swift`:

```swift
Toggle(id: "mynewtoggle", title: L.t(.myNewToggle), symbol: "sparkles",
       isOn: { /* read state */ },
       setState: { /* apply state */ }),
```

And add the matching `L.Key` + translations in `Localization.swift`.

## 📄 License

[MIT](LICENSE) © 2026
