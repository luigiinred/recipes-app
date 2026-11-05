#!/bin/bash
# Starts two fresh local Mealie servers for the discover and mealie scenes: one holding the demo recipes to browse, one empty to sync with.
# Usage: eval "$(mealie-demo.sh)"   (exports MEALIE_URL, MEALIE_TOKEN, MEALIE_SYNC_URL and MEALIE_SYNC_TOKEN for capture.sh; needs Docker and the `recipes` CLI)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# start <name> <port>: prints an API token for Mealie's built-in first-run account.
start() {
  docker rm -f "$1" >/dev/null 2>&1 || true
  docker run -d --name "$1" -p 127.0.0.1:$2:9000 -e ALLOW_SIGNUP=false -e BASE_URL=http://localhost:$2 ghcr.io/mealie-recipes/mealie:latest >/dev/null
  for _ in $(seq 100); do curl -sf http://127.0.0.1:$2/api/app/about >/dev/null && break; sleep 3; done
  local session
  session=$(curl -sf -X POST http://127.0.0.1:$2/api/auth/token -d "username=changeme@example.com&password=MyPassword" | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
  curl -sf -X POST http://127.0.0.1:$2/api/users/api-tokens -H "Authorization: Bearer $session" -H "Content-Type: application/json" \
    -d '{"name":"Recipes demo"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])"
}

token=$(start recipes-demo-mealie 9925)
sync_token=$(start recipes-demo-mealie-sync 9926)

lib="$(mktemp -d)/library"
python3 "$HERE/seed.py" "$lib" >/dev/null
MEALIE_URL=http://127.0.0.1:9925 MEALIE_TOKEN=$token "$HERE/../../.build/release/recipes" mealie --skip-meal-plan --skip-groceries --dir "$lib" >&2
# Ideas are recipes without ingredients; a shared server of real recipes doesn't have them.
for slug in pizza-night sandwiches leftovers; do
  curl -sf -o /dev/null -X DELETE http://127.0.0.1:9925/api/recipes/$slug -H "Authorization: Bearer $token" || true
done
echo "export MEALIE_URL=http://localhost:9925 MEALIE_TOKEN=$token MEALIE_SYNC_URL=http://localhost:9926 MEALIE_SYNC_TOKEN=$sync_token"
