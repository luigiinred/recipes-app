# Sync protocol

How a client keeps its own copy of a library in step with a server. The Swift implementation is `ServerSync` in `apps/ios/Sources/RecipeKit`, the server side is `apps/server/src/storage/sync-store.ts`.

The server exposes the library as a flat set of files, laid out like the iCloud container's `Documents` folder:

```
Recipes/<id>.json     Calendar/<id>.json     Groceries/<id>.json     Feeds/<id>.json
Images/<id>.jpg       StepImages/<id>.jpg
```

`<id>` is a lowercase UUID. A recipe's photo has the recipe's id; step photos have the ids listed in the recipe's `stepImages`. Any other path is a 404.

## Authentication

Every request carries `Authorization: Bearer <token>`. Tokens are created in the web UI (Settings) and can be revoked there. A bad token is a `401`.

## Endpoints

| Request | Response |
|---|---|
| `GET /api/sync/files` | `{ "files": [{ "path", "size", "etag", "mtimeMs" }], "serverTime" }`. `etag` is the hex SHA-256 of the file's bytes. |
| `GET /api/sync/files/<dir>/<name>` | The file's bytes, with `ETag: "<etag>"`. |
| `PUT /api/sync/files/<dir>/<name>` | Writes the body and returns the new entry. `If-Match: "<etag>"` replaces only the version you saw; `If-None-Match: *` only creates. A failed condition is `412`. |
| `DELETE /api/sync/files/<dir>/<name>` | `204`. `If-Match` works as for `PUT`. |

Writes are checked before they touch disk: JSON must parse as the document its folder holds and carry the id in its file name (`422` otherwise); photos must be JPEG, PNG, WebP or GIF (`415`); files are at most 25 MB (`413`).

Files edited on the server's disk by hand are picked up on the next listing, because etags are recomputed when a file's size or modification time changes.

## Algorithm

The server keeps no change log and no tombstones. The client keeps, per path, the content hash both sides had after its last successful pass (its *base*). For each path in the union of local files, server files and base entries:

| Local vs base | Server vs base | Action |
|---|---|---|
| same hash as server | | record as base |
| changed or new | unchanged | upload (`If-Match: <server etag>`, or `If-None-Match: *` if the server has none) |
| deleted | unchanged | delete on the server (`If-Match`) |
| unchanged | changed or new | download |
| unchanged | deleted | delete locally |
| changed | changed | resolve (below) |

Resolving an edit on both sides: if one side deleted the file, the edit wins. Otherwise documents keep the later `updatedAt` (`createdAt` when there is none), photos keep the later modification time, and a tie goes to the server.

A `412` on upload or delete means the server changed the file after the client listed it. The client leaves the base alone and the next pass sees the new server version.

Two safeguards: if a pass would delete more than half the files it knows about (and more than 10), the client stops and asks for confirmation, so an empty or unreadable local folder can't wipe the server; and the base is stored per server address, so pointing a folder at a different server starts from scratch rather than deleting things.

## Building a client

Write files atomically, hash what you wrote (not what you were told to expect), and store the base only after the transfer succeeded. A pass that fails halfway is safe to run again.
