import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import {
  feedSchema,
  groceryItemSchema,
  mealPlanEntrySchema,
  recipeSchema,
  type SyncFileEntry,
} from "@recipes/schema";
import type { z } from "zod";
import { HttpError } from "../errors.js";
import { sniffImage } from "./image-store.js";
import { atomicWrite, isMissing, KeyedLock } from "./fsutil.js";
import { LIBRARY_DIRS } from "./library.js";

const UUID = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
const NAME = new RegExp(`^(${UUID})\\.(json|jpg)$`);

type Kind = "json" | "image";
const DIRECTORIES: Record<string, { kind: Kind; schema?: z.ZodType<{ id: string }> }> = {
  [LIBRARY_DIRS.recipes]: { kind: "json", schema: recipeSchema },
  [LIBRARY_DIRS.mealPlan]: { kind: "json", schema: mealPlanEntrySchema },
  [LIBRARY_DIRS.groceries]: { kind: "json", schema: groceryItemSchema },
  [LIBRARY_DIRS.feeds]: { kind: "json", schema: feedSchema },
  [LIBRARY_DIRS.images]: { kind: "image" },
  [LIBRARY_DIRS.stepImages]: { kind: "image" },
};

/** `ifMatch` is an etag, or "*" for "must already exist"; `ifNoneMatch` means "must not exist yet". */
export interface WriteCondition {
  ifMatch?: string;
  ifNoneMatch?: boolean;
}

export const MAX_SYNC_FILE_BYTES = 25 * 1024 * 1024;

export interface ParsedPath {
  dir: string;
  name: string;
  id: string;
  kind: Kind;
}

/** Only `<known folder>/<lowercase uuid>.<json|jpg>` is addressable; everything else is refused before touching disk. */
export function parseLibraryPath(dir: string, name: string): ParsedPath {
  const spec = Object.hasOwn(DIRECTORIES, dir) ? DIRECTORIES[dir] : undefined;
  const match = NAME.exec(name);
  if (!spec || !match) throw new HttpError(404, "No such library file.");
  const expected = spec.kind === "json" ? "json" : "jpg";
  if (match[2] !== expected) throw new HttpError(404, "No such library file.");
  return { dir, name, id: match[1]!, kind: spec.kind };
}

/**
 * The library as a flat set of files, for clients that keep their own copy (the iOS app's server mode).
 * Clients compare etags against what they saw last time, so the server needs no change log or tombstones.
 */
export class SyncStore {
  private etags = new Map<string, { mtimeMs: number; size: number; etag: string }>();
  constructor(
    private readonly root: string,
    private readonly lock: KeyedLock = new KeyedLock(),
  ) {}

  private file({ dir, name }: ParsedPath): string {
    return path.join(this.root, dir, name);
  }

  private async describe(parsed: ParsedPath): Promise<SyncFileEntry | null> {
    const file = this.file(parsed);
    let stat;
    try {
      stat = await fs.stat(file);
    } catch (error) {
      if (isMissing(error)) return null;
      throw error;
    }
    const key = `${parsed.dir}/${parsed.name}`;
    const hit = this.etags.get(key);
    if (hit && hit.mtimeMs === stat.mtimeMs && hit.size === stat.size) {
      return { path: key, size: stat.size, etag: hit.etag, mtimeMs: stat.mtimeMs };
    }
    const etag = createHash("sha256").update(await fs.readFile(file)).digest("hex");
    this.etags.set(key, { mtimeMs: stat.mtimeMs, size: stat.size, etag });
    return { path: key, size: stat.size, etag, mtimeMs: stat.mtimeMs };
  }

  async list(): Promise<SyncFileEntry[]> {
    const entries: SyncFileEntry[] = [];
    const seen = new Set<string>();
    for (const dir of Object.keys(DIRECTORIES)) {
      let names: string[];
      try {
        names = await fs.readdir(path.join(this.root, dir));
      } catch (error) {
        if (isMissing(error)) continue;
        throw error;
      }
      const describeName = async (name: string): Promise<SyncFileEntry | null> => {
        try {
          const entry = await this.describe(parseLibraryPath(dir, name));
          if (entry) seen.add(entry.path);
          return entry;
        } catch (error) {
          if (error instanceof HttpError) return null;
          throw error;
        }
      };
      // A few dozen at a time: hashing a big library shouldn't open thousands of files at once.
      for (let i = 0; i < names.length; i += 32) {
        const described = await Promise.all(names.slice(i, i + 32).map(describeName));
        entries.push(...described.filter((entry): entry is SyncFileEntry => entry !== null));
      }
    }
    for (const key of this.etags.keys()) if (!seen.has(key)) this.etags.delete(key);
    return entries.sort((a, b) => a.path.localeCompare(b.path));
  }

  async read(parsed: ParsedPath): Promise<{ data: Buffer; entry: SyncFileEntry } | null> {
    const entry = await this.describe(parsed);
    if (!entry) return null;
    try {
      return { data: await fs.readFile(this.file(parsed)), entry };
    } catch (error) {
      if (isMissing(error)) return null;
      throw error;
    }
  }

  /**
   * Writes a file after checking it is what its path says it is. `ifMatch` is the etag the client last saw
   * (or "*" for "must not exist yet"); a mismatch means someone else changed it first.
   */
  async write(parsed: ParsedPath, data: Buffer, condition: WriteCondition = {}): Promise<SyncFileEntry> {
    if (data.length > MAX_SYNC_FILE_BYTES) throw new HttpError(413, "That file is too large.");
    this.validate(parsed, data);
    return this.lock.run(`${parsed.dir}/${parsed.name}`, async () => {
      await this.checkPrecondition(parsed, condition);
      await atomicWrite(this.file(parsed), data);
      const entry = await this.describe(parsed);
      if (!entry) throw new Error("File vanished after writing");
      return entry;
    });
  }

  async delete(parsed: ParsedPath, condition: WriteCondition = {}): Promise<boolean> {
    return this.lock.run(`${parsed.dir}/${parsed.name}`, async () => {
      await this.checkPrecondition(parsed, condition);
      try {
        await fs.unlink(this.file(parsed));
        return true;
      } catch (error) {
        if (isMissing(error)) return false;
        throw error;
      }
    });
  }

  private async checkPrecondition(parsed: ParsedPath, { ifMatch, ifNoneMatch }: WriteCondition): Promise<void> {
    if (ifMatch === undefined && !ifNoneMatch) return;
    const current = await this.describe(parsed);
    const ok = ifNoneMatch ? current === null : ifMatch === "*" ? current !== null : current?.etag === ifMatch;
    if (!ok) throw new HttpError(412, "The file changed on the server.");
  }

  private validate(parsed: ParsedPath, data: Buffer): void {
    if (parsed.kind === "image") {
      if (!sniffImage(data)) throw new HttpError(415, "That isn't a JPEG, PNG, WebP or GIF image.");
      return;
    }
    let raw: unknown;
    try {
      raw = JSON.parse(data.toString("utf8"));
    } catch {
      throw new HttpError(422, "That file isn't valid JSON.");
    }
    const result = DIRECTORIES[parsed.dir]!.schema!.safeParse(raw);
    if (!result.success) throw new HttpError(422, "That file isn't a valid library document.", result.error.issues);
    if (result.data.id !== parsed.id) throw new HttpError(422, "The document's id doesn't match its file name.");
  }
}
