# Glass Deck 1.6.2

## Monitor, with a history

- CPU, memory and network each gain a **60-sample history curve**, drawn once per second and right-aligned so the newest sample is always at the right edge.
- The network curve auto-scales against a decaying peak, so one large download does not flatten the following minutes into a straight line at zero.
- Idle machines draw a low, honest line instead of an amplified seismograph: the vertical scale has a fixed floor.
- The tab scrolls, so content can no longer squeeze the cards or clip the last row.

## Top processes

- **Top four processes by CPU** are listed under the graphs, with resident memory and a percentage that turns orange past 50 %.
- The × button asks a GUI app to quit normally (it gets to save) and sends `SIGTERM` to anything without a bundle. A refusal — a process owned by another user, or one that ignores the signal — reports in the status strip instead of pretending to work.
- Sampling runs `ps` on a utility queue every three seconds, and only while the Monitor tab is open. No Accessibility permission, no event taps, no private APIs.

## Rolled up from the 1.6.1 work (not shipped on its own)

- **Clipboard shelf**: the last 60 text clips, pinning, click-to-copy, all stored locally at `~/Library/Application Support/GlassDeck/clipboard.json`. Items a password manager flags as confidential are never recorded.
- Icon-only tab bar with tooltips; seven labelled segments did not fit a 380 pt panel.

## Compatibility and packages

- macOS 14 or newer, universal binary (arm64 + x86_64), ad hoc signed, not notarized.
- DMG installer, ZIP app bundle and a SHA256 checksum file.
- The Xcode build embeds the WidgetKit extension; `build-app.sh` (SwiftPM) still ships the app without the widget.

## Validation

- Offscreen layout harness renders the Monitor tab in a 380 × 780 pt panel after a full minute of real sampling: three curves, four process rows, nothing clipped and no gap in the header.
- `ps` parsing is a pure function and was exercised against live output, including paths containing spaces and `/Applications/Foo.app/Contents/MacOS/Foo`-style commands.
- Universal release build with the WidgetKit extension, signature verification, `npm test` for the web assets.
- Quit was exercised on a real GUI app: the row disappears after the process exits and the list re-reads.
