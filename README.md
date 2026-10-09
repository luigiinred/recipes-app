# Recipes

A recipe manager for iPhone, iPad, and Mac, synced through iCloud Drive, with a Mac command-line tool for agents.

## Layout

- `Sources/RecipeKit` — recipe model and the file-based store shared by the app and the CLI
- `Sources/recipes` — the `recipes` CLI
- `App/` — SwiftUI app (iOS + macOS); `project.yml` generates `Recipes.xcodeproj` with XcodeGen
- Each recipe is one JSON file (`<uuid>.json`) in the iCloud container's `Documents/Recipes` folder, so iCloud syncs files independently and never merges them.

## Build

```bash
xcodegen generate                      # creates Recipes.xcodeproj
open Recipes.xcodeproj                 # run the Recipes scheme on Mac or iPhone
swift test                             # RecipeKit tests
bin/install_cli.sh                     # installs `recipes` to ~/.local/bin
```

iCloud setup: the container `iCloud.com.garrabrant.recipes` must exist on the developer team (Xcode creates it on first signed build with automatic signing). Open the app on the Mac once so the container exists before using the CLI.

## CLI (for agents)

```bash
recipes list [--tag soup] [--json]
recipes show "tomato soup" [--json]     # id, id prefix, or title
recipes search tomato basil [--json]
recipes add --title "Soup" --ingredient "6 tomatoes" --step "Simmer." --tag soup
recipes add --from recipe.json          # or `--from -` for stdin; an existing id is replaced
recipes delete <id>
recipes schema                          # example JSON
recipes path                            # recipe folder
```

Only `title` is required in JSON. Use `--dir` or `RECIPES_DIR` to point at another folder (handy for testing).
