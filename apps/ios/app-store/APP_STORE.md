# App Store listing: Recipes

Everything needed to fill in App Store Connect for Recipes 1.0: copy you can paste, the screenshots and artwork in [`images/`](images/), and what's still open. Character counts are checked against Apple's limits.

Design decisions for the artwork (fonts, colors) are in [`design.markdown`](../../../design.markdown).

## Contents

1. [Positioning](#positioning)
2. [Asset index](#asset-index)
3. [Listing copy](#listing-copy)
4. [Screenshots and captions](#screenshots-and-captions)
5. [App information](#app-information)
6. [Before you submit](#before-you-submit)
7. [Regenerating the assets](#regenerating-the-assets)
8. [Photo credits](#photo-credits)

## Positioning

**The free, open-source recipe manager built for iPhone, iPad and Mac.** Three pillars carry the listing, the screenshots and the marketing:

1. **Save recipes from anywhere on the web.** Safari's Share sheet, a pasted link, a YouTube video or a scanned page. The importer reads the page and you review it before anything is saved.
2. **Plan with recipes or ideas.** My Week takes a recipe or a free-text idea such as "Taco night".
3. **Apple Intelligence that stays out of your way.** It helps you *add* (video captions to a recipe, splitting steps pasted as one block), *organize* (grouping a long ingredient list into sections) and *plan* (Smart Plan fills the empty slots). It runs on the device and you review the result.

Claims were checked against the code before they went into the copy:

| Claim | Status |
|---|---|
| Free | Yes. There is no StoreKit or purchase code |
| Open source | Yes. [`LICENSE`](../../../LICENSE) is MIT. Without a license file the public repo would not have granted anyone permission to reuse it, which is why it was added before advertising this |
| Import from anywhere on the web | Yes. Web pages, YouTube, scanned pages and the Share sheet |
| Plan with recipes or ideas | Yes. The Add Meal sheet takes free text (`NewIdeaSheet`); the plan model already allowed an entry with no recipe |
| Apple Intelligence for add, organize and plan | Yes, and no wider than that. Image Playground photos are separate |
| iPhone, iPad and Mac | Yes, and each has its own screenshot set |

**One Apple rule shapes the wording.** Price words such as "free" can't appear in the app name, subtitle or screenshots (App Review Guideline 2.3.7; worth re-reading before each submission). So "free and open source" lives in the description and promotional text, the subtitle says "Open source recipe manager", and the screenshots show the product, not the price. Competitor names also can't appear in any metadata. A competing listing was used for structure only (short ALL-CAPS feature sections), never its wording.

Marketing ideas not yet done: an **app preview video** (cook mode with a timer, then Share-sheet import), and a light-background variant of each set for product page optimization tests.

## Asset index

| What | File | Size | Upload to |
|---|---|---|---|
| App icon | [`images/icon/app-icon-1024.png`](images/icon/app-icon-1024.png) | 1024 × 1024, opaque | Approximate flat copy, cropped slightly to drop the rounded bevel. The shipping icon comes from the binary (`App/AppIcon.icon`). [`app-icon.png`](images/icon/app-icon.png) is the rendered Home Screen icon that the card and creative images use |
| iPhone screenshots (10) | [`images/iphone/`](images/iphone/) | 1320 × 2868 | iPhone 6.9" display |
| iPad screenshots (9) | [`images/ipad/`](images/ipad/) | 2752 × 2064, landscape | iPad 13" display |
| Mac screenshots (9) | [`images/mac/`](images/mac/) | 2880 × 1800 | Mac |
| Product page header | [`images/creative/header.png`](images/creative/header.png) | 3840 × 1646 (21:9) | Product page header |
| Search result image | [`images/creative/search.png`](images/creative/search.png) | 3840 × 2560 (3:2) | Search results |
| Universal creative | [`images/creative/universal.png`](images/creative/universal.png) | 5244 × 2950 (16:9) | Header and search from one file |

Screenshots are high-quality JPEG (sRGB, no alpha). The icon and creative assets are PNG. App Store Connect scales the 6.9" and 13" sets down to the smaller device sizes, so no other iPhone or iPad sizes are needed. Mac accepts 1280 × 800, 1440 × 900, 2560 × 1600 and 2880 × 1800.

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
Open source recipe manager
```

26 characters. "Open source" is indexed from here, so it is not repeated in the keywords.

### Promotional text (170 characters max)

Editable any time without a new release. This is where "free" can be said.

```
A free, open-source recipe manager for iPhone, iPad and Mac. Save recipes from any website, plan your week, and get help from Apple Intelligence. No account, no ads.
```

165 characters.

### Description (4,000 characters max)

Leads with free and open source, then the three pillars in the order of the screenshots.

```
Recipes is a free, open-source recipe manager built for iPhone, iPad and Mac. There is no account to create and no ads, and the source code is public under the MIT license.

SAVE FROM ANYWHERE ON THE WEB
Send a recipe from Safari with the Share sheet, paste a link, or import a YouTube video. Recipes reads the ingredients, steps and photo, and you review them before anything is saved. The video stays pinned above the recipe, and tapping a step's time jumps to that moment. Cooking from a book? Scan the page with your camera. Or type one in yourself.

PLAN YOUR WEEK, WITH RECIPES OR IDEAS
Line up what you'll cook next in Up Next, then place recipes on days in My Week. Not every meal is a recipe, so you can add an idea too, like "Taco night" or "Leftovers".

APPLE INTELLIGENCE, WHEN YOU WANT IT
On devices that support it, Apple Intelligence helps you add, organize and plan, and it runs on your device. It turns a video's captions into a recipe and splits steps that were pasted as one block. It sorts a long ingredient list into sections such as "For the sauce", and Smart Plan fills the empty slots in your week. You review everything before it's saved.

READS LIKE A COOKBOOK
Clear serif titles, amounts in bold, and preparation notes in quiet italics. Under every step you can see exactly which ingredients it uses.

COOK WITHOUT FUSS
Cook mode shows one step at a time in large type, keeps your screen awake, and lists the ingredients for that step. Times in the text become timers you start with a tap, and they keep counting on your Lock Screen. Cook several recipes at once.

SHOPPING THAT KEEPS UP
Add a recipe's ingredients to your grocery list in one tap. The list syncs both ways with the Reminders app.

STAYS ORGANIZED
Favorites or star ratings, nested categories like Dinner > Pasta, and quick search across titles, ingredients and tags. Give any recipe a photo from your library or Image Playground.

YOURS
Your recipes live in your own iCloud Drive and sync across iPhone, iPad and Mac. Print or share any recipe, and ask Siri to save a recipe, find one, or start cooking.

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

Each screenshot is a real capture of the app using the fictional recipe library in `tools/seed/`, except the devices shot (a composite of three captures) and the closing card (designed, not captured). Captions are set in New York on a dark warm brown, with the emphasized words in orange from the icon's utensils. They live in [`tools/captions.json`](tools/captions.json) so they can be localized without redoing artwork.

All three sets follow the same story, the pillars from [Positioning](#positioning) first and the everyday features after:

1. **Devices.** Built for iPhone, iPad and Mac.
2. **Import.** Save recipes from anywhere on the web. This is the review screen after importing a fictional recipe page served from this machine (`tools/seed/site`), so no third-party brand, photo or URL appears.
3. **Ideas.** Plan your week with recipes or ideas. "Taco night" sits in the week beside real recipes.
4. **Smart Plan.** Apple Intelligence plans the gaps. The Smart Plan sheet, before it runs (see the notes below).
5. **Clean Up.** Tidy a messy recipe in one tap. The editor's "Clean Up with Apple Intelligence" button and what it does.
6. onward. Library, recipe, cook mode and groceries, then the closing open-source card.

### iPhone (6.9")

| # | File | Caption | Shows |
|---|---|---|---|
| 1 | [`01-devices.jpg`](images/iphone/01-devices.jpg) | Built for iPhone, *iPad and Mac.* | The library on a Mac window, an iPad and an iPhone |
| 2 | [`02-import.jpg`](images/iphone/02-import.jpg) | Save recipes from *anywhere on the web.* | Import review for the fictional gnocchi page |
| 3 | [`03-ideas.jpg`](images/iphone/03-ideas.jpg) | Plan your week with *recipes or ideas.* | My Week with "Taco night" among recipes |
| 4 | [`04-smart-plan.jpg`](images/iphone/04-smart-plan.jpg) | Apple Intelligence *plans the gaps.* | Smart Plan sheet |
| 5 | [`05-clean-up.jpg`](images/iphone/05-clean-up.jpg) | Tidy a messy recipe *in one tap.* | Recipe editor, Clean Up with Apple Intelligence |
| 6 | [`06-library.jpg`](images/iphone/06-library.jpg) | Every recipe, *beautifully kept.* | Photo-card library |
| 7 | [`07-recipe.jpg`](images/iphone/07-recipe.jpg) | Recipes that *read like a cookbook.* | Recipe page with hero photo and ingredients |
| 8 | [`08-cook.jpg`](images/iphone/08-cook.jpg) | Cook with *your hands full.* | Cook mode, large type, step ingredients |
| 9 | [`09-groceries.jpg`](images/iphone/09-groceries.jpg) | Shopping lists that *stay in sync.* | Groceries |
| 10 | [`10-open-source.jpg`](images/iphone/10-open-source.jpg) | Open source. *No account. No ads.* | Closing card, not a capture: MIT license, iCloud Drive files, no ads |

### iPad (13", landscape)

| # | File | Caption | Shows |
|---|---|---|---|
| 1 | [`01-devices.jpg`](images/ipad/01-devices.jpg) | Built for iPhone, *iPad and Mac.* | Same lineup, laid out for landscape |
| 2 | [`02-import.jpg`](images/ipad/02-import.jpg) | Save recipes from *anywhere on the web.* | Import review |
| 3 | [`03-ideas.jpg`](images/ipad/03-ideas.jpg) | Plan your week with *recipes or ideas.* | My Week beside a recipe |
| 4 | [`04-smart-plan.jpg`](images/ipad/04-smart-plan.jpg) | Apple Intelligence *plans the gaps.* | Smart Plan sheet |
| 5 | [`05-clean-up.jpg`](images/ipad/05-clean-up.jpg) | Tidy a messy recipe *in one tap.* | Recipe editor |
| 6 | [`06-library.jpg`](images/ipad/06-library.jpg) | Your whole cookbook, *beautifully laid out.* | Library with the tab bar across the top |
| 7 | [`07-cook.jpg`](images/ipad/07-cook.jpg) | Step by step, *in large, clear type.* | Cook mode |
| 8 | [`08-groceries.jpg`](images/ipad/08-groceries.jpg) | Shopping lists that *stay in sync.* | Groceries |
| 9 | [`09-open-source.jpg`](images/ipad/09-open-source.jpg) | Open source. *No account. No ads.* | Closing card, not a capture |

### Mac (2880 × 1800)

| # | File | Caption | Shows |
|---|---|---|---|
| 1 | [`01-devices.jpg`](images/mac/01-devices.jpg) | Built for iPhone, *iPad and Mac.* | Same lineup |
| 2 | [`02-import.jpg`](images/mac/02-import.jpg) | Save recipes from *anywhere on the web.* | Import review |
| 3 | [`03-ideas.jpg`](images/mac/03-ideas.jpg) | Plan your week with *recipes or ideas.* | My Week beside a recipe |
| 4 | [`04-smart-plan.jpg`](images/mac/04-smart-plan.jpg) | Apple Intelligence *plans the gaps.* | Smart Plan sheet |
| 5 | [`05-clean-up.jpg`](images/mac/05-clean-up.jpg) | Tidy a messy recipe *in one tap.* | Recipe editor |
| 6 | [`06-library.jpg`](images/mac/06-library.jpg) | Your whole cookbook, *beautifully laid out.* | Three-column window: categories, recipes, recipe |
| 7 | [`07-cook.jpg`](images/mac/07-cook.jpg) | Step by step, *in large, clear type.* | Cook mode |
| 8 | [`08-groceries.jpg`](images/mac/08-groceries.jpg) | Shopping lists that *stay in sync.* | Groceries |
| 9 | [`09-open-source.jpg`](images/mac/09-open-source.jpg) | Open source. *No account. No ads.* | Closing card, not a capture |

Dropped from the first set: the steps-with-ingredients, Up Next, organize and dark-mode shots. Cook mode and the recipe page already show the step ingredients, and a dark shot can come back as a product page optimization variant.

### Creative assets

The header, search and universal images use a mosaic of the demo recipe photos behind the app icon and "Your recipes, *beautifully kept.*" They carry no pricing, URLs, other platforms or awards, per Apple's guidance. Preview them in App Store Connect's template before uploading, because Apple's safe areas differ slightly between the three.

### Notes on the screenshots

- The app UI is the real app. The recipes, plan and grocery list are fictional, and the photos are CC0 images credited [below](#photo-credits).
- The iPhone and iPad status bar is set to 9:41 with full battery and signal.
- **Smart Plan and Clean Up show the screen, not a result.** The simulator has no on-device model, so running them would show the fallback (a simple rotation) instead of Apple Intelligence. The sheet and the button text are what the caption claims. To show a result, capture on a Mac or iPhone with Apple Intelligence turned on.
- The Cook button, ingredient chips, timers and Live Activity are not all visible in stills. An **app preview video** (cook mode with a timer, then the share-sheet import) would sell the app better than any still. Not made.
- The captions never use price words ("free"), see [Positioning](#positioning).

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
- [ ] **Set the Apple ID** in `App/AppStoreLink.swift` once the app exists in App Store Connect. Until then Settings hides the "Help Support Us" section. The "Rate us" banner uses the in-app rating dialog and needs no ID.
- [x] **Mac screenshots.** Captured in a 1280 × 800 point window (2560 × 1600 pixels) from the capture tool, see [Regenerating the assets](#regenerating-the-assets). Re-run them whenever the Mac layout changes.
- [ ] **Decide the accent.** The icon is peach, terracotta and orange, while the app's accent is a tomato red. The artwork keeps its dark brown ground with the icon's orange. See [`design.markdown`](../../../design.markdown).
- [ ] **Preview the creative assets** in App Store Connect's template for header, search and universal.
- [ ] **Localize** `tools/captions.json` and the copy above if you ship in other languages.
- [ ] **App Privacy answers** (YouTube embed question above).
- [ ] **Optional:** an app preview video, and a light-background or dark-mode variant of the screenshots for product page optimization tests (`compose.py --style light` exists but its output wasn't reviewed, so it isn't included).

## Regenerating the assets

All commands run from `apps/ios`. Needs Xcode, XcodeGen, Google Chrome and ImageMagick, plus the identifiers in `apps/ios/.env`. The pipeline is: seed a fake library, drive the app with UI tests to save a raw screenshot per scene, then compose each raw capture with its caption.

```bash
set -a; source .env; set +a                # XcodeGen reads the bundle ID from here; without it the build has no CFBundleIdentifier
swift build -c release --product recipes   # the CLI that seeds the demo library
xcodegen generate
```

### iPhone and iPad (simulators)

```bash
xcrun simctl create "Recipes Shots iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl create "Recipes Shots iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcodebuild build-for-testing -project Recipes.xcodeproj -scheme Recipes -destination "id=<sim id>" -derivedDataPath /tmp/shots
# See the widget note below, then:
app-store/tools/capture.sh iphone <iphone sim id> /tmp/shots import idea smartplan cleanup library recipe cook groceries
app-store/tools/capture.sh ipad <ipad sim id> /tmp/shots import idea smartplan cleanup library cook groceries
```

Scenes are named in [`AppStoreScreenshotUITests.swift`](../RecipesUITests/AppStoreScreenshotUITests.swift): `home library list recipe ingredients cook plan upnext groceries settings search import idea smartplan cleanup` (add `-dark` to any for dark mode). A scene that fails prints its log path. Build for the simulator you capture on: the iPhone and iPad runs share one derived-data folder, so rebuild when you switch.

### Mac

The Mac app needs a window server, so run this **from a Terminal tab in your desktop session**, not from a headless shell, and don't touch the mouse: the UI test drives it for about a minute per scene.

```bash
xcodebuild build-for-testing -project Recipes.xcodeproj -scheme Recipes -destination "platform=macOS" -derivedDataPath /tmp/shots-mac -quiet \
  DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS= PROVISIONING_PROFILE_SPECIFIER= ENABLE_APP_SANDBOX=NO
app-store/tools/capture-mac.sh /tmp/shots-mac                    # library import idea smartplan cleanup cook groceries
```

Why it is built this way:

- **Ad hoc signing, no sandbox.** There is no Mac development certificate on the build machine, so the app is signed ad hoc with the entitlements removed and `ENABLE_APP_SANDBOX=NO`. The UI-test *runner* is still sandboxed and can't write into the repo, so the test saves the PNG to its own temp folder and prints `APP_STORE_SHOT <path>`; `capture-mac.sh` copies it out of the log.
- **`-ApplePersistenceIgnoreState YES`.** Without it the app can restore "no windows" and never open one, which looks like the UI test timing out waiting for the library.
- **A fixed window.** The window's default size and position depend on which display it last used (on a two-display machine it opened half off the edge of the external display and the screenshot picked up other apps' windows). `App/ScreenshotWindow.swift` sizes the window from `RECIPES_WINDOW_SIZE=1280x800` and puts it on the primary display, and `RECIPES_APPEARANCE=light` forces light mode. Both do nothing unless the UI test sets them. 1280 × 800 points is 2560 × 1600 pixels, an accepted Mac App Store size.
- **Clean saved state.** The app remembers split-view widths between runs, so `capture-mac.sh` clears those keys first. The sidebar's category groups are folded by the test so the sidebar doesn't run into its footer.
- **No other window in front.** The shot is the screen region under the window, so a notification, a permission prompt or another app on top ends up in it. Headless Chrome used to trigger a "find devices on local networks" prompt; the compose scripts now pass `--disable-features=MediaRouter` to avoid it, but dismiss any prompt on screen before capturing.
- **Screen Recording is not needed.** `screencapture -l <window id>` was tried and fails without that permission, so the test takes its own screenshot instead.

### Compose

```bash
python3 app-store/tools/compose.py iphone     # also ipad and mac; the devices shot reads each device's raw library capture
python3 app-store/tools/card.py               # the closing card, last in each set
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" App/AppIcon.icon --export-image \
  --output-file app-store/images/icon/app-icon.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
python3 app-store/tools/creative.py           # after an icon change
```

`compose.py` skips a scene whose raw capture is missing and prints it, which also shifts the numbering, so capture everything before composing for real. Delete old `images/<device>/*.jpg` first when the lineup changes, since files are named by position and caption id.

### Notes from making these

- **iPad needs an iOS 27 simulator.** The sidebar's category groups start folded only on iOS 27; on 26.x every group is expanded and the list runs off the bottom.
- **Use a dedicated simulator.** One last used by another app shows that app's "back" link in the status bar.
- **Fresh install every run.** `capture.sh` reinstalls the app because it remembers which sidebar sections are open. It seeds a new library each run with `tools/seed.py` (recipes in `tools/seed/recipes.json`, photos in `tools/seed/photos/`) and points the app at it with `RECIPES_DIR`.
- **The widget extension crashes the simulator test runner.** `TimerWidget` crashes at launch ("Critical process TimerWidget crashed", an assertion in `_EXRunningExtension._start`) and fails the run. Delete it from the *built* app and re-sign ad hoc: `rm -rf <DerivedData>/Build/Products/Debug-iphonesimulator/Recipes.app/PlugIns/TimerWidget.appex && codesign --force --sign - --preserve-metadata=entitlements <that .app>`. A rebuild brings it back, so repeat this after every `build-for-testing`. The crash itself is worth a look.
- **`xcodebuild` lingers after the test passes.** It sits on package resolution until a timeout, which used to cost two minutes per scene. `capture.sh` and `capture-mac.sh` now stop it as soon as the screenshot exists, so a "failed" message means a real failure.
- **The UI tests do nothing unless `APP_STORE_SCENE` is set**, so they are safe to leave in the suite.
- **The import scene needs the fake page.** `capture.sh` and `capture-mac.sh` serve `tools/seed/site` on port 8765 and the test imports `http://localhost:8765/lemon-herb-gnocchi.html`.
- **Landscape captures carry an orientation flag.** `capture.sh` ends each scene with `magick -auto-orient`.
- **Free disk space.** The simulator, Mac and Xcode builds together are several GB, and a full disk fails builds with confusing "database or disk is full" errors.
- **Both capture sets are safe to commit.** Only fictional data and CC0 photos appear. The raw captures in `tools/raw/` are git-ignored; check any Mac raw capture for other apps' windows before sharing it.

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
