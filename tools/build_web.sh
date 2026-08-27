#!/usr/bin/env bash
#
# Builds the Flutter web app and stages the files Firebase Hosting needs.
#
#   ./tools/build_web.sh                      # build only
#   ./tools/build_web.sh --deploy             # build and deploy
#   TWIN_WEB_HOST=play.example.com ./tools/build_web.sh --deploy
#
# The staging step exists because `flutter build web` does not copy dot-prefixed
# directories out of web/, so the App Links file is kept at web/well-known/ and
# renamed into place here.

set -euo pipefail

# The project ID is immutable and still carries the old name; it is invisible to
# players. HOSTING_SITE is the user-visible half, and is a separate Hosting site
# inside that same project, which is why the host could be renamed without
# migrating any data. Keep it in step with "site" in firebase.json.
PROJECT_ID="${FIREBASE_PROJECT:-naamkaran-31493}"
HOSTING_SITE="${FIREBASE_HOSTING_SITE:-twinnn}"
WEB_HOST="${TWIN_WEB_HOST:-$HOSTING_SITE.web.app}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
die()  { printf '\033[31m  ✗ %s\033[0m\n' "$1" >&2; exit 1; }

bold "Building web (host: $WEB_HOST)"
# --pwa-strategy=none disables the service worker on purpose.
#
# Flutter's default service worker caches the whole app and keeps serving the old
# build after a deploy: the new worker installs but the previous one stays in
# charge until every tab of the site is closed. A reload, even a hard one, shows
# stale UI. That is a bad trade for a game that needs the network to play anyway.
#
# The flag is deprecated (flutter/flutter#156910) and prints a warning. The check
# below verifies the outcome instead of trusting the flag, so when it eventually
# disappears this fails loudly rather than silently shipping a worker again.
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=TWIN_WEB_HOST="$WEB_HOST" \
  || die "web build failed"
ok "build/web"

bold "Checking no service worker got registered"
# Two independent signals, checked because the flag that suppresses the worker is
# deprecated and a future SDK could quietly start emitting one again.
#
# Do NOT grep flutter_bootstrap.js for "serviceWorkerVersion" — that string is
# part of the minified loader library and is present either way. The generated
# tail of the file is what matters: with the worker disabled it reads
# `_flutter.loader.load();` with no arguments, and Flutter writes a 0-byte
# placeholder for flutter_service_worker.js.
sw_bytes="$(wc -c < build/web/flutter_service_worker.js 2>/dev/null | tr -d ' ')"
if [[ "${sw_bytes:-1}" != "0" ]]; then
  die "Flutter emitted a real service worker (${sw_bytes} bytes).
     Users would be pinned to a stale build after every deploy. The
     --pwa-strategy=none flag is deprecated (flutter/flutter#156910); find the
     current way to disable it before shipping."
fi
if grep -q 'serviceWorkerVersion:"' build/web/flutter_bootstrap.js 2>/dev/null; then
  die "flutter_bootstrap.js registers a service worker with a real version."
fi
ok "no worker generated, bootstrap registers none"

bold "Staging .well-known"
if [[ -f web/well-known/assetlinks.json ]]; then
  mkdir -p build/web/.well-known
  cp web/well-known/assetlinks.json build/web/.well-known/assetlinks.json
  ok "assetlinks.json staged"
  info "fingerprint must match the key that signs the APK"
else
  info "no web/well-known/assetlinks.json, skipping"
fi

bold "Staging service worker kill switch"
# --pwa-strategy=none leaves an empty flutter_service_worker.js behind. An empty
# worker stops caching, but it does not evict the old one: by default a new
# worker waits until every tab closes before taking over, so returning visitors
# stay on a stale build.
#
# Overwrite it with a worker that deletes the caches, unregisters itself and
# reloads open tabs. It must keep this exact filename, because that is the URL
# browsers already have registered. Cannot live in web/ — Flutter overwrites it.
if [[ -f tools/sw_killswitch.js ]]; then
  cp tools/sw_killswitch.js build/web/flutter_service_worker.js
  ok "kill switch staged ($(wc -c < build/web/flutter_service_worker.js | tr -d ' ') bytes)"
else
  die "tools/sw_killswitch.js missing"
fi

bold "Size"
info "total build/web: $(du -sh build/web | awk '{print $1}')"
info "main.dart.js gzipped: $(gzip -c build/web/main.dart.js | wc -c | awk '{printf "%.2f MB", $1/1048576}')"

if [[ "${1:-}" == "--deploy" ]]; then
  bold "Deploying to Firebase Hosting (site: $HOSTING_SITE)"
  # The site is named explicitly because the project holds more than one, and a
  # bare `--only hosting` would be ambiguous.
  firebase deploy --only "hosting:$HOSTING_SITE" --project "$PROJECT_ID" \
    || die "deploy failed"
  echo
  ok "live at https://$WEB_HOST"
fi
