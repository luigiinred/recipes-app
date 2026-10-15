import fs from "node:fs/promises";
import path from "node:path";
import { isUUID } from "@recipes/schema";
import { atomicWrite, isMissing, stringifyDocument } from "./fsutil.js";

const DOCUMENT_NAME = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.json$/;

interface Cached<T> {
  mtimeMs: number;
  size: number;
  doc: T | null;
}

/** A folder of `<uuid>.json` files. Reads are cached by modification time, so files edited outside the server are picked up. */
export class DocStore<T extends { id: string }> {
  private cache = new Map<string, Cached<T>>();

  /**
   * `knownKeys` are the fields this server understands; any other field already in a file (written by a newer
   * app, say) is carried over when the document is saved again.
   */
  constructor(
    readonly dir: string,
    private readonly parse: (raw: unknown) => T | null,
    private readonly knownKeys: ReadonlySet<string>,
  ) {}

  private file(id: string): string {
    if (!isUUID(id)) throw new Error("Invalid id");
    return path.join(this.dir, `${id.toLowerCase()}.json`);
  }

  private async load(name: string): Promise<T | null> {
    const file = path.join(this.dir, name);
    let stat;
    try {
      stat = await fs.stat(file);
    } catch (error) {
      if (isMissing(error)) return null;
      throw error;
    }
    const hit = this.cache.get(name);
    if (hit && hit.mtimeMs === stat.mtimeMs && hit.size === stat.size) return hit.doc;
    let doc: T | null = null;
    try {
      doc = this.parse(JSON.parse(await fs.readFile(file, "utf8")));
    } catch {
      doc = null;
    }
    if (!doc) console.warn(`Skipping ${path.basename(this.dir)}/${name}: it isn't a valid document.`);
    this.cache.set(name, { mtimeMs: stat.mtimeMs, size: stat.size, doc });
    return doc;
  }

  async list(): Promise<T[]> {
    let names: string[];
    try {
      names = await fs.readdir(this.dir);
    } catch (error) {
      if (isMissing(error)) return [];
      throw error;
    }
    const wanted = names.filter((name) => DOCUMENT_NAME.test(name));
    const present = new Set(wanted);
    for (const key of this.cache.keys()) if (!present.has(key)) this.cache.delete(key);
    const loaded = await Promise.all(wanted.map((name) => this.load(name)));
    const docs: T[] = [];
    for (const doc of loaded) if (doc) docs.push(doc);
    return docs;
  }

  async get(id: string): Promise<T | null> {
    return this.load(path.basename(this.file(id)));
  }

  async put(doc: T): Promise<void> {
    const file = this.file(doc.id);
    await atomicWrite(file, stringifyDocument({ ...(await this.unknownFields(file)), ...doc }));
    this.cache.delete(path.basename(file));
  }

  private async unknownFields(file: string): Promise<Record<string, unknown>> {
    try {
      const raw = JSON.parse(await fs.readFile(file, "utf8")) as Record<string, unknown>;
      return Object.fromEntries(Object.entries(raw).filter(([key]) => !this.knownKeys.has(key)));
    } catch {
      return {};
    }
  }

  async delete(id: string): Promise<boolean> {
    try {
      await fs.unlink(this.file(id));
      this.cache.delete(path.basename(this.file(id)));
      return true;
    } catch (error) {
      if (isMissing(error)) return false;
      throw error;
    }
  }
}
