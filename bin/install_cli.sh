#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product recipes
mkdir -p "$HOME/.local/bin"
ln -sf "$PWD/.build/release/recipes" "$HOME/.local/bin/recipes"
echo "Installed: $HOME/.local/bin/recipes (make sure it's on your PATH)"
