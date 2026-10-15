#!/usr/bin/env bash
# Archive and upload Recipes (iOS + macOS) to TestFlight.
#
#   xcodegen generate → bump the build number in project.yml → archive + upload
#
# Usage: publish_testflight.sh [PLATFORM] [OPTIONS]
#   ios | macos | all (default)
#   --skip-bump   keep the current build number (reuse it)
#   -q, --quiet   show xcodebuild output only on error
#   -h, --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Recipes"
PROJECT="${APP_NAME}.xcodeproj"
SCHEME="$APP_NAME"
PROJECT_YML="project.yml"
BUILD_DIR="./build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"

PLATFORM="all"
SKIP_BUMP=false
QUIET=false

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    ios|macos|all) PLATFORM="$1"; shift ;;
    --skip-bump)   SKIP_BUMP=true; shift ;;
    -q|--quiet)    QUIET=true;    shift ;;
    -h|--help)     usage ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

step() { echo "==> $*"; }
die()  { echo "❌ $*" >&2; exit 1; }

require_env() {
  [[ -f .env ]] || die "missing .env (copy .env.example and fill it in)"
  set -a; source .env; set +a
  for var in RECIPES_TEAM_ID RECIPES_BUNDLE_ID RECIPES_ICLOUD_CONTAINER ASC_KEY_ID ASC_ISSUER_ID; do
    [[ -n "${!var:-}" ]] || die ".env must set $var"
  done
  TEAM_ID="$RECIPES_TEAM_ID"
  local key_path="$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8"
  [[ -f "$key_path" ]] || die "missing App Store Connect API key at $key_path"

  AUTH_ARGS=(
    -allowProvisioningUpdates
    -authenticationKeyPath "$key_path"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
}

# The single source of truth for the build number is project.yml (the xcodeproj is
# generated from it and is gitignored). XcodeGen injects CURRENT_PROJECT_VERSION as a
# build setting, and the Info.plists reference it as $(CURRENT_PROJECT_VERSION).
current_build_number() {
  sed -nE 's/.*CURRENT_PROJECT_VERSION: *"([0-9]+)".*/\1/p' "$PROJECT_YML" | head -1
}

set_build_number() {
  local n="$1"
  sed -i '' -E "s/(CURRENT_PROJECT_VERSION: *\")[0-9]*(\")/\1${n}\2/" "$PROJECT_YML"
}

bump_build_number() {
  local cur; cur="$(current_build_number)"
  [[ -n "$cur" ]] || die "could not read CURRENT_PROJECT_VERSION from $PROJECT_YML"
  if $SKIP_BUMP; then
    step "Keeping build number: $cur"
    return
  fi
  local new=$((cur + 1))
  step "Build number: $cur -> $new (project.yml)"
  set_build_number "$new"
}

ensure_project() {
  command -v xcodegen >/dev/null || die "xcodegen not installed (brew install xcodegen)"
  step "Generating $PROJECT (xcodegen)"
  xcodegen generate
}

run_xcodebuild() {
  if $QUIET; then
    local log; log="$(mktemp)"
    if ! xcodebuild "$@" >"$log" 2>&1; then
      echo ""
      echo "--- Last 30 lines ---"
      tail -30 "$log"
      rm -f "$log"
      return 1
    fi
    rm -f "$log"
  else
    xcodebuild "$@"
  fi
}

# Both platforms sign with cloud-managed automatic signing + the App Store Connect
# API key (no match profiles). DEVELOPMENT_TEAM is passed explicitly because it also
# reaches the SwiftPM package targets, which otherwise fail under automatic signing.
archive_and_upload() {
  local platform="$1" destination="$2" export_plist="$3"
  shift 3
  local extra_args=("$@")
  local archive_path="${BUILD_DIR}/${APP_NAME}-${platform}.xcarchive"

  [[ -f "$export_plist" ]] || die "missing $export_plist"
  mkdir -p "$BUILD_DIR"
  local resolved_plist="${BUILD_DIR}/$(basename "$export_plist")"
  cp "$export_plist" "$resolved_plist"
  /usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" "$resolved_plist"

  step "Archiving for ${platform}..."
  run_xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "$destination" \
    -archivePath "$archive_path" \
    -derivedDataPath "$DERIVED_DATA" \
    "${AUTH_ARGS[@]}" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    ${extra_args[@]+"${extra_args[@]}"}

  step "Uploading ${platform} to TestFlight..."
  run_xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportOptionsPlist "$resolved_plist" \
    "${AUTH_ARGS[@]}"

  step "${platform} upload complete ✓"
}

# --- Main ---------------------------------------------------------------------

if pgrep -xq "$APP_NAME"; then
  step "Killing running $APP_NAME..."
  killall "$APP_NAME" 2>/dev/null || true
  sleep 0.5
fi

require_env
bump_build_number
ensure_project

STARTED_AT=$SECONDS

case "$PLATFORM" in
  ios)
    archive_and_upload "iOS" "generic/platform=iOS" "ExportOptions.plist"
    ;;
  macos)
    archive_and_upload "macOS" "generic/platform=macOS" "ExportOptionsMacOS.plist"
    ;;
  all)
    archive_and_upload "iOS" "generic/platform=iOS" "ExportOptions.plist"
    archive_and_upload "macOS" "generic/platform=macOS" "ExportOptionsMacOS.plist"
    ;;
esac

ELAPSED=$(( SECONDS - STARTED_AT ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
step "Done! Deployed ${PLATFORM} to TestFlight in ${MINS}m ${SECS}s"
