#!/usr/bin/env bash
# One-shot TestFlight release for Recipes, run in-place in a clean checkout on master.
#
#   preflight → compile check → publish iOS + macOS → land the build-number bump
#   → tag a GitHub release → print RELEASE RESULT
#
# Usage: cut-release.sh [options]
#   --dry-run           preflight + compile check only (no upload, no commit)
#   --skip-build-check  skip the Debug compile check
#   --prerelease        mark the GitHub release as a prerelease
#   -h, --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Recipes"
PROJECT_YML="project.yml"
BRANCH="master"
LOCK="/tmp/recipes-cut-release.$(id -u).lock"

BUILD_CHECK=1
DRY_RUN=0
PRERELEASE=0

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)          DRY_RUN=1; shift ;;
    --skip-build-check) BUILD_CHECK=0; shift ;;
    --prerelease)       PRERELEASE=1; shift ;;
    -h|--help)          usage ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

step() { echo "==> $*"; }
die()  { echo "❌ $*" >&2; exit 1; }

PHASE=start
NEW=""; M=""; LOG_FILE=""; RELEASE_TAG=""; RELEASE_URL=""

acquire_lock() {
  if ! mkdir "$LOCK" 2>/dev/null; then
    local pid; pid="$(cat "$LOCK/pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      die "another cut-release is running (pid $pid). One release at a time."
    fi
    rm -rf "$LOCK"
    mkdir "$LOCK" || die "cannot create lock $LOCK"
  fi
  echo $$ > "$LOCK/pid"
}

on_exit() {
  local code=$?
  rm -rf "$LOCK"
  [[ $code -eq 0 ]] && return
  printf '\n❌ RELEASE FAILED — phase: %s (exit %s)\n' "$PHASE" "$code"
  [[ -n "$LOG_FILE" ]] && printf '   Log: %s\n' "$LOG_FILE"
}
trap on_exit EXIT

current_build_number() {
  sed -nE 's/.*CURRENT_PROJECT_VERSION: *"([0-9]+)".*/\1/p' "$PROJECT_YML" | head -1
}

marketing_version() {
  sed -nE 's/.*MARKETING_VERSION: *"([0-9.]+)".*/\1/p' "$PROJECT_YML" | head -1
}

LOG_DIR=".git/cut-release-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"
acquire_lock

PHASE=preflight
step "Preflight"
command -v xcodegen >/dev/null || die "xcodegen not installed (brew install xcodegen)"
command -v gh >/dev/null || die "gh CLI not installed (needed for the GitHub release)"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated"
[[ "$(git branch --show-current)" == "$BRANCH" ]] \
  || die "must be on $BRANCH (currently on $(git branch --show-current))"
[[ -z "$(git status --porcelain)" ]] \
  || die "working tree is dirty — commit or stash before releasing"
[[ -f .env ]] || die "missing .env (copy .env.example)"

git fetch origin --quiet
if git rev-parse "origin/$BRANCH" >/dev/null 2>&1; then
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH")" ]]; then
    step "HEAD differs from origin/$BRANCH (local commits will be pushed)"
  else
    step "HEAD is level with origin/$BRANCH"
  fi
fi

N="$(current_build_number)"
[[ -n "$N" ]] || die "could not read the build number from $PROJECT_YML"
NEW=$((N + 1))
M="$(marketing_version)"
step "Build number: $N -> $NEW   marketing: $M"

if (( BUILD_CHECK )); then
  PHASE=build-check
  step "Compile check (Debug, macOS, unsigned) before burning a build number"
  bin/launch_mac.sh --build-only --quiet 2>&1 | tee -a "$LOG_FILE" \
    || die "compile check failed — no build number was consumed"
fi

if (( DRY_RUN )); then
  PHASE=done
  printf '\n===== RELEASE RESULT =====\n'
  printf 'status: dry-run\n'
  printf 'build: %s\n' "$NEW"
  printf 'marketing_version: %s\n' "$M"
  printf 'platforms: iOS + macOS\n'
  printf '=========================\n'
  exit 0
fi

PHASE=publish
step "Publishing to TestFlight (iOS + macOS)"
bin/publish_testflight.sh all 2>&1 | tee -a "$LOG_FILE" || die "publish failed"

PHASE=verify
step "Verifying upload lines"
for platform in iOS macOS; do
  grep -q "$platform upload complete" "$LOG_FILE" || die "log has no '$platform upload complete' line"
done
grep -q "Done! Deployed" "$LOG_FILE" || die "log has no 'Done! Deployed' line"
NEW_ACTUAL="$(current_build_number)"
[[ "$NEW_ACTUAL" == "$NEW" ]] || die "project.yml is at build $NEW_ACTUAL, expected $NEW"
step "iOS + macOS uploaded ✓ (build $NEW)"

PHASE=commit
git add "$PROJECT_YML"
git diff --cached --quiet && die "no build-number change staged (expected $PROJECT_YML at build $NEW)"
git commit -q -m "chore: bump build number to ${NEW} for TestFlight upload"
step "Committed bump: $(git rev-parse --short HEAD)"

PHASE=push
git push origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"

PHASE=tag
RELEASE_TAG="v${M}-build.${NEW}"
git rev-parse -q --verify "refs/tags/$RELEASE_TAG" >/dev/null && die "tag $RELEASE_TAG already exists"
gh release view "$RELEASE_TAG" >/dev/null 2>&1 && die "GitHub release $RELEASE_TAG already exists"

args=(--target "$(git rev-parse HEAD)" --title "Recipes ${M} (build ${NEW})" --generate-notes)
if (( PRERELEASE )); then args+=(--prerelease); fi
RELEASE_URL="$(gh release create "$RELEASE_TAG" "${args[@]}")" || die "gh release create failed"

printf '\n===== RELEASE RESULT =====\n'
printf 'status: success\n'
printf 'build: %s\n' "$NEW"
printf 'marketing_version: %s\n' "$M"
printf 'platforms: iOS + macOS\n'
printf 'commit: %s\n' "$(git rev-parse HEAD)"
printf 'tag: %s\n' "$RELEASE_TAG"
printf 'release: %s\n' "$RELEASE_URL"
printf 'note: App Store Connect needs a few minutes to process the build before it shows in TestFlight.\n'
printf '=========================\n'
