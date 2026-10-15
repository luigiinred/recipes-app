# App Store listing: Recipes

Everything needed to fill in App Store Connect for Recipes 1.0: copy you can paste, the screenshots and artwork in [`images/`](images/), and what's still open. Character counts are checked against Apple's limits.

Design decisions for the artwork (fonts, colors) are in [`design.markdown`](../../../design.markdown).

## Contents

1. [Asset index](#asset-index)
2. [Listing copy](#listing-copy)
3. [Screenshots and captions](#screenshots-and-captions)
4. [App information](#app-information)
5. [Before you submit](#before-you-submit)
6. [Regenerating the assets](#regenerating-the-assets)
7. [Photo credits](#photo-credits)

## Asset index

| What | File | Size | Upload to |
|---|---|---|---|
| App icon | [`images/icon/app-icon-1024.png`](images/icon/app-icon-1024.png) | 1024 × 1024, opaque | Approximate flat copy, cropped slightly to drop the rounded bevel. The shipping icon comes from the binary (`App/AppIcon.icon`). [`app-icon.png`](images/icon/app-icon.png) is the rendered Home Screen icon that the card and creative images use |
| iPhone screenshots (10) | [`images/iphone/`](images/iphone/) | 1320 × 2868 | iPhone 6.9" display |
| iPad screenshots (6) | [`images/ipad/`](images/ipad/) | 2752 × 2064, landscape | iPad 13" display |
| Product page header | [`images/creative/header.png`](images/creative/header.png) | 3840 × 1646 (21:9) | Product page header |
| Search result image | [`images/creative/search.png`](images/creative/search.png) | 3840 × 2560 (3:2) | Search results |
| Universal creative | [`images/creative/universal.png`](images/creative/universal.png) | 5244 × 2950 (16:9) | Header and search from one file |
| Mac screenshots | not produced, see [Before you submit](#before-you-submit) | 2880 × 1800 | Mac |

Screenshots are high-quality JPEG (sRGB, no alpha). The icon and creative assets are PNG. App Store Connect scales the 6.9" and 13" sets down to the smaller device sizes, so no other iPhone or iPad sizes are needed.

## Listing copy

### App name (30 characters max)

```
Recipes: Cook, Plan & Shop
```

26 characters. The app's display name on the Home Screen is "Recipes" (`CFBundleDisplayName`), and the plain name is almost certainly taken, so the listing name adds descriptors. **Availability is not checked**: reserve it in App Store Connect first. Alternates if it's taken:

- `Recipe Keeper: Cook & Plan` (26)
- `Recipes: Plan, Cook, Shop` (25)

### Subtitle (30 characters max)

```
Save, plan, and cook anything
```

### Promotional text (170 characters max)

Editable any time without a new release.

```
Save recipes from any website or video, plan your week, and cook step by step with timers and the right ingredients for each step. Syncs through your own iCloud.
```

### Description (4,000 characters max)

```
Recipes is a calm, beautiful home for the food you love to cook.

SAVE FROM ANYWHERE
Send a recipe from Safari with the Share sheet, paste a link, or import a video. Recipes reads the ingredients, steps and photo, and you review them before anything is saved. Cooking from a book? Scan the page with your camera. Or type one in yourself.

READS LIKE A COOKBOOK
Clear serif titles, amounts in bold, and preparation notes in quiet italics. Under every step you can see exactly which ingredients it uses.

COOK WITHOUT FUSS
Cook mode shows one step at a time in large type, keeps your screen awake, and lists the ingredients for that step. Times in the text become timers you start with a tap, and they keep counting on your Lock Screen. Cook several recipes at once.

VIDEOS, TOO
Import a recipe from a YouTube video. The video stays pinned above the recipe, and tapping a step's time jumps to that moment in the video.

PLAN YOUR WEEK
Line up what you'll cook next in Up Next, then place recipes on days in My Week. On devices with Apple Intelligence, Smart Plan can fill the empty slots for you. You review the plan before it's added.

SHOPPING THAT KEEPS UP
Add a recipe's ingredients to your grocery list in one tap. The list syncs both ways with the Reminders app.

STAYS ORGANIZED
Favorites or star ratings, nested categories like Dinner > Pasta, and quick search across titles, ingredients and tags. Sort a long ingredient list into sections such as "For the sauce" by hand or with Apple Intelligence, and give any recipe a photo from your library or Image Playground.

YOURS
Your recipes live in your own iCloud Drive and sync across iPhone, iPad and Mac. There is no account to create and no ads. Print or share any recipe, and ask Siri to save a recipe, find one, or start cooking.

Some features, such as Smart Plan, ingredient sections and Image Playground photos, need a device that supports Apple Intelligence. Everything else works on every supported device.
```

### Keywords (100 characters max, comma-separated, no spaces)

Words already in the name and subtitle aren't repeated, since the store indexes those anyway.

```
meal planner,grocery list,cookbook,cooking,kitchen,timer,import,scan,video,dinner,food,organizer
```

### What's New (version 1.0)

```
Welcome to Recipes. Save recipes from the web or a video, plan your week, and cook step by step.
```

### URLs and legal

| Field | Value |
|---|---|
| Support URL | **Needed.** Not in the repo |
| Marketing URL | Optional |
| Privacy policy URL | **Needed.** Not in the repo (required for every app) |
| Copyright | `2026 Timmy Garrabrant` (confirm the legal name or entity to show) |

## Screenshots and captions

Each screenshot is a real capture from the simulator, using the fictional recipe library in `tools/seed/`. Captions are set in New York on a dark warm brown, with the emphasized words in orange from the icon's utensils. They live in [`tools/captions.json`](tools/captions.json) so they can be localized without redoing artwork.

### iPhone (6.9")

| # | File | Caption | Shows |
|---|---|---|---|
| 1 | [`01-library.jpg`](images/iphone/01-library.jpg) | Every recipe, *beautifully kept.* | Photo-card library |
| 2 | [`02-recipe.jpg`](images/iphone/02-recipe.jpg) | Recipes that *read like a cookbook.* | Recipe page with hero photo and ingredients |
| 3 | [`03-steps.jpg`](images/iphone/03-steps.jpg) | Know what *each step needs.* | Steps with their ingredient chips |
| 4 | [`04-cook.jpg`](images/iphone/04-cook.jpg) | Cook with *your hands full.* | Cook mode, large type, step ingredients |
| 5 | [`05-week.jpg`](images/iphone/05-week.jpg) | Plan your week *in a minute.* | My Week |
| 6 | [`06-upnext.jpg`](images/iphone/06-upnext.jpg) | Line up what *you'll cook next.* | Up Next queue |
| 7 | [`07-groceries.jpg`](images/iphone/07-groceries.jpg) | Shopping lists that *stay in sync.* | Groceries |
| 8 | [`08-organize.jpg`](images/iphone/08-organize.jpg) | Organize it *your way.* | Collections and categories |
| 9 | [`09-dark.jpg`](images/iphone/09-dark.jpg) | Easy on the eyes, *day or night.* | Recipe page in dark mode |
| 10 | [`10-open-source.jpg`](images/iphone/10-open-source.jpg) | Open source. *No account. No ads.* | Closing card, not a capture: MIT license, iCloud Drive files, no ads |

### iPad (13", landscape)

| # | File | Caption | Shows |
|---|---|---|---|
| 1 | [`01-library.jpg`](images/ipad/01-library.jpg) | Your whole cookbook, *beautifully laid out.* | Library with the tab bar built into the sidebar |
| 2 | [`02-week.jpg`](images/ipad/02-week.jpg) | Plan the week *with the recipe in hand.* | My Week beside a recipe |
| 3 | [`03-upnext.jpg`](images/ipad/03-upnext.jpg) | Line up what *you'll cook next.* | Up Next beside a recipe |
| 4 | [`04-cook.jpg`](images/ipad/04-cook.jpg) | Step by step, *in large, clear type.* | Cook mode |
| 5 | [`05-dark.jpg`](images/ipad/05-dark.jpg) | Easy on the eyes, *day or night.* | Library in dark mode |
| 6 | [`06-open-source.jpg`](images/ipad/06-open-source.jpg) | Open source. *No account. No ads.* | Closing card, not a capture |

### Creative assets

The header, search and universal images use a mosaic of the demo recipe photos behind the app icon and "Your recipes, *beautifully kept.*" They carry no pricing, URLs, other platforms or awards, per Apple's guidance. Preview them in App Store Connect's template before uploading, because Apple's safe areas differ slightly between the three.

### Notes on the screenshots

- The app UI is the real app. The recipes, plan and grocery list are fictional, and the photos are CC0 images credited [below](#photo-credits).
- The status bar is set to 9:41 with full battery and signal.
- The Cook button, ingredient chips, timers and Live Activity are not all visible in stills. The cook-mode shot is the clearest single frame, but an **app preview video** (cook mode with a timer, then the share-sheet import) would sell the app better than any still. Not made.

## App information

| Field | Suggested value |
|---|---|
| Primary category | Food & Drink (already set in the app: `public.app-category.food-and-drink`) |
| Secondary category | Lifestyle |
| Platforms | iPhone, iPad, Mac. Requires iOS 26 and macOS 26 |
| Price | Your choice. Not set here |
| Age rating | Expected **4+**. Answer "None" to every content question. For "Unrestricted web access", the app only reads pages you give it and plays an embedded video, so the answer should be No, but confirm |
| Export compliance | No non-exempt encryption (`ITSAppUsesNonExemptEncryption` is already `false`) |
| Version / build | 1.0 (6), from `project.yml` |

### App Privacy ("nutrition label")

Suggested answer: **Data Not Collected.** Reasoning from the code:

- No analytics, advertising, crash-reporting or tracking SDKs. The only package dependency is Swift Argument Parser, used by the command-line tool.
- Recipes, plans and groceries are stored on the device and in the user's own iCloud Drive container. Nothing goes to a server you run.
- The app downloads web pages and video details only when the user imports a link.

**Check before you answer:** playing a video shows YouTube's embedded player, which is Google's code and can set its own cookies. Decide whether that needs to be disclosed. Apple's questionnaire asks about data collected by the app *and its third-party partners*.

### Permissions the app asks for

| Permission | When | Text shown to the user |
|---|---|---|
| Camera | First time they scan a recipe | Recipes uses the camera to scan recipes from books and printouts. |
| Reminders | When Groceries sync is on | Recipes keeps your grocery list in sync with a list in the Reminders app. |

### App Review notes

```
There is no sign-in. The app starts with an empty library and a short welcome tour.

To see it with content quickly: Settings (gear) > Data & Developer > Developer Tools > "Add Sample Recipes, Plan and Groceries". This adds a handful of built-in recipes, a week plan and a grocery list.

To try importing: tap + > "Import from Web or YouTube..." and paste any public recipe page or YouTube recipe video. Importing needs an internet connection.

Camera access is used only for "Scan Recipe...". Reminders access is used only when Groceries sync is on, to keep a list called "Groceries" in step with the app.

Apple Intelligence features (Smart Plan, ingredient sections, Image Playground photos) are optional. On devices without it, Smart Plan falls back to a simple rotation, and Settings explains what isn't available and why.

Syncing uses the user's iCloud Drive. Without iCloud, the app keeps the library on the device.
```

Verify the Developer Tools path on the final build, and decide whether you want reviewers to see that screen at all.

## Before you submit

- [ ] **Support and privacy policy URLs.** Required, and neither exists in the repo.
- [ ] **Reserve the app name** (see alternates above).
- [ ] **Mac screenshots.** None were made. The Mac app launches from this tool's shell but never opens a window, because the shell has no GUI session, so the UI test that captures the window can't run. Mac builds also need a Mac development certificate that isn't on this machine. Run the capture from a normal Terminal tab in your desktop session, or take them by hand at 2880 × 1800 (or 1440 × 900 at 2x).
- [ ] **Decide the accent.** The icon is peach, terracotta and orange, while the app's accent is a tomato red. The artwork keeps its dark brown ground with the icon's orange. See [`design.markdown`](../../../design.markdown).
- [ ] **Preview the creative assets** in App Store Connect's template for header, search and universal.
- [ ] **Localize** `tools/captions.json` and the copy above if you ship in other languages.
- [ ] **App Privacy answers** (YouTube embed question above).
- [ ] **Optional:** an app preview video, and a light-background variant of the screenshots for product page optimization tests (`compose.py --style light` exists but its output wasn't reviewed, so it isn't included).

## Regenerating the assets

All commands run from `apps/ios`. Needs Xcode, XcodeGen, Google Chrome and ImageMagick.

```bash
swift build -c release --product recipes   # the CLI that seeds the demo library
xcodegen generate
xcrun simctl create "Recipes Shots iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl create "Recipes Shots iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcodebuild build-for-testing -project Recipes.xcodeproj -scheme Recipes -destination "id=<sim id>" -derivedDataPath /tmp/shots

app-store/tools/capture.sh iphone <iphone sim id> /tmp/shots home library recipe ingredients cook plan upnext groceries recipe-dark
app-store/tools/capture.sh ipad <ipad sim id> /tmp/shots library plan upnext cook library-dark
python3 app-store/tools/compose.py iphone
python3 app-store/tools/compose.py ipad
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" App/AppIcon.icon --export-image \
  --output-file app-store/images/icon/app-icon.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
python3 app-store/tools/card.py            # the closing card, last in each set (also run creative.py after an icon change)
python3 app-store/tools/creative.py
```

Notes from making these:

- The iPad shots need an iOS 27 simulator. The sidebar's category groups start folded only on iOS 27; on 26.x every group is expanded and the list runs off the bottom.
- Use a dedicated simulator. A simulator last used by another app shows that app's "back" link in the status bar.
- `capture.sh` reinstalls the app each run, because the app remembers which sidebar sections are open. It seeds a fresh library every run with `tools/seed.py` (recipes in `tools/seed/recipes.json`, photos in `tools/seed/photos/`) and points the app at it with `RECIPES_DIR`.
- The `TimerWidget` Live Activity extension crashes at launch in the simulator test runner and fails the run ("Critical process TimerWidget crashed"). I worked around it by deleting `PlugIns/TimerWidget.appex` from the *built* app in the derived data folder and re-signing it ad hoc: `rm -rf <DerivedData>/Build/Products/Debug-iphonesimulator/Recipes.app/PlugIns/TimerWidget.appex && codesign --force --sign - --preserve-metadata=entitlements <that .app>`. The crash itself is worth a look: it's an assertion in `_EXRunningExtension._start`.
- The UI test is `RecipesUITests/AppStoreScreenshotUITests.swift`. It does nothing unless `APP_STORE_SCENE` is set.
- `capture.sh` ends each scene with `magick -auto-orient`, because iPad landscape captures carry an orientation flag.

## Photo credits

The demo recipes use photos released under CC0 (no attribution required), found on Wikimedia Commons. They're listed for the record, and in case a photo is ever re-licensed or taken down.

| Recipe photo | Commons file | License | Page |
|---|---|---|---|
| pesto-pasta | Pesto Pasta (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Pesto_Pasta_(Unsplash).jpg> |
| butternut-soup | Autumn Soup (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Autumn_Soup_(Unsplash).jpg> |
| red-curry | Red Curry (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Red_Curry_(Unsplash).jpg> |
| pappardelle | Plate of Pasta (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Plate_of_Pasta_(Unsplash).jpg> |
| quiche | Quiche and Salad (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Quiche_and_Salad_(Unsplash).jpg> |
| shakshuka | Shakshuka (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Shakshuka_(Unsplash).jpg> |
| cookies | Chocolate chip cookies on cutting board.jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Chocolate_chip_cookies_on_cutting_board.jpg> |
| lemon-loaf | Lemon and lavender Bread (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Lemon_and_lavender_Bread_(Unsplash).jpg> |
| braised-beef | Meat Stew (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Meat_Stew_(Unsplash).jpg> |
| noodle-soup | Pho for Dinner (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Pho_for_Dinner_(Unsplash).jpg> |
| fig-toast | Gourmet Toast (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Gourmet_Toast_(Unsplash).jpg> |
| clams | Seafood Boil (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Seafood_Boil_(Unsplash).jpg> |
| lentil-salad | Healthy Lentil Salad (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Healthy_Lentil_Salad_(Unsplash).jpg> |
| egg-salad | Salad for dinner (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Salad_for_dinner_(Unsplash).jpg> |
| pancakes | Slicing Pancakes with Fork 374819.jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Slicing_Pancakes_with_Fork_374819.jpg> |
| fried-rice | Fried rice (Unsplash).jpg | CC0 | <https://commons.wikimedia.org/wiki/File:Fried_rice_(Unsplash).jpg> |

The photos are captured as shown on Commons at the time of download. Licensing was read from each file's Commons metadata, not independently verified.
