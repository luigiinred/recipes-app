#!/bin/bash
# Draft render of chosen frames (one sample each): render_list.sh <device> <out-dir> <frames-file> [workers]
dev=$1 out=$2 list=$3 workers=${4:-4}
mkdir -p "$out"
cat "$list" | xargs -P "$workers" -I{} node "$(dirname "$0")/render.mjs" "$dev" "$out" --from {} --to {} --workers 1 --subframes 1 2>&1 | grep -v "frames," | grep -v "^$" | head -5
