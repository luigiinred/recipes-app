#!/bin/bash
# Downloads the music for the preview videos: "Still Pickin'" by Kevin MacLeod, CC BY 4.0 (see CREDITS.md). It is not stored in the repository.
set -euo pipefail
cd "$(dirname "$0")"
curl -fL -o still-pickin-kevin-macleod.mp3 "https://archive.org/download/freepd/upbeat/Still%20Pickin.mp3"
echo "Saved music/still-pickin-kevin-macleod.mp3. Credit it wherever the video is shown."
