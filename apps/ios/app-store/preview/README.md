# App Store preview videos

HTML compositions, rendered frame by frame, that become the App Store app preview videos (`iphone.mp4`, `ipad.mp4`). Everything on screen is a pure
function of time, so any frame can be rendered alone. The footage is real: simulator recordings of the app, driven by `testPreview` in
[`AppStoreScreenshotUITests.swift`](../../RecipesUITests/AppStoreScreenshotUITests.swift).

**Status:** the iPhone film is a draft (see [`NEXT.md`](NEXT.md) for what is left). The iPad, Mac and iPhone Duo films are not built yet.

## What is in the box

| Path | What it is |
|---|---|
| `shared/kit.js`, `shared/engine.js`, `shared/template.html` | The animation engine: screens, camera, captions, the close card and the icon that assembles itself. Shared by every device |
| `tools/story_<device>.py` | One film's story: the frame of every scene, camera move, caption and sound event. `build_events.py` turns it into `events.json`, `events.js` and `<device>/index.html` |
| `events.json` | The single timeline, in frames at 30 fps (100 bpm: a beat is 18 frames, a bar 72). The picture and the sound both read it, so they cannot drift |
| `clips.json` | Which stretch of which recording becomes a footage clip (`tools/cut.py`) |
| `tools/retime.py` | Fits a recording into a frame budget: motion near natural speed, waiting squeezed |
| `tools/render.mjs` | Renders 8 sub-frames per frame on a 180° shutter and blends them in linear light (HyperFrames renders one sample per frame) |
| `tools/audio.py`, `tools/package.py` | Synthesizes the sound effects from `events.json`, mixes them under the music, normalizes to about -16 LUFS, encodes H.264 + AAC |
| `tools/verify_sync.py` | Detects onsets in the rendered audio and compares them with `events.json` |
| `../tools/record.sh` | Records one UI-test scene from a simulator (`xcrun simctl io … recordVideo`) |

## What you need that is not in the repository

- **Device frame:** Apple's own bezel PNGs from [Apple Design Resources](https://developer.apple.com/design/resources/). The iPhone film uses
  `iPhone 17 Pro Max - Cosmic Orange - Portrait.png`, saved as `assets/bezel-iphone-17-pro-max-cosmic-orange.png`. Its screen opening is
  1320 × 2868 at (75, 66), which is exactly a simulator screenshot. Check Apple's terms before sharing the frames, and note that Apple may not want
  hardware frames in app previews: set `"bezel": ""` in the story to drop it.
- **Music:** `music/fetch.sh`. The track is CC BY 4.0, so [`music/CREDITS.md`](music/CREDITS.md) has to be shown wherever the video is.
- **Footage:** `footage/raw/<device>/<scene>.mov`, recorded with `../tools/record.sh` (not stored: it is gigabytes, and the share scene shows a recipe
  site's page). The story imports "World's Best Lasagna" from the web into `seed/lasagna/` with `recipes import <url>`; `../tools/seed.py` copies it into
  each scene's library (`APP_PREVIEW_LASAGNA=1`).
- `npm install` here (HyperFrames, Puppeteer and sharp), `ffmpeg`, Google Chrome, and a Python venv with `numpy scipy soundfile pillow`.

## Making a film

```bash
../tools/record.sh iphone <simulator udid> <derived data> hero share plan smartplan cleanup cook   # the recordings
python3 tools/cut.py iphone                                      # 60 fps frame sequences into footage/frames/
python3 tools/build_events.py iphone                             # story -> events.json and iphone/index.html
node tools/render.mjs iphone renders/iphone/frames --workers 6   # 792 frames x 8 sub-frames
python3 tools/package.py iphone renders/iphone/frames iphone.mp4 # sound, mix, encode
python3 tools/verify_sync.py events.json iphone renders/iphone/fx.wav iphone.mp4
```

Draft frames render in seconds with `--subframes 1 --step 12`. Scenes with a first-run system question (Reminders, alarms) are answered by `record.sh`
before recording starts.
