# recipes-cli Specification

## Purpose
The `recipes` command-line tool on macOS reads and writes the same library folder the app uses, so people and agents can list, add, import, plan and shop from a terminal. Syncing with a server (`recipes sync`) is covered by library-sync and syncing with Mealie (`recipes mealie`) by mealie-sync.

## Requirements

### Requirement: Library location
Every command that touches the library SHALL use the folder given by `--dir`, else `RECIPES_DIR`, else the app's iCloud Drive library (the configured iCloud container, or the single `iCloud~…~recipes` container in `~/Library/Mobile Documents` that holds a `Documents/Recipes` folder), else a local `Application Support/Recipes` folder. `recipes path` prints the folder in use.

#### Scenario: Override
- **WHEN** the user runs `RECIPES_DIR=~/demo recipes path`
- **THEN** it prints the expanded `~/demo` path

#### Scenario: No iCloud library
- **GIVEN** no iCloud library, `--dir` or `RECIPES_DIR`
- **WHEN** the user runs `recipes add --title Soup`
- **THEN** the recipe is saved in the local folder
- **AND** a note on standard error says the iCloud library wasn't found and to open the Recipes app once to enable sync

### Requirement: Finding a recipe
Commands that take a recipe argument SHALL accept a full id, an exact title (case-insensitive), an id prefix, or a part of the title, tried in that order. No match fails with a not-found error; several matches fail with an ambiguity error listing each candidate's 8-character id and title.

#### Scenario: Ambiguous title fragment
- **GIVEN** recipes "Tomato Soup" and "Tomato Salad"
- **WHEN** the user runs `recipes show tomato`
- **THEN** the command fails and lists both recipes with their short ids

### Requirement: Listing, showing and searching
`recipes list` SHALL print each recipe's 8-character id, title and tags, optionally limited by `--tag` (case-insensitive exact tag) and `--collection` (`recent`, `up-next` or `want-to-cook`, `favorites`, `top-rated`, `uncategorized`; anything else is an error). `recipes show <recipe>` prints the recipe as Markdown, and `recipes search <words>` lists recipes matching all the words in titles, ingredients, tags and notes. Each takes `--json` to print full recipes as JSON instead.

#### Scenario: Unknown collection
- **WHEN** the user runs `recipes list --collection bogus`
- **THEN** it fails with `Unknown collection "bogus".`

#### Scenario: JSON output
- **WHEN** the user runs `recipes list --json`
- **THEN** it prints a JSON array of complete recipe documents

### Requirement: Adding and replacing recipes
`recipes add` SHALL create a recipe from `--title`, `--summary`, `--servings`, `--prep`, `--cook`, repeatable `--ingredient`, `--step` and `--tag`, `--source` and `--notes`, or read one recipe object or an array from `--from <file>` (or `-` for standard input). With `--from`, a recipe whose id already exists is replaced. Every saved recipe is normalized to the standard form (see recipe-format), needs a title, and gets a new `updatedAt`. `--image <file>` sets the photo of a single saved recipe. It prints "Saved <short id>  <title>" per recipe, or the saved recipes with `--json`.

#### Scenario: From standard input
- **WHEN** an agent pipes a JSON array of two recipes into `recipes add --from -`
- **THEN** both are saved and two "Saved" lines are printed

#### Scenario: Missing title
- **WHEN** the user runs `recipes add` with neither `--title` nor `--from`
- **THEN** it fails with "Provide --title or --from."

#### Scenario: Image with several recipes
- **WHEN** the user runs `recipes add --from many.json --image photo.jpg` and the file holds several recipes
- **THEN** it fails with "--image works with a single recipe."

### Requirement: Format reference
`recipes schema` SHALL print an example recipe in the JSON format `add --from` accepts, followed by the recipe format rules (the same rules given to the on-device model).

#### Scenario: Schema
- **WHEN** an agent runs `recipes schema`
- **THEN** it prints an "Example Pancakes" recipe as JSON and then the format rules

### Requirement: Importing and media commands
`recipes import <url>` SHALL import a web page or YouTube video and save the recipe with its photo (see web-import and youtube-import), printing any importer warning on standard error; non-`http(s)` input is refused. `recipes image <recipe> <file-or-url>` sets a recipe's photo from a file or an `http(s)` URL, re-encoded as JPEG. `recipes scan <file>` reads a recipe from a photo or PDF (see scan-import) and saves it only with `--save`. `recipes transcript <youtube-url>` prints a video's captions (with `--with-description`, also its title, channel and description), and `recipes timestamps <recipe>` finds and saves where each step is spoken in the recipe's video.

#### Scenario: Not a web address
- **WHEN** the user runs `recipes import notes.txt`
- **THEN** it fails with "Not a web URL: notes.txt"

#### Scenario: Timestamps without a video
- **WHEN** the user runs `recipes timestamps` on a recipe not imported from YouTube
- **THEN** it fails saying the recipe wasn't imported from a YouTube video

### Requirement: Marking and deleting
`recipes mark <recipe>` SHALL set `--favorite true|false`, `--want-to-cook true|false` (the Up Next queue; joining it sets the queue time) and `--rating 1-5` (0 clears; other values are an error), then print the resulting favorite, rating and up-next state. `recipes delete <recipe>` deletes the recipe with its photos.

#### Scenario: Clearing a rating
- **WHEN** the user runs `recipes mark Soup --rating 0`
- **THEN** the recipe has no rating and the output shows `rating=none`

### Requirement: Meal plan commands
`recipes plan` (default `list`) SHALL list planned meals from `--from` (a `YYYY-MM-DD` day, `today` or `tomorrow`; default today) for `--days` days (default 14), soonest first and by meal within a day. `recipes plan add <recipe> --date <day> [--meal breakfast|lunch|dinner|snack]` plans a recipe (dinner by default), and `recipes plan remove <id-prefix>` removes a planned meal. Lists take `--json`.

#### Scenario: Bad date
- **WHEN** the user runs `recipes plan add Soup --date someday`
- **THEN** it fails with `Use YYYY-MM-DD, today, or tomorrow (got "someday").`

### Requirement: Grocery commands
`recipes groceries` (default `list`) SHALL list items unchecked first, oldest first, as `[ ]` or `[x]` with quantity and short id. `add <text>...` adds items, splitting a leading quantity from each text; `add-recipe <recipe>` adds every ingredient of a recipe, skipping ones whose name and quantity match an unchecked item; `check <id-prefix>` checks an item off (`--undo` unchecks it); `remove <id-prefix>` removes one; and `clear` removes all checked items. Id prefixes matching several items fail with the candidates listed.

#### Scenario: Adding a recipe's ingredients twice
- **GIVEN** `recipes groceries add-recipe Soup` already added its ingredients
- **WHEN** the user runs it again
- **THEN** it prints "Added 0 item(s) from Soup"

### Requirement: Feed commands
`recipes feeds` (default `list`) SHALL list subscribed feeds, `add <url>` subscribes to a feed or a site that has one, `remove <feed>` unsubscribes by id prefix or title, and `entries <feed> [--limit N]` prints the latest posts (20 by default) with their date and link (see feeds).

#### Scenario: Reading a feed
- **WHEN** the user runs `recipes feeds entries "Smitten" --limit 5`
- **THEN** it prints up to five posts with their dates and links

### Requirement: Export
`recipes export` SHALL write every recipe, photo, planned meal, grocery item and feed as one JSON document, the same format the app and server export, to standard output or to the file given by `-o`/`--output`.

#### Scenario: Export to a file
- **WHEN** the user runs `recipes export -o all.json`
- **THEN** the document is written to `all.json` and the command prints its path

### Requirement: On-device model commands
`recipes sections <recipe>` SHALL group a recipe's ingredients into sections with the on-device model, print the result and save it only with `--save`; it reports when the ingredients belong together or the model is unavailable. `recipes ai-check` reports whether Apple Intelligence is available and, when it is, times the recipe-writing model on short and very long sample captions (see apple-intelligence).

#### Scenario: Model unavailable
- **GIVEN** Apple Intelligence is not available on the Mac
- **WHEN** the user runs `recipes ai-check`
- **THEN** it prints "Apple Intelligence: not available" with the reason and stops
