#!/usr/bin/env bash
# Generates Recipes.xcodeproj with the identifiers from .env.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo "❌ missing .env (copy .env.example and fill it in)" >&2; exit 1; }
set -a; source .env; set +a
for var in RECIPES_TEAM_ID RECIPES_BUNDLE_ID RECIPES_ICLOUD_CONTAINER; do
  [[ -n "${!var:-}" ]] || { echo "❌ .env must set $var" >&2; exit 1; }
done
command -v xcodegen >/dev/null || { echo "❌ xcodegen not installed (brew install xcodegen)" >&2; exit 1; }

exec xcodegen generate "$@"
