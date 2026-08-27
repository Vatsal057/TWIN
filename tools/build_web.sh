#!/usr/bin/env bash
#
# Builds the Flutter web app and stages the files Firebase Hosting needs.
#
#   ./tools/build_web.sh                      # build only
#   ./tools/build_web.sh --deploy             # build and deploy
#   NAAMKARAN_WEB_HOST=play.example.com ./tools/build_web.sh --deploy
#
# The staging step exists because `flutter build web` does not copy dot-prefixed
# directories out of web/, so the App Links file is kept at web/well-known/ and
# renamed into place here.

set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT:-naamkaran-31493}"
WEB_HOST="${NAAMKARAN_WEB_HOST:-$PROJECT_ID.web.app}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
die()  { printf '\033[31m  ✗ %s\033[0m\n' "$1" >&2; exit 1; }

bold "Building web (host: $WEB_HOST)"
flutter build web --release --dart-define=NAAMKARAN_WEB_HOST="$WEB_HOST" \
  || die "web build failed"
ok "build/web"

bold "Staging .well-known"
if [[ -f web/well-known/assetlinks.json ]]; then
  mkdir -p build/web/.well-known
  cp web/well-known/assetlinks.json build/web/.well-known/assetlinks.json
  ok "assetlinks.json staged"
  info "fingerprint must match the key that signs the APK"
else
  info "no web/well-known/assetlinks.json, skipping"
fi

SIZE="$(du -sh build/web | awk '{print $1}')"
ASSET="$(find build/web -name '*.nkem' -exec du -h {} + 2>/dev/null | awk '{print $1}' | head -1)"
bold "Size"
info "total build/web: $SIZE"
info "embedding asset: ${ASSET:-not found}"

if [[ "${1:-}" == "--deploy" ]]; then
  bold "Deploying to Firebase Hosting"
  firebase deploy --only hosting --project "$PROJECT_ID" || die "deploy failed"
  echo
  ok "live at https://$WEB_HOST"
fi
