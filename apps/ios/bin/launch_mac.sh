#!/usr/bin/env bash
# Build (and optionally launch) Recipes for macOS.
#
# `--build-only` is the release compile check: it disables code signing so it needs no
# certificates or profiles, and it runs before any build number is consumed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Recipes"
PROJECT="${APP_NAME}.xcodeproj"
SCHEME="$APP_NAME"
DERIVED_DATA="./build"
CONFIG="Debug"
DESTINATION="platform=macOS"

CLEAN=false
BUILD=true
LAUNCH=true
QUIET=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build and launch ${APP_NAME} for macOS (debug, unsigned).

Options:
  -c, --clean       Clean the build folder before building
  -b, --build-only  Build without launching
  -r, --run-only    Launch the most recent build without rebuilding
  -q, --quiet       Show xcodebuild output only on error
  -h, --help        Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--clean)      CLEAN=true;  shift ;;
    -b|--build-only) LAUNCH=false; shift ;;
    -r|--run-only)   BUILD=false;  shift ;;
    -q|--quiet)      QUIET=true;   shift ;;
    -h|--help)       usage ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

step() { echo "==> $*"; }

generate_project() {
  command -v xcodegen >/dev/null || { echo "❌ xcodegen not installed (brew install xcodegen)" >&2; exit 1; }
  step "Generating project (xcodegen)"
  "$SCRIPT_DIR/generate.sh"
}

kill_running() {
  if pgrep -xq "$APP_NAME"; then
    step "Killing running $APP_NAME..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 0.5
  fi
}

build_app() {
  step "Building $APP_NAME (${CONFIG}, macOS, unsigned)..."

  local xcode_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIG"
    -destination "$DESTINATION"
    -derivedDataPath "$DERIVED_DATA"
    CODE_SIGN_IDENTITY="-"
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=NO
    build
  )

  if $QUIET; then
    if ! xcodebuild "${xcode_args[@]}" 2>&1 | tail -30; then
      echo "❌ Build failed. Re-run without --quiet for full output."
      return 1
    fi
  else
    xcodebuild "${xcode_args[@]}"
  fi

  step "Build succeeded ✓"
}

launch_app() {
  local app="$DERIVED_DATA/Build/Products/${CONFIG}/${APP_NAME}.app"
  if [[ ! -d "$app" ]]; then
    echo "❌ App bundle not found at: $app"
    echo "   Run without --run-only to build first."
    exit 1
  fi
  step "Launching $APP_NAME..."
  open "$app"
}

generate_project
kill_running

if $CLEAN; then
  rm -rf "$DERIVED_DATA"
fi

if $BUILD; then
  build_app
fi

if $LAUNCH; then
  launch_app
fi
