#!/bin/bash
# Captures raw simulator screenshots for the App Store with AppStoreScreenshotUITests.
# Usage: [LANDSCAPE=1] [DISPLAY_ID=<simctl io display>] [MEALIE_URL=… MEALIE_TOKEN=…] capture.sh <iphone|ipad|iphone-duo|iphone-duo-open> <simulator-udid>  <derived-data-dir> [scene ...]
# Needs: `xcodebuild build-for-testing` for the Recipes scheme into <derived-data-dir>, and the `recipes` CLI built (see seed.py).
# The discover and mealie scenes need the demo Mealie servers from mealie-demo.sh.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
set -a; source "$HERE/../../.env"; set +a
device=$1 udid=$2 derived=$3; shift 3
scenes=("$@")
[ ${#scenes[@]} -eq 0 ] && scenes=(home library recipe ingredients cook plan upnext groceries)

raw="$HERE/raw/$device"; mkdir -p "$raw"
lib="$(mktemp -d)/library"

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
# The app remembers which sidebar sections are open, so start from a fresh install.
xcrun simctl uninstall "$udid" "$RECIPES_BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""

# The import scene reads a fictional recipe page served from this machine.
# Bound to the loopback addresses, which win over another process listening on *:8765.
(cd "$HERE/seed/site" && exec python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1) &
server=$!
(cd "$HERE/seed/site" && exec python3 -m http.server 8765 --bind ::1 >/dev/null 2>&1) &
server6=$!
trap 'kill $server $server6 2>/dev/null' EXIT

for scene in "${scenes[@]}"; do
  echo "== $device $scene"
  python3 "$HERE/seed.py" "$lib" >/dev/null   # a fresh library per scene, so one scene's edits never show in another
  rm -f "$raw/$scene.png"
  # Mealie and Discover servers are kept in the keychain, which outlives the app, so each scene starts without them.
  xcrun simctl keychain "$udid" reset
  case "$scene" in
    discover*) link="recipes://discover?server=${MEALIE_URL:-}&token=${MEALIE_TOKEN:-}" ;;
    mealie*) link="recipes://mealie?server=${MEALIE_SYNC_URL:-}&token=${MEALIE_SYNC_TOKEN:-}" ;;
    *) link="" ;;
  esac
  xcrun simctl ui "$udid" appearance "$([[ "$scene" == *-dark ]] && echo dark || echo light)"
  TEST_RUNNER_APP_STORE_SCENE="$scene" TEST_RUNNER_APP_STORE_OUT="$raw" TEST_RUNNER_APP_STORE_LIB="$lib" TEST_RUNNER_APP_STORE_OPEN_URL="$link" \
  TEST_RUNNER_APP_STORE_STYLE="$([ "$device" = ipad ] && echo list || echo cards)" \
  TEST_RUNNER_APP_STORE_LANDSCAPE="${LANDSCAPE:-$([ "$device" = ipad ] && echo 1 || echo 0)}" \
    xcodebuild test-without-building -project "$HERE/../../Recipes.xcodeproj" -scheme Recipes -derivedDataPath "$derived" \
      -destination "id=$udid" -only-testing:RecipesUITests/AppStoreScreenshotUITests/testCapture </dev/null >"$raw/$scene.log" 2>&1 &
  run=$!
  # xcodebuild lingers after the test passes, so stop it once the screenshot is written (or after two minutes).
  for _ in $(seq 120); do [ -f "$raw/$scene.png" ] || ! kill -0 $run 2>/dev/null && break; sleep 1; done
  # The test can only screenshot the main display, which is dark while an iPhone Duo is unfolded.
  [ -n "${DISPLAY_ID:-}" ] && [ -f "$raw/$scene.png" ] && xcrun simctl io "$udid" screenshot --display="$DISPLAY_ID" "$raw/$scene.png" >/dev/null
  sleep 2; kill $run 2>/dev/null || true; wait $run 2>/dev/null || true
  [ -f "$raw/$scene.png" ] || echo "scene $scene failed, see $raw/$scene.log"
  # Landscape captures carry an orientation flag; bake it into the pixels.
  [ -f "$raw/$scene.png" ] && magick "$raw/$scene.png" -auto-orient "$raw/$scene.png"
done
ls "$raw"
