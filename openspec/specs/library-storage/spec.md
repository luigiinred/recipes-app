# library-storage Specification

## Purpose
Keeps a recipe library as a folder of plain files that the app (iOS, iPadOS, macOS), the `recipes` CLI and the server all read and write in the same layout, decides where that folder lives on each platform, and exports or restores the whole library as one JSON document.

## Requirements

### Requirement: Library folder layout
The system SHALL store a library as a root folder with six subfolders: `Recipes/<id>.json`, `Calendar/<id>.json` (planned meals), `Groceries/<id>.json`, `Feeds/<id>.json`, `Images/<id>.jpg` (a recipe's cover photo, named by the recipe id) and `StepImages/<id>.jpg` (step photos, named by the ids in a recipe's `stepImages`). File names use the lowercase id. Each recipe, meal, grocery item and feed is its own file, so iCloud syncs them independently and never merges file contents. The same layout is used in the iCloud container's `Documents` folder and in the server's data folder, so a library can be copied between them as is.

#### Scenario: Saving a recipe writes one file
- **WHEN** a recipe with id `E621E1F8-C36C-495A-93FC-0C247A3E6E5F` is saved
- **THEN** it is written to `Recipes/e621e1f8-c36c-495a-93fc-0c247a3e6e5f.json` under the library root

#### Scenario: Copying a library to the server
- **GIVEN** the contents of an iCloud library's `Documents` folder copied into the server's data folder
- **WHEN** the server lists recipes
- **THEN** the copied recipes, photos, planned meals, groceries and feeds appear

### Requirement: Category order file
The app SHALL save the user's chosen category order as `CategoryOrder.json` in the library root, a JSON list of category paths, so the order follows the library through iCloud to the user's other devices. A missing or unreadable file means no chosen order. The server, server sync and the export document do not carry this file.

#### Scenario: Order persists
- **WHEN** the app saves the order "Dessert", "Dinner"
- **THEN** `CategoryOrder.json` in the library root holds `["Dessert","Dinner"]` and loading it returns that list

#### Scenario: No order yet
- **GIVEN** a library without `CategoryOrder.json`
- **WHEN** the app loads the category order
- **THEN** it is empty and categories are alphabetical

### Requirement: JSON file encoding
The system SHALL write library documents as pretty-printed JSON with keys in sorted order, unescaped slashes, ISO 8601 dates and no members for absent optional values. Writes replace the file atomically, so a reader never sees a half-written file; the app coordinates reads and writes with other processes using the same files.

#### Scenario: Server matches the app's files
- **WHEN** the server saves a recipe with no servings
- **THEN** the file has sorted keys, no `servings` member, and dates like `2026-01-01T10:00:00Z`

### Requirement: Unreadable files are skipped
The system SHALL skip, rather than fail on, files in a library folder that are not `.json` documents of the expected kind or do not decode, and list everything else. The server also ignores files whose names are not `<uuid>.json`, skips recipe files with a blank title, and logs a warning naming each skipped file.

#### Scenario: A broken file does not hide the library
- **GIVEN** a `Recipes` folder with one valid recipe and one file containing invalid JSON
- **WHEN** the library is listed
- **THEN** the valid recipe is listed and the broken file is left out

### Requirement: Library location in the app
In the app, the share extension and Siri shortcuts, the system SHALL use the folder named by the `RECIPES_DIR` environment variable when it is set (with `~` expanded); otherwise the `Documents` folder of the iCloud container named by `RECIPES_ICLOUD_CONTAINER` or the `RecipesICloudContainer` Info.plist key, when iCloud is available; otherwise a local folder `Recipes` in the user's Application Support directory. The app sidebar footer shows "Synced with iCloud" or "Stored on this device" to match.

#### Scenario: iCloud unavailable
- **GIVEN** no `RECIPES_DIR` and no available iCloud container
- **WHEN** the app starts
- **THEN** it uses Application Support/Recipes and the footer reads "Stored on this device"

#### Scenario: Demo library
- **GIVEN** `RECIPES_DIR=~/recipes-demo`
- **WHEN** the app starts
- **THEN** it reads and writes the library in `~/recipes-demo`

### Requirement: Library location for the CLI
The `recipes` CLI SHALL use the folder given by `--dir`, else `RECIPES_DIR`, else the app's iCloud library on the Mac under `~/Library/Mobile Documents/<container>/Documents`, else the local Application Support/Recipes folder. Without a configured container id, the CLI uses the one `iCloud~…~recipes` folder that contains `Documents/Recipes`, and none when there are several. After saving into the local fallback folder, it prints a note to standard error that the iCloud library was not found and the Recipes app should be opened once to enable sync.

#### Scenario: Explicit folder
- **WHEN** the user runs `recipes list --dir ~/recipes-copy`
- **THEN** the CLI reads the library in `~/recipes-copy`

#### Scenario: Fallback warning
- **GIVEN** no `--dir`, no `RECIPES_DIR` and no iCloud library on the Mac
- **WHEN** the user adds a recipe with the CLI
- **THEN** it is saved under Application Support/Recipes and stderr says "note: iCloud library not found; saved to <path>. Open the Recipes app once to enable sync."

### Requirement: iCloud placeholders are downloaded
When a library folder in iCloud holds a placeholder for a file not yet on the device, the system SHALL ask iCloud to download it and leave it out of the current listing; it appears in a later listing once downloaded. The app re-reads the library every two seconds while running.

#### Scenario: Placeholder recipe
- **GIVEN** `Recipes/.<id>.json.icloud` in the library folder
- **WHEN** the app lists recipes
- **THEN** the download of `<id>.json` starts and the recipe is not yet listed

### Requirement: Server data folder
The server SHALL keep its library in the folder named by `DATA_DIR` (default `./data`, `/data` in Docker), create the six library folders on start, and keep its own password hash, access tokens and cookie secret in `<data>/.server/`. It re-reads a document when its size or modification time changes, so files edited or restored outside the server are picked up while it runs.

#### Scenario: Edited outside the server
- **GIVEN** the server is running
- **WHEN** a recipe file in the data folder is replaced by hand
- **THEN** the next API read returns the new contents

### Requirement: Unknown fields survive server edits
When the server saves a document that already exists on disk, it SHALL keep any fields of the existing file that it does not know about, so documents written by a newer app are not stripped.

#### Scenario: Future field kept
- **GIVEN** a recipe file with an extra field `"difficulty": "easy"`
- **WHEN** the recipe is edited through the server API
- **THEN** the file still contains `"difficulty": "easy"`

### Requirement: Deleting a recipe removes its files
The system SHALL delete a recipe's cover photo and step photos along with its recipe file. In the app and CLI, it also deletes planned meals that point at the recipe, keeping other meals. When the server saves a recipe, it deletes step photos the previous version referenced and the new one no longer does.

#### Scenario: Photos and plan entries removed in the app
- **GIVEN** a recipe with a cover photo, two step photos and a planned meal, and another planned meal for a different recipe
- **WHEN** the recipe is deleted in the app
- **THEN** its recipe file, cover photo, step photos and planned meal are removed and the other planned meal remains

### Requirement: Library export document
The system SHALL export a whole library as one JSON document with `version` (1), `exportedAt`, `recipes`, `mealPlan`, `groceries`, `feeds`, `images` and `stepImages`. `images` maps each lowercased recipe id to its cover photo as base64; `stepImages` maps each lowercased step photo id listed in a recipe to that photo as base64. Recipes are ordered by title, planned meals by day, and groceries and feeds by creation date. The app and the server produce and read the same document, and a document without `stepImages` is accepted.

#### Scenario: Round trip
- **GIVEN** a library with two recipes, one with a cover photo, a planned meal, a grocery item and a feed
- **WHEN** it is exported and the document is read back
- **THEN** it has both recipes, the meal, the grocery item and the feed, and `images` holds only the photographed recipe's photo

#### Scenario: Empty library
- **WHEN** an empty library is exported
- **THEN** the document has empty lists and empty `images`

### Requirement: Export all data in the app
In the app, Settings → Data & Developer SHALL offer "Export all data as JSON" under "Your data", which builds the export document and lets the user save it as a `.json` file named "Recipes Export YYYY-MM-DD". The button is disabled while the export is being built, and a failure shows a "Couldn't export" alert with the error.

#### Scenario: Export from Settings
- **WHEN** the user taps "Export all data as JSON" on 2026-11-03
- **THEN** a save dialog offers the file "Recipes Export 2026-11-03" containing the export document

### Requirement: Download everything and restore on the server
The server SHALL return the export document from `GET /api/export` as an attachment named `recipes-YYYY-MM-DD.json`, and the web UI's Settings → "Your data" SHALL offer it as "Download everything". `POST /api/export/restore` (the web UI's "Restore from an export") SHALL write every item in an export document into the library, replacing items with the same id and deleting nothing, skip recipes with a blank title and photo keys that are not UUIDs, keep only http and https links on restored recipes, and answer with counts of `recipes`, `mealPlan`, `groceries`, `feeds` and `images` written. Restores larger than 512 MB are refused with HTTP 413. The web UI then reloads and shows "Restored N recipes, N planned meals and N grocery items".

#### Scenario: Move a library between servers
- **GIVEN** a server with one recipe with a photo, one planned meal and one grocery item
- **WHEN** its `GET /api/export` document is posted to another server's `/api/export/restore`
- **THEN** the answer is `{recipes: 1, mealPlan: 1, groceries: 1, feeds: 0, images: 1}` and the recipe, its photo and the meal are on the second server

#### Scenario: App export restored on the server
- **WHEN** a document exported by the app, with uppercase recipe ids and no `stepImages`, is restored on the server
- **THEN** the restore succeeds and the recipe can be read by its id

#### Scenario: Path tricks ignored
- **WHEN** an export whose `images` has the key `../../escape` is restored
- **THEN** no image is written and the `images` count is 0
