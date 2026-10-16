#!/bin/bash
# Captures raw Mac window screenshots for the App Store with AppStoreScreenshotMacUITests.
# Run it from a Terminal in your desktop session: the app needs a window server, and the test takes over the mouse for about a minute.
# Usage: capture-mac.sh <derived-data-dir> [scene ...]
# Needs the Mac app built for testing into <derived-data-dir>, ad hoc signed (see APP_STORE.md).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
derived=$1; shift
scenes=("$@")
[ ${#scenes[@]} -eq 0 ] && scenes=(library import idea smartplan cleanup cook groceries)

set -a; source "$HERE/../../.env"; set +a
# The app remembers split-view widths and its window frame between runs. Forget the widths, and set the saved frame
# to 1280 x 800 points (2560 x 1600 pixels) just inside the top-left of the screen it last used, clear of the Dock.
# The frame only exists once the app has been run, so on a fresh machine launch it once and quit it first.
python3 -I - <<PY
import plistlib, subprocess, os
domain = os.environ["RECIPES_BUNDLE_ID"]
try:
    prefs = plistlib.loads(subprocess.run(["defaults", "export", domain, "-"], capture_output=True, check=True).stdout)
except subprocess.CalledProcessError:
    prefs = {}
for key, value in prefs.items():
    if key.startswith("NSSplitView"):
        subprocess.run(["defaults", "delete", domain, key], check=True)
    elif key.startswith("NSWindow Frame"):
        sx, sy, sw, sh = (int(v) for v in value.split()[4:8])
        frame = f"{sx + 100} {sy + sh - 100 - 800} 1280 800 {sx} {sy} {sw} {sh}"
        subprocess.run(["defaults", "write", domain, key, "-string", frame], check=True)
PY

raw="$HERE/raw/mac"; mkdir -p "$raw"
lib="$(mktemp -d)/library"

# The import scene reads a fictional recipe page served from this machine.
(cd "$HERE/seed/site" && exec python3 -m http.server 8765 >/dev/null 2>&1) &
server=$!
trap 'kill $server 2>/dev/null' EXIT

for scene in "${scenes[@]}"; do
  echo "== mac $scene"
  python3 "$HERE/seed.py" "$lib" >/dev/null   # a fresh library per scene, so one scene's edits never show in another
  rm -f "$raw/$scene.png"
  TEST_RUNNER_APP_STORE_SCENE="$scene" TEST_RUNNER_APP_STORE_LIB="$lib" \
    xcodebuild test-without-building -project "$HERE/../../Recipes.xcodeproj" -scheme Recipes -derivedDataPath "$derived" \
      -destination "platform=macOS" -only-testing:RecipesUITests/AppStoreScreenshotMacUITests/testCapture </dev/null >"$raw/$scene.log" 2>&1 &
  run=$!
  # xcodebuild lingers after the test passes, so stop it once the screenshot path is printed (or after three minutes).
  for _ in $(seq 180); do grep -q APP_STORE_SHOT "$raw/$scene.log" || ! kill -0 $run 2>/dev/null && break; sleep 1; done
  sleep 2; kill $run 2>/dev/null || true; wait $run 2>/dev/null || true
  # The test runner is sandboxed, so it saves into its own temp folder and prints the path.
  shot="$(sed -n 's/.*APP_STORE_SHOT //p' "$raw/$scene.log" | tail -1)"
  if [ -n "$shot" ] && [ -f "$shot" ]; then magick "$shot" -auto-orient "$raw/$scene.png"; else echo "scene $scene failed, see $raw/$scene.log"; fi
done
ls "$raw"
