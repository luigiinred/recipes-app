# Recipes for iPhone, iPad and Mac

The SwiftUI app, share extension, `RecipeKit` package and `recipes` command-line tool. Part of the [Recipes monorepo](../../README.md); everything here is relative to `apps/ios`.

A recipe manager synced through iCloud Drive, with a command-line tool for agents. The CLI can also mirror a library with a self-hosted [server](../server/README.md) (`recipes sync`).

## Features

- **Recipes** with photos, shown as a compact list (default) or photo cards. One tap toggles between them. On iPhone the Recipes tab opens on a home list (All Recipes, Most Recent, Favorites or Top Rated) and your categories; tap a category to see its subcategories and recipes, and keep drilling (`Dessert` → `Cookies`). On Mac it is a three-column split: collections and the category tree, the recipes in the one you pick, and the recipe. On iPad the tab bar is built into the sidebar, so Recipes, Plan, Groceries, Settings and Search sit in one list; the same control switches back to a tab bar across the top. The Recipes tab is a list beside the recipe, and its filter menu narrows the list to a collection or category.
- **Organizing**: favorites or one-to-five star ratings (chosen in Settings; Top Rated lists 4 and 5 stars), the Up Next queue, and nested categories (`Dinner/Pasta`).
- **Import** from any recipe web page (schema.org data), from **YouTube** videos, from a scanned book page (camera or photo/PDF), or by typing it in. Every import opens a review step for the title and categories, including from the Share sheet.
- **YouTube**: the video stays pinned above the recipe while you scroll, and cook mode shows it too, jumping to each step's moment as you move through the steps. The recipe is read from the description. When the description has none, the video's captions are used, structured by the on-device language model where available. Each step gets a timestamp, and the video plays inline on the recipe page. Tap a step's time to jump there.
- **Photos**: imported with the recipe, picked from your library, or created with Image Playground. The recipe's title, summary, main ingredients, cooking method, and serving notes seed the picture.
- **Cook mode**: large step-by-step text, keeps the screen awake, several recipes at once, timers detected from the step text.
- **Plan** tab, in two parts. **Up Next** is a reorderable queue of recipes you mean to cook soon: swipe any recipe left (or tap the Up Next button on its page) to queue it, and it leaves the queue when you plan it. **My Week** lists the seven days with each day's meals; add a meal from Up Next or the whole library, or jot down an idea ("Spaghetti", "Leftovers") that you don't have a recipe for yet (it is saved in your library as an idea, so you can plan it again and fill it in later), move it between days and meals from its menu, or tap **Smart Plan** to have Apple Intelligence fill the empty slots from your recipes (Up Next and favorites first). Without Apple Intelligence a simple rotation fills them instead, and you review the plan before it is added.
- **Groceries** syncs both ways with a "Groceries" list in the Reminders app. The ⋯ menu has Clear Completed, Clear All (asks first), and the Reminders sync switch.
- **Siri and Shortcuts** (App Intents): save a recipe from a link (for example one sent to you in Messages), find a recipe, start cooking, and add a recipe's ingredients to groceries. Recipes are indexed for Spotlight.
- **Search** lives in the tab bar on iPhone: a separate button that grows into a full search bar and tucks the tabs away.
- **Settings** (gear on iPhone, ⌘, on Mac), grouped into pages: **Recipes** (list style, favorites or stars, which swipe actions show including Delete, review-before-saving imports), **Planner** (default meal, week start, meals to plan), **Cooking** (keep the screen awake), **Groceries** (Reminders sync), **Apple Intelligence**, and **Data & Developer** (export all data as JSON: every recipe, photo as base64, planned meal, grocery item, and feed).
- **Ingredient sections** ("Potato chips", "Cinnamon sugar"): add headings by hand in the editor, or tap **Group with Apple Intelligence** to sort a long list by the part of the dish it's for. Scans and video descriptions with `For the sauce:` lines get sections automatically. Under every step, chips show the ingredients that step uses (matched from the step's text), and cook mode lists them in large type.
- **Ingredients** show the amount in bold and the preparation in grey italics (`**2 tbsp** butter *softened*`).
- **Welcome tour**: shown once on the first launch with an empty library (Settings → Show Welcome Tour replays it). It explains Share → Save to Recipes with a mock share sheet, then offers photo cards for real recipes from AllRecipes, BBC Good Food and two YouTube videos (previews load in the background) and imports them through the normal review and save steps, then tries Up Next and Groceries on the recipe you saved.
- **Developer Tools** (Settings): add built-in sample recipes, a sample week plan and groceries, or import a batch of real recipes (AllRecipes, Tasty, Serious Eats, BBC Good Food, Food Network, YouTube) to try every importer.
- The share extension opens the same editor as the app and, once saved, offers **Open in Recipes** (`recipes://recipe/<id>`).
- **Apple Intelligence** (Settings shows what's ready on this device, and why when it isn't): writing a recipe from a video's captions, grouping ingredients, and Image Playground photos. When the model isn't available, imports still work and say why.
- **Printing** and sharing.
- Layouts respond to width (ingredients and steps sit side by side when there's room), including iPad multitasking, landscape, and wide dual-screen canvases.
- Feeds (subscribing to recipe blogs) are built but hidden behind `AppFeatures.feeds`.

## Recipe format

Recipes are saved in one standard form, whether they come from the editor, an import, the on-device model, or an agent using the CLI. Ingredients are `quantity unit item` (`1 1/2 cups flour`, `2 cloves garlic, minced`), and the editor edits them as separate quantity, unit (a preset list), and item fields. Steps are short imperative sentences without numbering. Tags stay generic: main ingredient, vegetarian/vegan, and course (never ingredient lists or site keywords). `recipes schema` prints the full rules, which are also given to the on-device model; saving normalizes anything that doesn't follow them. Steps can have a photo each (picked in the editor, or taken from a web page's step images).

## Layout

- `Sources/RecipeKit`: models, file store, importers (web, YouTube), parsers, timestamp alignment, and the server sync client. Shared by the app and CLI.
- `Sources/recipes`: the `recipes` CLI.
- `App/`: SwiftUI app (iOS + macOS). `ShareExtension/`: "Save to Recipes" in the share sheet.
- `project.yml` generates `Recipes.xcodeproj` with XcodeGen.
- Every recipe, meal, grocery item, and feed is its own JSON file (and photos are JPEGs) in the iCloud container, so iCloud syncs them independently and never merges file contents:

  ```
  Documents/Recipes/<uuid>.json   Documents/Images/<uuid>.jpg
  Documents/Calendar/<uuid>.json  Documents/Groceries/<uuid>.json  Documents/Feeds/<uuid>.json
  Documents/StepImages/<uuid>.jpg
  ```

## Build

Run these from `apps/ios`.

```bash
cp .env.example .env              # once: your team ID, bundle ID and iCloud container
bin/generate.sh                   # creates Recipes.xcodeproj from .env
open Recipes.xcodeproj            # run the Recipes scheme on Mac or iPhone
swift test                        # RecipeKit unit tests
bin/install_cli.sh                # installs `recipes` to ~/.local/bin
```

iCloud setup: the container `iCloud.com.garrabrant.recipes` must exist on the developer team (Xcode creates it on the first signed build with automatic signing). Open the app once on the Mac so the container exists before using the CLI. Set `RECIPES_DIR` to point the app or CLI at another library folder (handy for demos).

## Snapshot tests

Snapshots use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) and live in `RecipesTests/__Snapshots__/<Suite>/`. Coverage is tiered in `SnapshotSupport.swift`: simple sheets get one light capture, normal screens get light and dark on iPhone (light on Mac), and the few screens whose layout changes with width also get iPhone landscape, an unfolded dual-screen/iPad-sized canvas, and a narrow Mac window. Sample data comes from `App/SampleData.swift` (the photos are generated placeholders).

```bash
# iOS (iPhone 17 simulator, iOS 27.0 only)
xcodebuild test -project Recipes.xcodeproj -scheme Recipes -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath build-ios CODE_SIGNING_ALLOWED=NO -only-testing:RecipesTests

# macOS 27.0 only (ad-hoc signed and unsandboxed so references can be written into the repo)
xcodebuild test -project Recipes.xcodeproj -scheme Recipes -destination 'platform=macOS' -derivedDataPath build-mac CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER= DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS= ENABLE_APP_SANDBOX=NO -only-testing:RecipesTests

# UI tests: click the Mac sidebar, and tap the iPhone search button, in the real app (same flags, with -only-testing:RecipesUITests)
```

Missing references are recorded on the first run (that run reports a failure); run again to verify. To re-record after an intended UI change, delete the PNGs or prefix the command with `TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all`.

## CLI (for agents)

Install the prebuilt, notarized binary (macOS, universal x86_64 + arm64):

```bash
curl -fL https://github.com/luigiinred/recipes-app/releases/latest/download/recipes.zip \
  -o /tmp/recipes.zip \
  && unzip -o /tmp/recipes.zip -d /tmp/recipes-cli \
  && mkdir -p ~/.local/bin \
  && install -m 0755 /tmp/recipes-cli/recipes ~/.local/bin/recipes \
  && rm -rf /tmp/recipes.zip /tmp/recipes-cli \
  && ~/.local/bin/recipes --help
```

`~/.local/bin` must be on your `PATH`. To build from source instead, run `bin/install_cli.sh`.

```bash
recipes list [--tag soup] [--collection favorites|want-to-cook|recent|uncategorized] [--json]
recipes show "tomato soup" [--json]       # id, id prefix, or title; step timestamps print as links
recipes search tomato basil [--json]
recipes add --title "Soup" --ingredient "6 tomatoes" --step "Simmer." --tag soup [--image photo.jpg]
recipes add --from recipe.json            # or `--from -` for stdin; an existing id is replaced
recipes import https://example.com/recipe # web page or YouTube video; saves the photo too
recipes transcript https://youtu.be/ID    # captions, when the description has no recipe
recipes timestamps "Shakshuka"            # find where each step is spoken in the video
recipes image "Soup" photo.jpg            # file or URL
recipes mark "Soup" --favorite true --rating 4 --want-to-cook true   # want-to-cook = Up Next queue
recipes scan page.jpg [--save]            # text recognition on a photo or PDF
recipes plan [add|remove|list] ...        # meal calendar
recipes groceries [add|add-recipe|check|remove|clear|list] ...   # the app mirrors these into Reminders
recipes feeds [add|remove|entries|list] ...
recipes sections "Soup" [--save]            # group ingredients into sections (on-device model)
recipes ai-check                          # is Apple Intelligence ready? tries the recipe-writing model
recipes export [-o all.json]              # everything as one JSON document
recipes sync [--server URL]               # mirror the library folder with a self-hosted server (token in RECIPES_TOKEN)
recipes delete <id>
recipes schema                            # example JSON
recipes path                              # library folder
```

### Syncing with a server

```bash
export RECIPES_SERVER=https://recipes.example.com
export RECIPES_TOKEN=rcp_...        # create one in the server's web UI under Settings
RECIPES_DIR=~/recipes-copy recipes sync
```

Each pass uploads what changed here, downloads what changed on the server and carries deletions both ways; when both sides edited a recipe the later edit wins, and a pass that would delete most of the library stops and asks for `--allow-mass-deletion`. Without `RECIPES_DIR` it syncs the iCloud folder, which is also the way to move an iCloud library onto a server. The protocol is in [`docs/sync-protocol.md`](../../docs/sync-protocol.md).

Only `title` is required in recipe JSON. `stepTimestamps` is an optional array of seconds parallel to `steps` (`null` for none).

The release workflow (`.github/workflows/release-cli.yml` at the repository root) builds the universal binary, signs it with a Developer ID, notarizes it, and attaches `recipes.zip` to every `v*` release. It needs these repository secrets: `CERTIFICATE_P12` (base64 Developer ID Application `.p12`), `CERTIFICATE_P12_PASSWORD`, `KEYCHAIN_PASSWORD` (any value), and `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_AUTH_KEY` (the App Store Connect API key used for notarization).

## Limitations

- The first launch asks for access to Reminders. Without it, the grocery list still works but stays in the app (and the CLI).
- Image Playground needs Apple Intelligence, and it makes illustrations or stylized images, not photographs.
- Siri's ability to find a link "your wife sent" depends on Apple Intelligence's personal context; the intents themselves take a plain link, so they also work from Shortcuts.
- In Mac snapshots, the selected sidebar row draws as a black block (an offscreen-rendering artifact; the real app is fine).

- YouTube import depends on YouTube's unofficial caption endpoints, which can change. Videos without captions or a recipe in the description import as a draft to finish by hand.
- Step timestamps are matched by comparing step words to the captions, so a step may get none or a time a few seconds off. They are editable.
- The on-device model needs a device with Apple Intelligence; otherwise YouTube videos without a recipe in the description open as a draft with the captions alongside.
