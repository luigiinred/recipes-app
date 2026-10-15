import type { Context } from "hono";
import type { z } from "zod";
import { HttpError } from "./errors.js";

export async function jsonBody<S extends z.ZodType>(c: Context, schema: S): Promise<z.output<S>> {
  let raw: unknown;
  try {
    raw = await c.req.json();
  } catch {
    throw new HttpError(400, "The request body isn't valid JSON.");
  }
  const result = schema.safeParse(raw);
  if (!result.success) {
    const first = result.error.issues[0];
    const where = first?.path.length ? `${first.path.join(".")}: ` : "";
    throw new HttpError(422, `${where}${first?.message ?? "Invalid request."}`, result.error.issues);
  }
  return result.data;
}

/** Ids in URLs are matched case-insensitively and stored lowercase; anything else can't name a document. */
export function idParam(c: Context, name = "id"): string {
  const value = c.req.param(name) ?? "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) throw new HttpError(404, "Not found.");
  return value.toLowerCase();
}

export function imageResponse(
  c: Context,
  image: { data: Buffer; mtimeMs: number },
  contentType: string,
): Response {
  const etag = `"${Math.round(image.mtimeMs)}-${image.data.length}"`;
  const headers = new Headers({
    "content-type": contentType,
    etag,
    "cache-control": c.req.query("v") ? "private, max-age=31536000, immutable" : "private, no-cache",
    "x-content-type-options": "nosniff",
  });
  if (c.req.header("if-none-match") === etag) return new Response(null, { status: 304, headers });
  headers.set("content-length", String(image.data.length));
  return new Response(new Uint8Array(image.data), { headers });
}
