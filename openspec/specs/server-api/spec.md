# server-api Specification

## Purpose
The self-hostable Node server keeps one recipe library as plain files in a data folder and exposes it as a JSON REST API, alongside the file-sync endpoints (see library-sync) and the built web UI (see web-ui). It runs from source or as a Docker image.

## Requirements

### Requirement: Environment configuration
The server SHALL read its configuration from environment variables: `PORT` (default `8080`), `HOST` (default `127.0.0.1`), `DATA_DIR` (default `./data`), `RECIPES_PASSWORD` (unset), `TRUST_PROXY` (off), `SESSION_DAYS` (default `30`), `ALLOW_PRIVATE_IMPORTS` (off) and `WEB_DIR` (the built web UI). Boolean flags accept `1`, `true`, `yes` or `on`, case-insensitively. `PORT` and `SESSION_DAYS` must be positive integers, otherwise the server refuses to start with an error naming the variable.

#### Scenario: Invalid number
- **WHEN** the server starts with `SESSION_DAYS=0`
- **THEN** it fails with an error saying `SESSION_DAYS must be a positive integer`

#### Scenario: API-only mode
- **WHEN** the server starts with `WEB_DIR=none`
- **THEN** it serves only the `/api` routes and logs that the web UI is disabled

### Requirement: Docker image
The repository SHALL ship a Dockerfile and a `docker-compose.yml` that run the server as a non-root user with `HOST=0.0.0.0`, `PORT=8080`, `DATA_DIR=/data` (a volume) and the built web UI, and a health check that polls `GET /api/health`.

#### Scenario: Compose start
- **WHEN** the user runs `docker compose up -d` from the repository root
- **THEN** the server listens on port 8080 with its library in the `recipes-data` volume
- **AND** the first-run setup code appears in `docker compose logs recipes`

### Requirement: Library folder layout
The server SHALL store the library under the data folder in the same layout as the app's iCloud `Documents` folder: `Recipes/`, `Calendar/`, `Groceries/` and `Feeds/` hold one `<id>.json` file each, and `Images/` and `StepImages/` hold `<id>.jpg` photos. It creates these folders on start and keeps its own password hash, tokens and cookie secret in `.server/`, outside them. Files changed on disk are read fresh when their size or modification time changes, so a copied-in or restored library is picked up while the server runs.

#### Scenario: Reading app-written files
- **GIVEN** a recipe file written by the iOS app with an uppercase id
- **WHEN** a client requests `GET /api/recipes/<id>`
- **THEN** the recipe is returned with its id and step-photo ids in lowercase

#### Scenario: Unknown fields survive edits
- **GIVEN** a recipe file containing a field the server doesn't know
- **WHEN** the recipe is changed with `PATCH` or `PUT`
- **THEN** the saved file still contains that field

### Requirement: JSON error responses
The API SHALL answer errors as `{ "error": "<message>" }` with a matching HTTP status: `400` for a body that isn't JSON, `422` for a body that fails validation (the message names the first invalid field), `404` for unknown ids, and `500` with a generic message for unexpected failures. Ids in URLs must be UUIDs; anything else is a `404` without touching the disk. Authenticated API responses carry `Cache-Control: no-store` unless they set their own caching.

#### Scenario: Not an id
- **WHEN** a client requests `GET /api/recipes/..%2F..%2Fetc%2Fpasswd`
- **THEN** the server answers `404`

#### Scenario: No caching
- **WHEN** a signed-in client requests `GET /api/recipes`
- **THEN** the response has `Cache-Control: no-store`

### Requirement: Request size limits
The server SHALL refuse JSON request bodies larger than 2 MB with `413`, including on the sign-in routes, while allowing recipe photo uploads up to 15 MB, sync file uploads up to 25 MB and library restores up to 512 MB.

#### Scenario: Oversized recipe
- **WHEN** a client posts a recipe whose notes are 3 MB long
- **THEN** the server answers `413`

#### Scenario: Large photo
- **WHEN** a client uploads a 5 MB JPEG as a recipe photo
- **THEN** the upload succeeds

### Requirement: Recipe endpoints
The server SHALL provide `GET /api/recipes`, `POST /api/recipes`, and `GET`, `PUT`, `PATCH` and `DELETE /api/recipes/:id`. Recipes are returned sorted by title, each with an `imageVersion` (the photo's version number, or `null` without a photo). `POST` creates a recipe (with a new id unless one is given; an existing id is `409`) and answers `201`. `PUT` replaces the recipe, keeping its `createdAt`; an id in the body that differs from the URL is `422`. `PATCH` accepts only `isFavorite`, `rating` (1 to 5, or `null` to clear), `wantToCook`, `tags` and `notes`. A recipe needs a non-blank title. Saving tidies ingredients, steps and tags into the standard form (see recipe-format), drops `sourceURL` and `imageURL` values that aren't `http(s)`, and deletes step photos the recipe no longer references. Deleting a recipe also deletes its photo and step photos.

#### Scenario: Create and tidy
- **WHEN** a client posts `{ "title": "  Tomato   Soup ", "ingredients": ["2 Tablespoons butter"], "steps": ["Step 1: simmer"] }`
- **THEN** the server answers `201` with title `Tomato Soup`, ingredient `2 tbsp butter`, step `Simmer.` and `imageVersion: null`

#### Scenario: Patch outside the allowed fields
- **WHEN** a client sends `PATCH /api/recipes/:id` with `{ "title": "x" }` or `{ "rating": 9 }`
- **THEN** the server answers `422`

#### Scenario: Queueing sets a queue time
- **WHEN** a client patches a recipe with `{ "wantToCook": true }`
- **THEN** the returned recipe has a `queuedAt` time
- **AND** patching `{ "wantToCook": false }` removes it

#### Scenario: Unsafe links
- **WHEN** a client creates a recipe with `sourceURL` `javascript:alert(1)`
- **THEN** the saved recipe has no `sourceURL`

### Requirement: Recipe list filters
`GET /api/recipes` SHALL accept optional `q` (search text), `tag` (a category, including its subcategories) and `collection` (`all`, `recent`, `up-next`, `favorites`, `top-rated` or `uncategorized`) filters, applied together. An unknown collection is `400`.

#### Scenario: Filtering
- **GIVEN** a favorite "Lemon Cake" tagged `Dessert/Cake` and "Beef Stew" with ingredient `1 lb beef`
- **WHEN** a client requests `?q=beef`, `?tag=dessert` and `?collection=favorites`
- **THEN** the answers are `["Beef Stew"]`, `["Lemon Cake"]` and `["Lemon Cake"]`

### Requirement: Recipe photos
The server SHALL serve a recipe's cover photo at `GET /api/recipes/:id/image` and step photos at `GET /api/step-images/:id`, with the content type sniffed from the bytes, `X-Content-Type-Options: nosniff` and an `ETag`; a request with `?v=` is cached as immutable and a matching `If-None-Match` gets `304`. `PUT /api/recipes/:id/image` stores the raw request body as the photo and returns the updated recipe; only JPEG, PNG, WebP and GIF are accepted (`415` otherwise). `DELETE /api/recipes/:id/image` removes it. The server does not resize or convert photos.

#### Scenario: Refusing SVG
- **WHEN** a client uploads `<svg onload=alert(1)>` as a recipe photo
- **THEN** the server answers `415`

#### Scenario: Serving by sniffed type
- **WHEN** a client uploads a PNG and then requests the photo
- **THEN** the response has `Content-Type: image/png`

### Requirement: Meal plan endpoints
The server SHALL provide `GET` and `POST /api/meal-plan` and `PUT` and `DELETE /api/meal-plan/:id`. `GET` accepts optional `from` and `to` days (`YYYY-MM-DD`, inclusive) and returns entries sorted by day, then meal (breakfast, lunch, dinner, snack), then creation time. A new entry needs a valid `day` and either a `title` or an existing `recipeID` (whose title it takes); `meal` defaults to `dinner`. Planning a recipe that is in Up Next takes it out of the queue. `PUT` changes the day and meal and keeps the existing title and recipe unless new ones are given.

#### Scenario: Planning a queued recipe
- **GIVEN** a recipe with `wantToCook: true`
- **WHEN** a client posts `{ "recipeID": <id>, "day": "2026-10-15", "meal": "dinner" }`
- **THEN** the entry is created with the recipe's title
- **AND** the recipe's `wantToCook` becomes `false`

#### Scenario: Missing title
- **WHEN** a client posts `{ "day": "2026-10-15" }`
- **THEN** the server answers `422`

### Requirement: Grocery endpoints
The server SHALL provide `GET` and `POST /api/groceries`, `PATCH` and `DELETE /api/groceries/:id`, and `POST /api/groceries/clear`. `GET` returns items oldest first. `POST` takes one item or an array of up to 500, skips any item whose name (case-insensitive) and quantity match an unchecked item already on the list or earlier in the same request, and returns the items it added. Saved items always carry `id`, `name`, `quantity`, `isChecked`, `createdAt` and `updatedAt`. `clear` takes `{ "scope": "completed" }` or `{ "scope": "all" }` and returns `{ "removed": <count> }`.

#### Scenario: Duplicates skipped
- **WHEN** a client posts `[{ "name": "Milk", "quantity": "1 l" }, { "name": "milk", "quantity": "1 l" }, { "name": "Eggs" }]`
- **THEN** only Milk and Eggs are added
- **AND** posting `{ "name": "MILK", "quantity": "1 l" }` afterwards returns `[]`

#### Scenario: Clearing completed items
- **GIVEN** one checked and one unchecked item
- **WHEN** a client posts `{ "scope": "completed" }` to `/api/groceries/clear`
- **THEN** the answer is `{ "removed": 1 }` and only the unchecked item remains

### Requirement: Import a recipe page
`POST /api/import` with `{ "url" }` SHALL fetch the page, read its schema.org recipe data and return `{ draft, image }`, where `image` is the recipe photo as a `data:` URL when one was found, without saving anything. YouTube links are refused with `422` (importing them needs the apps), a page without recipe data is `422`, and a page that can't be fetched is `502`. Only `http(s)` URLs are fetched, at most 5 redirects, within 30 seconds overall, pages up to 5 MB and photos up to 15 MB. Unless `ALLOW_PRIVATE_IMPORTS` is on, loopback, private and link-local addresses are refused (`400`), checked at connection time for every hop. Page parsing follows the same rules as the app (see web-import).

#### Scenario: Importing a draft
- **GIVEN** `ALLOW_PRIVATE_IMPORTS` is on and a local page that redirects to a recipe page with a photo
- **WHEN** a client posts its URL to `/api/import`
- **THEN** the answer's `draft` has the recipe's title, ingredients and the final page URL as `sourceURL`
- **AND** `image` starts with `data:image/jpeg;base64,`
- **AND** the library still has no recipes

#### Scenario: Private address refused
- **GIVEN** `ALLOW_PRIVATE_IMPORTS` is off
- **WHEN** a client asks to import a page on `127.0.0.1`
- **THEN** the server answers `400`

### Requirement: Export and restore
`GET /api/export` SHALL return the whole library as one JSON document (`version: 1`, `exportedAt`, `recipes`, `mealPlan`, `groceries`, `feeds`, and base64 `images` and `stepImages` keyed by id), the same format the app's "Export all data" makes, as a download named `recipes-<YYYY-MM-DD>.json`. `POST /api/export/restore` writes everything in such a document into the library, replacing items with the same id and deleting nothing, skips recipes without a title and photo keys that aren't UUIDs, and returns counts of `recipes`, `mealPlan`, `groceries`, `feeds` and `images`.

#### Scenario: Moving a library between servers
- **GIVEN** a server with one recipe and its photo, one planned meal and one grocery item
- **WHEN** its export is restored into an empty server
- **THEN** the restore answers `{ "recipes": 1, "mealPlan": 1, "groceries": 1, "feeds": 0, "images": 1 }`
- **AND** the recipe on the new server has a photo

#### Scenario: Hostile photo key
- **WHEN** a restore document has an `images` key `../../escape`
- **THEN** it is ignored and the restore reports `images: 0`

### Requirement: Web UI hosting and security headers
When a web UI folder is configured, the server SHALL serve its files for any non-API path, fall back to `index.html` for paths without a file extension so client-side routes survive a reload, answer `404` for missing files with an extension, never answer an `/api/` path with HTML, never read outside the folder, and answer `400` to a malformed address. Files under `/assets/` are cached as immutable; other files use `no-cache`. Every response carries `X-Content-Type-Options: nosniff`, `Referrer-Policy: same-origin` and `X-Frame-Options: DENY`, and HTML responses carry a Content Security Policy limited to the server's own origin (YouTube's no-cookie embed allowed in frames).

#### Scenario: Client route reload
- **WHEN** a browser requests `/recipes/some-id/edit`
- **THEN** the server answers with `index.html`

#### Scenario: Path traversal
- **WHEN** a client requests `/%2e%2e/outside-secret.txt`
- **THEN** the response does not contain the file outside the web folder
