#!/bin/bash
# Records simulator video of the app for the App Store preview videos, one paced UI-test scene at a time.
# Usage: record.sh <iphone|ipad> <simulator-udid> <derived-data-dir> <scene ...>   (scenes: import plan smartplan cleanup cook)
# Needs the same build-for-testing as capture.sh (with the TimerWidget extension removed). Writes preview/footage/raw/<device>/<scene>.mov and .log.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
set -a; source "$HERE/../../.env"; set +a
device=$1 udid=$2 derived=$3; shift 3
raw="$HERE/../preview/footage/raw/$device"; mkdir -p "$raw"

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
[ "${KEEP_APP:-}" ] || [ "$1" = share ] || xcrun simctl uninstall "$udid" "$RECIPES_BUNDLE_ID" 2>/dev/null || true
xcrun simctl spawn "$udid" launchctl unsetenv RECIPES_DIR 2>/dev/null || true
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""
xcrun simctl ui "$udid" appearance light

# Safari on the recipe page: close the site's banner, share to "Save to Recipes" from the toolbar, review, save, and open the recipe.
SHARE_TAPS="w:1;t:0.926,0.167;w:2;m:page;t:0.495,0.946;w:2.5;m:sheet;t:0.61,0.76;w:15;m:review;t:0.905,0.12;w:4;m:saved;t:0.5,0.634;w:6;m:opened;d:0.5,0.8,0.5,0.3;w:0.6;d:0.5,0.8,0.5,0.3;w:0.6;d:0.5,0.8,0.5,0.35;w:2.5;m:scrolled;w:1"

for scene in "$@"; do
  echo "== $device $scene"
  lib="$(mktemp -d)/library"
  # Every clip but the share one starts with the web-imported lasagna in the library; the share clip adds it.
  APP_PREVIEW_SPARSE=$([[ "$scene" == plan || "$scene" == smartplan ]] && echo 1) \
  APP_PREVIEW_LASAGNA=$([[ "$scene" != share && "$scene" != safarisettings ]] && echo 1) \
  APP_PREVIEW_MESSY=$([[ "$scene" == cleanup ]] && echo 1) \
  APP_PREVIEW_WEEK=$([[ "$scene" == smartplan ]] && echo 1) python3 "$HERE/seed.py" "$lib" >/dev/null
  rm -f "$raw/$scene.mov" "$raw/$scene.log"
  # The share scene starts in Safari, already on the recipe page. The extension only exists while the app is installed.
  # The extension is started by the system and keeps its own library, so point the app's library at the extension's, seeded with the same
  # recipes. Saving from the share sheet then shows up in the app. Needs the extension to have run once, which creates its container.
  if [ "$scene" = cook ]; then
    # The first timer ever started makes the system ask about alarms. Answer it before recording.
    APP_PREVIEW_PRIME=1 TEST_RUNNER_APP_PREVIEW_PRIME=1 TEST_RUNNER_APP_PREVIEW_SCENE=prep TEST_RUNNER_APP_STORE_LIB="$lib" xcodebuild test-without-building -project "$HERE/../../Recipes.xcodeproj" -scheme Recipes -derivedDataPath "$derived" \
      -destination "id=$udid" -only-testing:RecipesUITests/AppStoreScreenshotUITests/testPreview </dev/null >"$raw/prep.log" 2>&1 &
    prep=$!
    for _ in $(seq 150); do grep -q "APP_PREVIEW_EVENT end" "$raw/prep.log" 2>/dev/null && break; kill -0 $prep 2>/dev/null || break; sleep 1; done
    sleep 1; kill $prep 2>/dev/null || true; wait $prep 2>/dev/null || true
    xcrun simctl terminate "$udid" "$RECIPES_BUNDLE_ID" 2>/dev/null || true
  fi
  if [ "$scene" = share ]; then
    xcrun simctl install "$udid" "$derived/Build/Products/Debug-iphonesimulator/Recipes.app"
    xcrun simctl privacy "$udid" grant reminders "$RECIPES_BUNDLE_ID" 2>/dev/null || true
    TEST_RUNNER_APP_PREVIEW_SCENE=prep TEST_RUNNER_APP_STORE_LIB="$lib" xcodebuild test-without-building -project "$HERE/../../Recipes.xcodeproj" -scheme Recipes -derivedDataPath "$derived" \
      -destination "id=$udid" -only-testing:RecipesUITests/AppStoreScreenshotUITests/testPreview </dev/null >"$raw/prep.log" 2>&1 &
    prep=$!
    for _ in $(seq 120); do grep -q "APP_PREVIEW_EVENT end" "$raw/prep.log" 2>/dev/null && break; kill -0 $prep 2>/dev/null || break; sleep 1; done
    sleep 1; kill $prep 2>/dev/null || true; wait $prep 2>/dev/null || true
    xcrun simctl terminate "$udid" "$RECIPES_BUNDLE_ID" 2>/dev/null || true
    appdata="$(xcrun simctl get_app_container "$udid" "$RECIPES_BUNDLE_ID" data)"
    extdata=""
    for d in "$HOME/Library/Developer/CoreSimulator/Devices/$udid/data/Containers/Data/PluginKitPlugin"/*; do
      [ "$(plutil -extract MCMMetadataIdentifier raw "$d/.com.apple.mobile_container_manager.metadata.plist" 2>/dev/null)" = "$RECIPES_BUNDLE_ID.share" ] && extdata="$d"
    done
    if [ -z "$extdata" ]; then echo "The share extension has not run yet, so it has no container. Run this scene once more."; fi
    if [ -n "$extdata" ]; then
      rm -rf "$extdata/Library/Application Support/Recipes"; mkdir -p "$extdata/Library/Application Support"
      cp -R "$lib" "$extdata/Library/Application Support/Recipes"
      rm -rf "$appdata/Library/Application Support/Recipes"; mkdir -p "$appdata/Library/Application Support"
      ln -s "$extdata/Library/Application Support/Recipes" "$appdata/Library/Application Support/Recipes"
    fi
    # What the UI tests pass as launch arguments, for an app the system opens. Written through the simulator's own preferences daemon.
    for kv in "onboardingCompleted -bool true" "reviewPromptDismissed -bool true" "syncGroceriesWithReminders -bool false" "recipeListStyle -string cards" "defaultMeal -string dinner"; do
      xcrun simctl spawn "$udid" defaults write "$RECIPES_BUNDLE_ID" $kv
    done
    xcrun simctl openurl "$udid" "${APP_PREVIEW_PAGE:-https://www.allrecipes.com/recipe/23600/worlds-best-lasagna/}"; sleep 6
  fi
  xcrun simctl io "$udid" recordVideo --codec=h264 --force "$raw/$scene.mov" 2>"$raw/$scene.rec.log" &
  rec=$!
  sleep 2
  echo "RECORD_START $(python3 -c 'import time;print(time.time())')" >"$raw/$scene.log"
  TEST_RUNNER_APP_PREVIEW_SCENE="$scene" TEST_RUNNER_APP_PREVIEW_TAPS="${APP_PREVIEW_TAPS:-$SHARE_TAPS}" TEST_RUNNER_APP_STORE_LIB="$lib" \
  TEST_RUNNER_APP_STORE_STYLE="$([ "$device" = ipad ] && echo list || echo cards)" \
  TEST_RUNNER_APP_STORE_LANDSCAPE="$([ "$device" = ipad ] && echo 1 || echo 0)" \
    xcodebuild test-without-building -project "$HERE/../../Recipes.xcodeproj" -scheme Recipes -derivedDataPath "$derived" \
      -destination "id=$udid" -only-testing:RecipesUITests/AppStoreScreenshotUITests/testPreview </dev/null >>"$raw/$scene.log" 2>&1 &
  run=$!
  # xcodebuild lingers after the test passes, so stop it once the final event is logged (or after four minutes).
  for _ in $(seq 240); do grep -q "APP_PREVIEW_EVENT end" "$raw/$scene.log" 2>/dev/null && break; kill -0 $run 2>/dev/null || break; sleep 1; done
  sleep 2
  # Stop the recorder itself: interrupting only the process that started it can leave the recording running, and the next one then fails.
  pkill -INT -f "simctl io $udid recordVideo" 2>/dev/null || true; wait $rec 2>/dev/null || true
  for _ in $(seq 60); do pgrep -f "simctl io $udid recordVideo" >/dev/null || break; sleep 1; done
  kill $run 2>/dev/null || true; wait $run 2>/dev/null || true
  grep -q "APP_PREVIEW_EVENT end" "$raw/$scene.log" || echo "scene $scene failed, see $raw/$scene.log"
done
ls -la "$raw"
