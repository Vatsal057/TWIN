#!/usr/bin/env bash
#
# Provisions the Firebase project TWIN needs for real two-player games.
#
# Run this once, after `firebase login`. Everything it does is idempotent, so
# re-running after a partial failure is safe.
#
#   ./tools/setup_firebase.sh                  # interactive project pick/create
#   ./tools/setup_firebase.sh my-project-id    # use/create a specific project
#
# One step cannot be scripted: enabling Anonymous authentication. The Firebase
# CLI has no command for auth providers, so the script stops and hands you the
# exact console URL at the end.

set -euo pipefail

ANDROID_PACKAGE="com.twinnn.twin"
FIRESTORE_LOCATION="${FIRESTORE_LOCATION:-asia-south1}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$1"; }
die()  { printf '\033[31m  ✗ %s\033[0m\n' "$1" >&2; exit 1; }

# Pulls an app id out of `firebase apps:list`.
#
# That command prints a box-drawn table with │ separators and no package-name
# column, so neither column-splitting nor filtering by package works. Matching
# the app id's own shape (1:<projectNumber>:<platform>:<hash>) is unambiguous
# and survives any table reformatting.
#   $1 platform for the CLI (only ANDROID is used; the project has no Apple targets)
#   $2 platform as it appears inside the app id (android)
app_id_of() {
  firebase apps:list "$1" --project "$PROJECT_ID" 2>/dev/null \
    | grep -oE "1:[0-9]+:$2:[0-9a-zA-Z]+" \
    | head -1 || true
}

# ---------------------------------------------------------------- preflight

bold "Checking tools"

command -v firebase >/dev/null 2>&1 \
  || die "firebase CLI not found. Install it: npm install -g firebase-tools"
ok "firebase $(firebase --version 2>/dev/null | tail -1)"

# An authorized account always prints an email address; "No authorized
# accounts" never does.
if ! firebase login:list 2>/dev/null | grep -q '@'; then
  warn "Not logged in. Opening the browser flow now."
  firebase login || die "login failed"
fi
ok "logged in as $(firebase login:list 2>/dev/null | grep -o '[^ ]*@[^ ]*' | head -1)"

# ------------------------------------------------------------------ project

bold "Selecting project"

PROJECT_ID="${1:-}"

if [[ -z "$PROJECT_ID" ]]; then
  info "Existing projects:"
  firebase projects:list 2>/dev/null | sed 's/^/    /' || true
  printf '\n  Project ID to use (blank to create a new one): '
  read -r PROJECT_ID
fi

if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID="twin-$(date +%s | tail -c 6)"
  info "Creating project $PROJECT_ID"
  firebase projects:create "$PROJECT_ID" --display-name "TWIN" \
    || die "could not create project. Google caps how many projects an account may own; delete an old one or pass an existing project id."
  ok "created $PROJECT_ID"
elif firebase projects:list 2>/dev/null | grep -q "$PROJECT_ID"; then
  ok "using existing $PROJECT_ID"
else
  info "Project $PROJECT_ID not in your list; creating it"
  firebase projects:create "$PROJECT_ID" --display-name "TWIN" \
    || die "could not create or access $PROJECT_ID"
fi

firebase use "$PROJECT_ID" >/dev/null 2>&1 || true

# -------------------------------------------------------------- android app

bold "Registering the Android app"

if [[ -f android/app/google-services.json ]]; then
  ok "android/app/google-services.json already present, leaving it alone"
else
  ANDROID_APP_ID="$(app_id_of ANDROID android)"

  if [[ -z "$ANDROID_APP_ID" ]]; then
    info "Creating Android app for $ANDROID_PACKAGE"
    firebase apps:create ANDROID "TWIN Android" \
      --package-name "$ANDROID_PACKAGE" --project "$PROJECT_ID" >/dev/null \
      || die "could not register the Android app"
    ANDROID_APP_ID="$(app_id_of ANDROID android)"
  fi
  [[ -n "$ANDROID_APP_ID" ]] || die "could not determine the Android app id"
  info "app id $ANDROID_APP_ID"

  firebase apps:sdkconfig ANDROID "$ANDROID_APP_ID" --project "$PROJECT_ID" \
    --out android/app/google-services.json >/dev/null \
    || die "could not download google-services.json"
  ok "wrote android/app/google-services.json"
fi

# No iOS or macOS step: those platform folders were removed from the project, so
# the app ships on Android and the web only. Re-add them with
# `flutter create --platforms=ios .` before registering an Apple app here.

# ---------------------------------------------------------------- firestore

bold "Enabling the Firestore API"

# On a freshly created project firestore.googleapis.com is off, and
# `firestore:databases:create` does not turn it on — it just fails with a 403.
# The CLI caches an OAuth token with cloud-platform scope, which is exactly what
# the console's "Create database" button uses, so enable the API with it.
enable_api() {
  local api="$1"
  local token
  token="$(
    python3 -c "
import json, pathlib
print(json.load(open(pathlib.Path.home() / '.config/configstore/firebase-tools.json'))['tokens']['access_token'])
" 2>/dev/null || true
  )"
  if [[ -z "$token" ]]; then
    warn "could not read the cached CLI token; enable $api by hand:"
    info "https://console.developers.google.com/apis/api/$api/overview?project=$PROJECT_ID"
    return 1
  fi
  local code
  code="$(
    curl -s -o /dev/null -w '%{http_code}' -X POST \
      -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
      -d '{}' \
      "https://serviceusage.googleapis.com/v1/projects/$PROJECT_ID/services/$api:enable"
  )"
  [[ "$code" == "200" ]]
}

if enable_api firestore.googleapis.com; then
  ok "firestore.googleapis.com enabled"
  info "waiting 30s for the enablement to propagate"
  sleep 30
else
  warn "continuing anyway; database creation may fail with a 403"
fi

bold "Creating the Firestore database"

if firebase firestore:databases:list --project "$PROJECT_ID" 2>/dev/null \
    | grep -q "(default)"; then
  ok "default database already exists"
else
  info "Creating in $FIRESTORE_LOCATION (override with FIRESTORE_LOCATION=...)"
  warn "the location is permanent; a database cannot be moved later"
  # Retry: API enablement can take a little while to propagate.
  for attempt in 1 2 3 4 5; do
    if firebase firestore:databases:create "(default)" \
        --location "$FIRESTORE_LOCATION" --project "$PROJECT_ID" 2>&1 | tail -4; then
      :
    fi
    if firebase firestore:databases:list --project "$PROJECT_ID" 2>/dev/null \
        | grep -q "(default)"; then
      ok "database created in $FIRESTORE_LOCATION"
      break
    fi
    [[ $attempt -lt 5 ]] && info "retrying in 25s" && sleep 25
  done
  firebase firestore:databases:list --project "$PROJECT_ID" 2>/dev/null \
    | grep -q "(default)" \
    || warn "could not create it from the CLI. Create Firestore once in the console, then re-run."
fi

# --------------------------------------------------------------- deploy rules

bold "Deploying security rules"

if firebase deploy --only firestore:rules --project "$PROJECT_ID"; then
  ok "firestore.rules deployed"
else
  warn "rules deploy failed. Once Firestore exists, run:"
  info "firebase deploy --only firestore:rules --project $PROJECT_ID"
fi

# ------------------------------------------------------------------- wrap up

echo
bold "One step left, and it genuinely cannot be scripted"
cat <<EOF

  Enable Anonymous sign-in in the console:

    https://console.firebase.google.com/project/$PROJECT_ID/authentication/providers

    Authentication -> Get started -> Anonymous -> Enable

  There is no CLI command for auth providers. The REST alternative
  (identitytoolkit admin/v2 config) belongs to Identity Platform and returns
  BILLING_NOT_ENABLED on the free Spark plan, so do not go looking for a
  scripted route — and do not enable billing just for this. The console's
  "Get started" provisions Firebase Auth on Spark at no cost.

  Without it every client fails to sign in and the app falls back to offline
  practice, exactly as if Firebase were missing.

EOF

bold "Then build for both phones"
cat <<EOF

    flutter build apk --release --split-per-abi

  Install the arm64-v8a APK from build/app/outputs/flutter-apk/ on both
  devices. Both builds must come from this same project or they will each work
  fine and still never see each other.

EOF

ok "project $PROJECT_ID configured"
