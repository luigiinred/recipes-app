# Recipes server

A self-hosted home for your recipe library: a REST API, file-sync endpoints for clients that keep their own copy, and the [web UI](../web), in one Node process. Your recipes stay as plain files in a folder you control.

## Run it

**Docker**

```bash
docker compose up -d                 # from the repository root
docker compose logs recipes          # the setup code is printed here
```

or without compose:

```bash
docker build -t recipes-server .
docker run -d --name recipes -p 8080:8080 -v recipes-data:/data recipes-server
```

**From source** (Node 22 or newer):

```bash
npm ci
npm run build
DATA_DIR=/srv/recipes HOST=0.0.0.0 npm start
```

Open the address in a browser. On first run it asks for the **setup code** the server printed (it is also in `<data>/.server/setup-code`) and a password. To skip that page, start the server with `RECIPES_PASSWORD` set; it is used only while no password exists yet.

## Configuration

All settings are environment variables.

| Variable | Default | |
|---|---|---|
| `PORT` | `8080` | Port to listen on. |
| `HOST` | `127.0.0.1` (`0.0.0.0` in the Docker image) | Address to bind. |
| `DATA_DIR` | `./data` (`/data` in Docker) | The library folder. |
| `RECIPES_PASSWORD` | unset | Seeds the owner password on first start. |
| `TRUST_PROXY` | `false` | Believe `X-Forwarded-For`, `-Proto` and `-Host` from a reverse proxy. Set it only when one is in front, or clients can spoof their address. |
| `SESSION_DAYS` | `30` | How long a browser stays signed in. |
| `ALLOW_PRIVATE_IMPORTS` | `false` | Let "Import from the web" fetch from private and loopback addresses (see below). |
| `WEB_DIR` | the built web UI | Folder of static files to serve; `none` runs API-only. |

## Your data

```
<data>/Recipes/<id>.json     <data>/Calendar/<id>.json    <data>/Groceries/<id>.json   <data>/Feeds/<id>.json
<data>/Images/<id>.jpg       <data>/StepImages/<id>.jpg
<data>/.server/              password hash, access tokens, cookie secret (owner-only permissions)
```

This is the same layout as the app's iCloud folder, so:

- **Back up** by copying the folder (or just the six library folders). The server reads files fresh when their size or modification time changes, so a restore can be done with the server running.
- **Move an iCloud library in** by copying `~/Library/Mobile Documents/iCloud~com~garrabrant~recipes/Documents` into the data folder, or with `recipes sync` (below), or by uploading the app's "Export all data" file in Settings → Your data → Restore.
- **Use the command-line tool** against the server's folder with `RECIPES_DIR=<data> recipes list`.

## Security

- Everything under `/api` except sign-in requires the owner password's session cookie or an access token. Passwords are stored as scrypt hashes; sign-in attempts are rate limited per address; changing the password signs every browser out.
- **Put HTTPS in front of it** if it is reachable from anything other than your own machine: passwords and tokens travel in the clear over plain HTTP. For example with Caddy:

  ```
  recipes.example.com {
      reverse_proxy localhost:8080
  }
  ```

  then run the server with `TRUST_PROXY=true`. Without it, every visitor appears to come from the proxy's address, so the sign-in rate limit is shared and cookies aren't marked `Secure` (the server logs a warning when it sees forwarded headers without the setting). Don't set it when nothing is in front of the server: clients could then forge their address.
- Sessions are stateless signed cookies: signing out clears the browser's copy, and changing the password is how you invalidate every session at once. Revoke access tokens individually in Settings.
- Cookie-authenticated requests that change data must come from the server's own pages (`Origin`/`Sec-Fetch-Site` are checked), and the session cookie is `HttpOnly` and `SameSite=Lax`.
- "Import from the web" makes the server fetch a URL you give it. It only follows `http(s)`, refuses loopback, private and link-local addresses at connection time (so DNS tricks don't help), limits redirects, size and time, and only keeps images it recognises by content. Set `ALLOW_PRIVATE_IMPORTS=true` if you need to import from a site on your own network.
- Uploaded photos are served with their sniffed type and `nosniff`; SVG and HTML are refused. Recipe source links are only rendered when they are `http(s)`.
- This is a single-owner server: one library, one password, any number of access tokens. There are no separate user accounts.

## Access tokens

Settings → "Connect the iPhone and Mac apps" creates a named token. A token can do everything the web UI can, so treat it like a password; revoke it there when a device is lost.

```bash
export RECIPES_SERVER=https://recipes.example.com
export RECIPES_TOKEN=rcp_...
recipes sync            # mirror a local library folder with the server
```

`recipes sync` is part of the [command-line tool](../ios/README.md#cli-for-agents). The apps themselves don't have a server option yet; see the [status](../../README.md#status).

## API

JSON over HTTP, authenticated with the session cookie or `Authorization: Bearer <token>`. Errors are `{ "error": "..." }` with a matching status. Documents have the shapes in [`packages/schema`](../../packages/schema/src/index.ts).

| | |
|---|---|
| `GET /api/health`, `GET /api/session` | Liveness; whether you are signed in and whether setup is pending. |
| `POST /api/setup`, `/api/login`, `/api/logout`, `/api/password` | First-run setup, sign in and out, change password. |
| `GET/POST /api/tokens`, `DELETE /api/tokens/:id` | Access tokens. A new token's value is returned once. |
| `GET /api/recipes` | All recipes, plus `imageVersion`. Filters: `q`, `tag`, `collection` (`all`, `recent`, `up-next`, `favorites`, `top-rated`, `uncategorized`). |
| `POST /api/recipes`, `GET/PUT/PATCH/DELETE /api/recipes/:id` | `PUT` replaces; `PATCH` takes `isFavorite`, `rating`, `wantToCook`, `tags`, `notes`. Saving tidies ingredients, steps and tags into the app's standard form. |
| `GET/PUT/DELETE /api/recipes/:id/image` | Cover photo (raw image bytes). |
| `GET /api/step-images/:id` | A step's photo. |
| `GET/POST /api/meal-plan`, `PUT/DELETE /api/meal-plan/:id` | Planned meals (`?from=&to=` as `YYYY-MM-DD`). Planning a queued recipe takes it out of Up Next. |
| `GET/POST /api/groceries`, `PATCH/DELETE /api/groceries/:id`, `POST /api/groceries/clear` | Shopping list. `POST` takes one item or an array and skips duplicates. |
| `POST /api/import` | `{ "url" }` → a recipe draft and photo read from the page's schema.org data. Nothing is saved. |
| `GET /api/export`, `POST /api/export/restore` | The whole library as one JSON document, the same one the app exports. |
| `GET/PUT/DELETE /api/sync/files/...` | File-level sync; see [the protocol](../../docs/sync-protocol.md). |

## Limits

- Import reads web pages with schema.org recipe data. YouTube import, page scanning and Smart Plan need the apps' on-device frameworks and aren't here.
- Photos are stored as uploaded (the web UI scales them to 2000 px first). The server doesn't resize or convert images.
- Ingredient and step tidying follows the app's rules; the app's ingredient-section grouping and tag vocabulary clean-up are only partly mirrored, and the apps tidy anything the server leaves alone the next time they save it.

## Develop

```bash
npm ci                           # at the repository root
npm run dev -w @recipes/server   # reloads on change
npm test -w @recipes/server
```

Tests run the whole app in memory against a temporary data folder (`test/helpers.ts`), including the sync endpoints and the importer against a local HTTP server.
