# Recipes

A recipe manager for iPhone, iPad and Mac, and a self-hostable server with a web UI for people who'd rather keep their recipes on their own machine than in iCloud.

| | |
|---|---|
| [`apps/ios`](apps/ios) | The SwiftUI app (iOS and macOS), the share extension, the shared `RecipeKit` Swift package and the `recipes` command-line tool. Stores its library in iCloud Drive. |
| [`apps/server`](apps/server) | A Node server: REST API, file-sync endpoints and the built web UI, in one process. Stores the library as plain files. |
| [`apps/web`](apps/web) | The web UI (React + Vite). Browse, edit, import from a web page, plan the week, keep a grocery list, cook step by step. |
| [`packages/schema`](packages/schema) | The recipe data model and helpers (ingredient parsing, categories, collections), shared by the server and the web UI. |
| [`docs`](docs) | The [sync protocol](docs/sync-protocol.md) and [syncing the app with Mealie](docs/mealie.md). |
| [`Design`](Design) | App icon sources. |

Both sides use the same library format: one JSON file per recipe, meal, grocery item and feed, plus JPEG photos. A library can be copied between an iCloud folder and the server's data folder as is, and the server's "Download everything" produces the same document as the app's "Export all data".

## Run the server

```bash
docker compose up -d
docker compose logs recipes     # prints the one-time setup code
```

Open <http://localhost:8080>, enter the setup code and choose a password. [`apps/server/README.md`](apps/server/README.md) covers configuration, HTTPS, backups, moving an existing library in, and the API.

From source (Node 22 or newer):

```bash
npm ci
npm run build
npm start                       # http://127.0.0.1:8080, library in ./apps/server/data
```

## Develop

```bash
npm ci
npm run dev        # server on :8080 with reload, web UI on :5173 (proxies /api)
npm run typecheck
npm test           # schema, server and web tests
```

The iOS app and `RecipeKit`:

```bash
cd apps/ios
cp .env.example .env   # once: fill in your team ID, bundle ID and iCloud container
bin/generate.sh && open Recipes.xcodeproj
swift test         # RecipeKit unit tests
```

See [`apps/ios/README.md`](apps/ios/README.md) for features, snapshot tests, the CLI and releases.

## Status

- The server and web UI are complete for browsing, editing, importing web pages, planning, groceries and cook mode. Importing from YouTube, scanning a page, Smart Plan and photo generation are app features that need on-device frameworks; they aren't in the web UI.
- The `recipes` CLI can sync a library folder with a server (`recipes sync`). The iPhone and Mac apps don't have a "use my server" option yet: the share extension needs an App Group to share a local copy with the app, which is an Apple Developer account change. Until then the apps keep using iCloud.

## License

[MIT](LICENSE).
