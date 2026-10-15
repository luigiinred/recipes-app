import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { HttpError } from "../errors.js";
import { MAX_SYNC_FILE_BYTES, parseLibraryPath, type SyncStore, type WriteCondition } from "../storage/sync-store.js";

export function syncRoutes(sync: SyncStore): Hono {
  const app = new Hono();

  app.get("/sync/files", async (c) => c.json({ files: await sync.list(), serverTime: Date.now() }));

  app.get("/sync/files/:dir/:name", async (c) => {
    const file = await sync.read(parseLibraryPath(c.req.param("dir"), c.req.param("name")));
    if (!file) throw new HttpError(404, "No such library file.");
    return new Response(new Uint8Array(file.data), {
      headers: {
        "content-type": "application/octet-stream",
        etag: `"${file.entry.etag}"`,
        "x-content-type-options": "nosniff",
      },
    });
  });

  // `If-Match: "<etag>"` replaces only the version the client last saw; `If-None-Match: *` only creates.
  app.put(
    "/sync/files/:dir/:name",
    bodyLimit({ maxSize: MAX_SYNC_FILE_BYTES, onError: () => { throw new HttpError(413, "That file is too large."); } }),
    async (c) => {
      const parsed = parseLibraryPath(c.req.param("dir"), c.req.param("name"));
      const entry = await sync.write(parsed, Buffer.from(await c.req.arrayBuffer()), conditions(c.req.header("if-match"), c.req.header("if-none-match")));
      return c.json(entry, { headers: { etag: `"${entry.etag}"` } });
    },
  );

  app.delete("/sync/files/:dir/:name", async (c) => {
    const parsed = parseLibraryPath(c.req.param("dir"), c.req.param("name"));
    await sync.delete(parsed, conditions(c.req.header("if-match"), undefined));
    return c.body(null, 204);
  });

  return app;
}

function conditions(ifMatch: string | undefined, ifNoneMatch: string | undefined): WriteCondition {
  const etag = ifMatch?.trim().replace(/^W\//, "").replace(/^"|"$/g, "");
  return { ifMatch: etag || undefined, ifNoneMatch: ifNoneMatch?.trim() === "*" };
}
