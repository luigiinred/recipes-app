#!/bin/bash
# Captures raw simulator screenshots for the App Store with AppStoreScreenshotUITests.
# Usage: capture.sh <iphone|ipad> <simulator-udid>  <derived-data-dir> [scene ...]
# Needs: `xcodebuild build-for-testing` for the Recipes scheme into <derived-data-dir>, and the `recipes` CLI built (see seed.py).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
device=$1 udid=$2 derived=$3; shift 3
scenes=("$@")
[ ${#scenes[@]} -eq 0 ] && scenes=(home library recipe ingredients cook plan upnext groceries)

raw="$HERE/raw/$device"; mkdir -p "$raw"
lib="$(mktemp -d)/library"
python3 "$HERE/seed.py" "$lib" >/dev/null

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""

# The import scene reads a fictional recipe page served from this machine.
(cd "$HERE/seed/site" && exec python3 -m http.server 8765 >/dev/null 2>&1) &
server=$!
trap 'kill $server 2>/dev/null' EXIT

for scene in "${scenes[@]}"; do
  echo "== $device $scene"
  rm -f "$raw/$scene.png"
  xcrun simctl ui "$udid" appearance "$([[ "$scene" == *-dark ]] && echo dark || echo light)"
  TEST_RUNNER_APP_STORE_SCENE="$scene" TEST_RUNNER_APP_STORE_OUT="$raw" TEST_RUNNER_APP_STORE_LIB="$lib" \
  TEST_RUNNER_APP_STORE_STYLE="$([ "$device" = ipad ] && echo list || echo cards)" \
  TEST_RUNNER_APP_STORE_LANDSCAPE="$([ "$device" = ipad ] && echo 1 || echo 0)" \
    timeout 120 xcodebuild test-without-building -project "$HERE/../../Recipes.xcodeproj" -scheme Recipes -derivedDataPath "$derived" \
      -destination "id=$udid" -only-testing:RecipesUITests/AppStoreScreenshotUITests/testCapture </dev/null >"$raw/$scene.log" 2>&1 || echo "scene $scene failed, see $raw/$scene.log"
  # Landscape captures carry an orientation flag; bake it into the pixels.
  [ -f "$raw/$scene.png" ] && magick "$raw/$scene.png" -auto-orient "$raw/$scene.png"
done
ls "$raw"
