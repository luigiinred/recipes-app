import { libraryExportSchema, importRequestSchema } from "@recipes/schema";
import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { HttpError } from "../errors.js";
import { jsonBody } from "../http.js";
import { importFromURL } from "../importers/import-url.js";
import type { Library } from "../storage/library.js";

const MAX_LIBRARY_BYTES = 512 * 1024 * 1024;

export function libraryRoutes(library: Library, allowPrivateImports: boolean): Hono {
  const app = new Hono();

  app.post("/import", async (c) => {
    const { url } = await jsonBody(c, importRequestSchema);
    return c.json(await importFromURL(url, allowPrivateImports));
  });

  app.get("/export", async (c) => {
    const body = JSON.stringify(await library.export());
    const stamp = new Date().toISOString().slice(0, 10);
    return new Response(body, {
      headers: { "content-type": "application/json", "content-disposition": `attachment; filename="recipes-${stamp}.json"` },
    });
  });

  app.post(
    "/export/restore",
    bodyLimit({ maxSize: MAX_LIBRARY_BYTES, onError: () => { throw new HttpError(413, "That export is too large."); } }),
    async (c) => {
      const data = await jsonBody(c, libraryExportSchema);
      return c.json(await library.importExport(data));
    },
  );

  return app;
}
