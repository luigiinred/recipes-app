# library-sync Specification

## Purpose
Keeps a local library folder in step with a self-hosted Recipes server by copying whole files both ways. The server exposes the library as a flat set of files with content hashes; the `recipes sync` command on macOS runs the client side. The iPhone, iPad and Mac apps do not use it.

## Requirements

### Requirement: Addressable library files
The sync endpoints SHALL address only `Recipes/<id>.json`, `Calendar/<id>.json`, `Groceries/<id>.json`, `Feeds/<id>.json`, `Images/<id>.jpg` and `StepImages/<id>.jpg`, where `<id>` is a lowercase UUID. Any other folder, file name, extension or uppercase id is a `404` before the disk is touched. All sync endpoints require authentication (see server-auth).

#### Scenario: Outside the library
- **WHEN** a client requests `GET` or `PUT /api/sync/files/.server/auth.json`, `Recipes/notes.txt`, `Recipes/<UPPERCASE-ID>.json` or `constructor/<id>.jpg`
- **THEN** the server answers `404`

#### Scenario: Wrong extension for the folder
- **WHEN** a client uploads `Recipes/<id>.jpg`
- **THEN** the server answers `404`

### Requirement: File listing
`GET /api/sync/files` SHALL return `{ "files": [{ "path", "size", "etag", "mtimeMs" }], "serverTime" }` for every library file, sorted by path, where `etag` is the lowercase hex SHA-256 of the file's bytes. Hashes are recomputed whenever a file's size or modification time changes, so files edited on the server's disk by hand appear with their new etag.

#### Scenario: Hand edit on disk
- **GIVEN** a recipe file uploaded through sync
- **WHEN** the file is rewritten directly on the server's disk
- **THEN** the next listing shows a different etag for it
- **AND** `GET /api/recipes/<id>` returns the new content

### Requirement: File read
`GET /api/sync/files/<dir>/<name>` SHALL return the file's bytes with `ETag: "<etag>"`, or `404` when it doesn't exist.

#### Scenario: Reading a file
- **WHEN** a client reads a recipe file it uploaded
- **THEN** the `ETag` header equals the quoted etag the upload returned

### Requirement: Conditional writes and deletes
`PUT /api/sync/files/<dir>/<name>` SHALL write the request body atomically and return the new listing entry; `DELETE` removes the file and answers `204`. `If-Match: "<etag>"` makes the request succeed only if the server's current file has that etag, `If-Match: *` only if the file exists, and `If-None-Match: *` (on `PUT`) only if it does not; a failed condition answers `412` and changes nothing. Without a condition the write or delete is unconditional.

#### Scenario: Stale write refused
- **GIVEN** a file was uploaded and then replaced using `If-Match` with its first etag
- **WHEN** a client uploads again with that first etag
- **THEN** the server answers `412`
- **AND** a `DELETE` with that etag also answers `412`

#### Scenario: Create only
- **GIVEN** a file already exists
- **WHEN** a client uploads it with `If-None-Match: *`
- **THEN** the server answers `412`

### Requirement: Upload validation
The server SHALL check every uploaded file before writing it: JSON files must parse as the document type of their folder (recipe, meal plan entry, grocery item or feed) and carry the id in their file name (`422` otherwise); photos must be JPEG, PNG, WebP or GIF by content (`415` otherwise); and no file may exceed 25 MB (`413`). Files written through sync are immediately visible through the REST API (see server-api).

#### Scenario: Mismatched id
- **WHEN** a client uploads `Recipes/<id>.json` whose `id` field is a different UUID
- **THEN** the server answers `422`

#### Scenario: Wrong document type
- **WHEN** a client uploads a recipe document as `Groceries/<id>.json`
- **THEN** the server answers `422`

#### Scenario: Not a photo
- **WHEN** a client uploads `<html>` as `Images/<id>.jpg`
- **THEN** the server answers `415`

### Requirement: Three-way sync pass
`recipes sync` SHALL compare, for every path in the union of local files, server files and its stored base, the local content hash, the server etag and the hash both sides had after the last successful pass. When local and server match it records that as the base. Otherwise a change on one side only is copied to the other (upload with `If-Match` of the server etag or `If-None-Match: *`, download, or delete with `If-Match`), and a deletion on one side of an unchanged file deletes it on the other. Only lowercase-UUID `.json` and `.jpg` files in the six library folders are synced locally; other files are ignored. Downloads are written atomically.

#### Scenario: First pass
- **GIVEN** an empty local folder and a server with files
- **WHEN** the user runs `recipes sync`
- **THEN** every server file is downloaded
- **AND** a second pass changes nothing

#### Scenario: Deletions travel
- **GIVEN** a file synced in an earlier pass
- **WHEN** it is deleted locally and the user syncs
- **THEN** it is deleted on the server

#### Scenario: Ignored files
- **GIVEN** local files `Recipes/notes.txt`, `Recipes/<id>.json.tmp` and `Recipes/<UPPERCASE-ID>.json`
- **WHEN** the user syncs
- **THEN** nothing is uploaded

### Requirement: Conflict resolution
When a file changed on both sides since the last pass, the sync SHALL keep the edit if the other side deleted it; otherwise a JSON document keeps the version with the later `updatedAt` (or `createdAt` when there is none), a photo keeps the version with the later modification time, and a tie goes to the server. Each such file counts as a conflict in the report.

#### Scenario: Newer edit wins
- **GIVEN** a recipe edited locally with an older `updatedAt` and on the server with a newer one
- **WHEN** the user syncs
- **THEN** the server's version is kept locally and the report counts one conflict

#### Scenario: Edit beats deletion
- **GIVEN** a recipe deleted on the server and edited locally since the last pass
- **WHEN** the user syncs
- **THEN** the local edit is uploaded and the recipe exists on the server again

### Requirement: Lost races are deferred
When the server answers `412` to an upload or delete during a pass, the sync SHALL leave that path's base unchanged, count it as deferred, and pick up the server's new version on the next pass.

#### Scenario: Retry next pass
- **GIVEN** the server refuses the first upload with `412`
- **WHEN** the user syncs twice
- **THEN** the first pass reports one deferred file and the second uploads it

### Requirement: Mass-deletion safeguard
A pass that would delete more than half of the files in its base and more than 10 SHALL stop before changing anything and report how many files it would delete, unless run with `--allow-mass-deletion`.

#### Scenario: Server emptied
- **GIVEN** 30 recipes synced earlier and then all removed from the server
- **WHEN** the user runs `recipes sync`
- **THEN** it fails with "This would delete 30 files, which looks like a mistake. Nothing was changed."
- **AND** the 30 local files remain
- **AND** `recipes sync --allow-mass-deletion` deletes them

### Requirement: Per-server base
The sync SHALL store its base in `.sync-state.json` in the library folder, tagged with the server address, and start from an empty base when pointed at a different server, so switching servers never deletes files. The base is saved only after a pass finishes, so a pass that fails halfway can be run again safely.

#### Scenario: Different server
- **GIVEN** a folder synced with one server
- **WHEN** the user syncs it with another server
- **THEN** no local files are deleted because they are missing on the new server

### Requirement: recipes sync command
`recipes sync` SHALL take the server address from `--server` or `RECIPES_SERVER` (it must be `http://` or `https://`) and the access token from `RECIPES_TOKEN` only, sync the library folder chosen by `--dir`, `RECIPES_DIR` or the iCloud library (see recipes-cli), and print the counts uploaded, downloaded, deleted here and deleted on the server, plus conflicts and deferred files when there are any. `--json` prints the report as JSON. A rejected token fails with "The server didn't accept the access token."

#### Scenario: Missing token
- **WHEN** the user runs `recipes sync --server https://recipes.example.com` without `RECIPES_TOKEN`
- **THEN** it fails asking to set `RECIPES_TOKEN` to an access token from the server's Settings page

#### Scenario: Bad token
- **WHEN** `RECIPES_TOKEN` holds a revoked token
- **THEN** the command fails with "The server didn't accept the access token."
