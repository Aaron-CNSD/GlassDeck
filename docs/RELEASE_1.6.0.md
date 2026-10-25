# Glass Deck 1.6.0

## Built in workspace

- Switch between the existing system controls and the new Workspace in the same Mac application window.
- Open Workspace from the menu bar's right-click menu.
- Focus timer, task list, notes, length/temperature conversion, text statistics and JSON formatting are included in the app bundle and work without a network connection.
- Import backups using a native file picker; export JSON backups and TXT notes using native Save dialogs.
- Native copy uses the macOS clipboard after the user's Copy action.
- Workspace and browser data are stored separately. Use backup export/import to transfer records. The workspace UI currently uses Simplified Chinese; native system controls keep the existing five languages.

## Compatibility and packages

- macOS 14 or newer.
- Universal binary: Apple Silicon arm64 and Intel x86_64. Built and interactively tested on Apple Silicon; Intel and macOS 14 hardware were not available for runtime testing.
- DMG installer and ZIP app bundle.
- Ad hoc signed; not Apple notarized.
- The existing SwiftPM build does not bundle the optional WidgetKit extension. Build the Xcode project for a signed widget extension.
- Windows, Linux, iOS and iPadOS users can continue using https://aarongame.com/app/ in a modern browser. These assets are Mac apps, not native builds for the other platforms.

## Validation

- 11 Node tests cover timer recovery, backup validation, conversions, asset scope, deployment routes and native resource bundling.
- Universal release build and code-signature verification.
- Interactive checks cover system/workspace switching, notes retained across app launches, and TXT export contents through the macOS Save panel.
- Device sleep/app exit does not provide a background alarm guarantee. User records stay on this device and do not sync automatically.
