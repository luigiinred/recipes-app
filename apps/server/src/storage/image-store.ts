import fs from "node:fs/promises";
import path from "node:path";
import { isUUID } from "@recipes/schema";
import { atomicWrite, isMissing } from "./fsutil.js";

const IMAGE_NAME = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jpg$/;

export interface StoredImage {
  data: Buffer;
  mtimeMs: number;
}

/** A folder of `<uuid>.jpg` files. The extension is fixed by the library layout; the bytes may be any web image format. */
export class ImageStore {
  constructor(readonly dir: string) {}

  private file(id: string): string {
    if (!isUUID(id)) throw new Error("Invalid id");
    return path.join(this.dir, `${id.toLowerCase()}.jpg`);
  }

  async read(id: string): Promise<StoredImage | null> {
    try {
      const [data, stat] = await Promise.all([fs.readFile(this.file(id)), fs.stat(this.file(id))]);
      return { data, mtimeMs: stat.mtimeMs };
    } catch (error) {
      if (isMissing(error)) return null;
      throw error;
    }
  }

  async write(id: string, data: Uint8Array): Promise<void> {
    await atomicWrite(this.file(id), data);
  }

  async delete(id: string): Promise<boolean> {
    try {
      await fs.unlink(this.file(id));
      return true;
    } catch (error) {
      if (isMissing(error)) return false;
      throw error;
    }
  }

  /** Modification time of every stored image, keyed by id. */
  async stamps(): Promise<Map<string, number>> {
    const result = new Map<string, number>();
    let names: string[];
    try {
      names = await fs.readdir(this.dir);
    } catch (error) {
      if (isMissing(error)) return result;
      throw error;
    }
    await Promise.all(
      names.map(async (name) => {
        const match = IMAGE_NAME.exec(name);
        if (!match) return;
        try {
          result.set(match[1]!.toLowerCase(), (await fs.stat(path.join(this.dir, name))).mtimeMs);
        } catch (error) {
          if (!isMissing(error)) throw error;
        }
      }),
    );
    return result;
  }
}

export type ImageKind = "image/jpeg" | "image/png" | "image/webp" | "image/gif";

/** Identifies a web-safe image by its magic bytes; anything else (SVG, HTML) is refused. */
export function sniffImage(data: Uint8Array): ImageKind | null {
  const startsWith = (...bytes: number[]) => bytes.every((byte, i) => data[i] === byte);
  if (startsWith(0xff, 0xd8, 0xff)) return "image/jpeg";
  if (startsWith(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)) return "image/png";
  if (startsWith(0x47, 0x49, 0x46, 0x38)) return "image/gif";
  if (startsWith(0x52, 0x49, 0x46, 0x46) && data[8] === 0x57 && data[9] === 0x45 && data[10] === 0x42 && data[11] === 0x50) return "image/webp";
  return null;
}
