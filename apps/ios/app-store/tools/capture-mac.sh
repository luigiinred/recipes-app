#!/bin/bash
# Captures raw Mac window screenshots for the App Store with AppStoreScreenshotMacUITests.
# Run it from a Terminal in your desktop session: the app needs a window server, and the test takes over the mouse for about a minute.
# Usage: capture-mac.sh <derived-data-dir> [scene ...]
# Needs the Mac app built for testing into <derived-data-dir>, ad hoc signed (see APP_STORE.md).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
derived=$1; shift
scenes=("$@")
[ ${#scenes[@]} -eq 0 ] && scenes=(library plan upnext groceries)

raw="$HERE/raw/mac"; mkdir -p "$raw"
lib="$(mktemp -d)/library"
python3 "$HERE/seed.py" "$lib" >/dev/null

for scene in "${scenes[@]}"; do
  echo "== mac $scene"
  rm -f "$raw/$scene.png"
  TEST_RUNNER_APP_STORE_SCENE="$scene" TEST_RUNNER_APP_STORE_LIB="$lib" \
    timeout 150 xcodebuild test-without-building -project "$HERE/../../Recipes.xcodeproj" -scheme Recipes -derivedDataPath "$derived" \
      -destination "platform=macOS" -only-testing:RecipesUITests/AppStoreScreenshotMacUITests/testCapture </dev/null >"$raw/$scene.log" 2>&1 || echo "scene $scene failed, see $raw/$scene.log"
  # The test runner is sandboxed, so it saves into its own temp folder and prints the path.
  shot="$(sed -n 's/.*APP_STORE_SHOT //p' "$raw/$scene.log" | tail -1)"
  [ -n "$shot" ] && [ -f "$shot" ] && magick "$shot" -auto-orient "$raw/$scene.png"
done
ls "$raw"
