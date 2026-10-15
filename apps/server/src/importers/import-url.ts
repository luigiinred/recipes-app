import type { ImportResponse } from "@recipes/schema";
import { HttpError } from "../errors.js";
import { sniffImage } from "../storage/image-store.js";
import { parseRecipePage } from "./recipe-page.js";
import { safeFetch } from "./safe-fetch.js";

const MAX_PAGE_BYTES = 5 * 1024 * 1024;
const MAX_PHOTO_BYTES = 15 * 1024 * 1024;

const YOUTUBE_HOSTS = new Set(["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "music.youtube.com"]);

/** Reads a recipe from a web page and downloads its cover photo. The draft is returned for review, not saved. */
export async function importFromURL(rawUrl: string, allowPrivate: boolean): Promise<ImportResponse> {
  const url = new URL(rawUrl);
  if (YOUTUBE_HOSTS.has(url.hostname.toLowerCase())) {
    throw new HttpError(422, "Importing from YouTube isn't supported on the server yet. Use the iPhone or Mac app.");
  }
  const page = await safeFetch(url, { allowPrivate, maxBytes: MAX_PAGE_BYTES });
  if (page.status < 200 || page.status >= 300) throw new HttpError(502, `The page returned HTTP ${page.status}.`);
  const parsed = parseRecipePage(page.body.toString("utf8"), page.finalUrl);
  if (!parsed) throw new HttpError(422, "No recipe found on that page.");

  let image: string | null = null;
  if (parsed.imageURL) {
    try {
      const photo = await safeFetch(parsed.imageURL, { allowPrivate, maxBytes: MAX_PHOTO_BYTES, accept: "image/*" });
      const kind = sniffImage(photo.body);
      if (photo.status >= 200 && photo.status < 300 && kind) image = `data:${kind};base64,${photo.body.toString("base64")}`;
    } catch {
      image = null;
    }
  }
  return { draft: parsed.draft, image };
}
