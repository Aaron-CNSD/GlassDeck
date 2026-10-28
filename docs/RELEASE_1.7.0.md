# Glass Deck 1.7.0

## One field for everything

- **⌘K opens a command palette.** Every switch, every tool action and every tab in a single list: type three letters, press return, done. The header carries a small `⌘K` chip so the shortcut is discoverable instead of folklore.
- The search is boring on purpose. Exact title beats prefix, prefix beats word prefix, word prefix beats substring, a keyword hit beats a loose subsequence, and ties break on the shorter title. There is no machine learning in a search box with thirty entries.
- **English words find Chinese controls.** Each switch carries its own id plus the words people actually reach for — `dark`, `theme`, `mute`, `trash`, `screenshot`, `clipboard` — so a panel in 简体中文 still answers to `dark`. The right-hand note counts as searchable text too: typing 动作 lists every action, 开关 lists every switch.
- **↑↓ moves, ↩ runs, esc closes, clicking works.** An empty query lists everything, so the palette doubles as a menu for people who have not memorised the deck yet. No results says so in words rather than sitting blank.
- Switch rows show **live state** ("开关 · 已开启"). The palette does not shell out to `defaults`/`osascript` while it opens: it reads the cache that the background refresh already filled, so summoning it is instant even on a cold panel.
- The action list is the Tools tab flattened, not a second implementation — same `SystemController` and `DevTools` calls, same localised titles, same status strip when a permission is missing.
- **⌘1…⌘7** jump straight to a tab, for the keyboard-only crowd.

## Small print

- Nine new interface strings, translated into all five languages (en, zh-Hans, zh-Hant, ja, ko).
- The palette is one local `NSEvent` monitor while the window is key; no global hot key, no event taps, no Accessibility permission.

## Compatibility and packages

- macOS 14 or newer, universal binary (arm64 + x86_64), ad hoc signed, not notarized.
- DMG installer, ZIP app bundle and a SHA256 checksum file.
- The Xcode build embeds the WidgetKit extension; `build-app.sh` (SwiftPM) still ships the app without the widget.

## Validation

- Offscreen layout harness renders the deck at 380 × 780 pt in four palette states — empty query, `dark`, `动作`, and a query with no matches — checking six full rows, no clipped text, an opaque footer that hides the scrolling row underneath, and the empty-state message centred.
- Ranking exercised against live titles and aliases: `dark` → 深色模式, `mute`/`静音` → 静音, `trash` → 清空废纸篓, `clip` → 清空剪贴板, `剪贴板` → tab + OCR + clear, `tab` → all seven tabs, `3` → 窗口.
- Universal release build with the WidgetKit extension, `codesign --verify --deep --strict`, and a launch-and-quit smoke test of the signed bundle.
- `npm test` for the web assets.
