# Glass Deck Web

A buildless PWA at `/app/`, alongside the existing macOS AppKit app. It works in modern browsers on Windows, Linux, macOS, iOS and iPadOS. Installation depends on the browser; no native Windows, Linux or iOS binaries are included.

## Features

- Focus timer with pause, reset and 5/25/50-minute presets. A persisted wall-clock deadline keeps it accurate after suspension. Sound is best effort while the page is active, not an OS background alarm.
- Task list and autosaved notes, stored locally in the current browser.
- JSON backup export and validated import, with replacement confirmation. No account or automatic cross-device sync. Browser storage may be cleared or unavailable; export important data.
- Length and temperature conversion, text statistics, JSON formatting and clipboard copy.
- Optional screen wake lock where supported, light/dark themes, responsive layout, keyboard-accessible controls.
- Offline application shell cached after a successful first online visit. No external scripts, fonts or analytics.

The web app cannot change system settings, inspect processes, or clean system caches. These remain in the native Mac app.

## Run and verify

```sh
npm test
python3 -m http.server 4173 --directory website
# Open http://localhost:4173/app/
```

No npm install or build step is required. Production must use HTTPS. Deploy the existing Cloudflare Worker with `npx wrangler deploy --config deploy/wrangler.jsonc` only when ready to publish. Static assets live under `website/`.

## Install

- iPhone/iPad: open in Safari, Share, Add to Home Screen.
- Windows/Linux: use Chrome or Edge's install app menu where available.
- macOS: Safari's Add to Dock where available, or Chrome's install app menu.
- Unsupported installation browsers can still use the website online.

Test on real devices before advertising native-equivalent support. Automated tests cover model and asset correctness; browser QA should cover tasks, note persistence, timers, import/export, narrow viewport overflow, service-worker readiness and offline reload. A simulator or browser viewport is not a physical iOS/iPadOS verification.

## Updating offline assets

Bump the `CACHE` name in `website/app/sw.js` whenever app-shell files change. The worker removes only its own older `glassdeck-web-` caches. Existing open pages pick up changes on reload. Site-wide caches and local user data are preserved.

## Optional GitHub Actions

`docs/web-ci.example.yml` contains a workflow example. A repository maintainer can copy it to `.github/workflows/web.yml` to enable checks. It is kept as an example because adding a workflow through GitHub requires separate workflow permissions. Local checks remain available through `npm test`.

## Embedded Mac workspace

From v1.6.0 the macOS app embeds the same workspace using WKWebView. `tools/bundle-workspace.sh` creates classic-script resources to avoid local-file module restrictions. Both the SwiftPM bundle script and Xcode post-build phase package these resources. No loopback server, remote page, private WebKit preferences, or service worker is needed in the native app.

Native export/copy handlers accept only messages from the bundled workspace's main frame, cap payloads at 2 MB, and expose no shell or system-control bridge. File exports require a Save dialog; import uses the system file picker. Remote links open in the default browser. Native and browser storage are separate.
