import { randomBytes } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

export async function atomicWrite(file: string, data: string | Uint8Array, mode?: number): Promise<void> {
  await fs.mkdir(path.dirname(file), { recursive: true });
  const temp = `${file}.${randomBytes(6).toString("hex")}.tmp`;
  try {
    await fs.writeFile(temp, data, mode === undefined ? undefined : { mode });
    await fs.rename(temp, file);
  } catch (error) {
    await fs.rm(temp, { force: true });
    throw error;
  }
}

export const isMissing = (error: unknown): boolean => (error as NodeJS.ErrnoException)?.code === "ENOENT";

/** Serializes work per key so check-then-write sequences on one file can't interleave. */
export class KeyedLock {
  private tails = new Map<string, Promise<unknown>>();

  async run<T>(key: string, work: () => Promise<T>): Promise<T> {
    const previous = this.tails.get(key) ?? Promise.resolve();
    const next = previous.catch(() => {}).then(work);
    this.tails.set(key, next);
    try {
      return await next;
    } finally {
      if (this.tails.get(key) === next) this.tails.delete(key);
    }
  }
}

/** Stable key order and no `null` object members, like the files the iOS app writes. */
export function stringifyDocument(value: unknown): string {
  const normalize = (input: unknown): unknown => {
    if (Array.isArray(input)) return input.map(normalize);
    if (input && typeof input === "object") {
      const out: Record<string, unknown> = {};
      for (const key of Object.keys(input).sort()) {
        const member = (input as Record<string, unknown>)[key];
        if (member === null || member === undefined) continue;
        out[key] = normalize(member);
      }
      return out;
    }
    return input;
  };
  return JSON.stringify(normalize(value), null, 2) + "\n";
}
