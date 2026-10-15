import fs from "node:fs/promises";
import path from "node:path";
import type { Hono } from "hono";

const TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webmanifest": "application/manifest+json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
};

/** Serves the built web UI, falling back to index.html so client-side routes survive a reload. */
export function serveWeb(app: Hono, webDir: string): void {
  const root = path.resolve(webDir);

  async function readFile(relative: string): Promise<{ data: Buffer; ext: string; file: string } | null> {
    const file = path.resolve(root, "." + path.posix.normalize("/" + relative));
    if (file !== root && !file.startsWith(root + path.sep)) return null;
    try {
      const stat = await fs.stat(file);
      if (!stat.isFile()) return null;
      return { data: await fs.readFile(file), ext: path.extname(file).toLowerCase(), file };
    } catch {
      return null;
    }
  }

  app.get("*", async (c) => {
    let pathname: string;
    try {
      pathname = decodeURIComponent(new URL(c.req.url).pathname);
    } catch {
      return c.text("Bad request.", 400);
    }
    if (pathname.startsWith("/api/")) return c.json({ error: "Not found." }, 404);
    const hit = await readFile(pathname === "/" ? "index.html" : pathname);
    const asset = hit ?? (path.extname(pathname) ? null : await readFile("index.html"));
    if (!asset) return c.text("Not found.", 404);
    const hashed = /^\/assets\//.test(pathname);
    return new Response(new Uint8Array(asset.data), {
      headers: {
        "content-type": TYPES[asset.ext] ?? "application/octet-stream",
        "cache-control": hashed ? "public, max-age=31536000, immutable" : "no-cache",
      },
    });
  });
}
