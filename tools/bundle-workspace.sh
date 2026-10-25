#!/bin/bash
# Bundle the existing web workspace without Node dependencies or a web server.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:?Usage: bundle-workspace.sh destination-directory}"
mkdir -p "$DEST"
cp "$ROOT/website/app/style.css" "$ROOT/website/app/icon.svg" "$ROOT/website/app/icon-192.png" "$DEST/"
# A classic script avoids file-origin ES module restrictions in WKWebView.
{
  echo '(function () {'
  echo '"use strict";'
  sed 's/^export //' "$ROOT/website/app/model.mjs"
  sed '1{/^import /d;}' "$ROOT/website/app/app.mjs"
  echo '})();'
} > "$DEST/workspace.js"
sed 's#<script type="module" src="./app.mjs"></script>#<script src="./workspace.js"></script>#; /rel="manifest"/s#<link rel="manifest" href="./manifest.webmanifest">##' "$ROOT/website/app/index.html" > "$DEST/index.html"
