import {
  createHash,
  createHmac,
  randomBytes,
  scrypt as scryptCallback,
  timingSafeEqual,
  type BinaryLike,
} from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import { isoDate, type ApiToken } from "@recipes/schema";
import { atomicWrite, isMissing, KeyedLock } from "../storage/fsutil.js";

const scryptAsync = promisify(scryptCallback) as (password: BinaryLike, salt: BinaryLike, keylen: number) => Promise<Buffer>;

// Hashing runs on the thread pool the file system shares; a few at a time keeps sign-in floods from starving it.
const MAX_CONCURRENT_HASHES = 2;
let activeHashes = 0;
const waitingHashes: (() => void)[] = [];

async function scrypt(password: BinaryLike, salt: BinaryLike, keylen: number): Promise<Buffer> {
  if (activeHashes >= MAX_CONCURRENT_HASHES) await new Promise<void>((resolve) => waitingHashes.push(resolve));
  else activeHashes += 1;
  try {
    return await scryptAsync(password, salt, keylen);
  } finally {
    const next = waitingHashes.shift();
    if (next) next();
    else activeHashes -= 1;
  }
}

export const MIN_PASSWORD_LENGTH = 8;

interface StoredToken extends ApiToken {
  hash: string;
}

interface AuthFile {
  passwordHash: string | null;
  tokens: StoredToken[];
}

const sha256 = (value: string): string => createHash("sha256").update(value).digest("hex");

async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const key = await scrypt(password.normalize("NFKC"), salt, 64);
  return `scrypt$${salt.toString("base64")}$${key.toString("base64")}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [scheme, salt, key] = stored.split("$");
  if (scheme !== "scrypt" || !salt || !key) return false;
  const expected = Buffer.from(key, "base64");
  const actual = await scrypt(password.normalize("NFKC"), Buffer.from(salt, "base64"), expected.length);
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

/**
 * Owner password, API tokens and the cookie-signing secret. These live in `<data>/.server/`, next to the library
 * folders but outside them, and are written owner-readable only.
 */
export class AuthStore {
  private readonly file: string;
  private readonly secretFile: string;
  private readonly setupCodeFile: string;
  private state: AuthFile = { passwordHash: null, tokens: [] };
  private secret = Buffer.alloc(0);
  private setupCode: string | null = null;
  private lock = new KeyedLock();

  constructor(dataDir: string) {
    const dir = path.join(dataDir, ".server");
    this.file = path.join(dir, "auth.json");
    this.secretFile = path.join(dir, "secret");
    this.setupCodeFile = path.join(dir, "setup-code");
  }

  async init(seedPassword: string | null): Promise<void> {
    try {
      this.state = { ...this.state, ...JSON.parse(await fs.readFile(this.file, "utf8")) };
    } catch (error) {
      if (!isMissing(error)) throw error;
    }
    try {
      this.secret = Buffer.from((await fs.readFile(this.secretFile, "utf8")).trim(), "hex");
    } catch (error) {
      if (!isMissing(error)) throw error;
    }
    if (this.secret.length < 32) {
      this.secret = randomBytes(32);
      await atomicWrite(this.secretFile, this.secret.toString("hex"), 0o600);
    }
    if (!this.state.passwordHash && seedPassword) {
      await this.setPassword(seedPassword);
    }
    if (!this.state.passwordHash) {
      this.setupCode = randomBytes(8).toString("hex");
      await atomicWrite(this.setupCodeFile, this.setupCode + "\n", 0o600);
    } else {
      await fs.rm(this.setupCodeFile, { force: true });
    }
  }

  get setupRequired(): boolean {
    return !this.state.passwordHash;
  }

  get pendingSetupCode(): string | null {
    return this.setupRequired ? this.setupCode : null;
  }

  private async save(): Promise<void> {
    await atomicWrite(this.file, JSON.stringify(this.state, null, 2), 0o600);
  }

  async setPassword(password: string): Promise<void> {
    const passwordHash = await hashPassword(password);
    await this.lock.run("auth", async () => {
      this.state.passwordHash = passwordHash;
      await this.save();
    });
    this.setupCode = null;
    await fs.rm(this.setupCodeFile, { force: true });
  }

  async checkPassword(password: string): Promise<boolean> {
    return this.state.passwordHash ? verifyPassword(password, this.state.passwordHash) : false;
  }

  checkSetupCode(code: string): boolean {
    if (!this.setupCode) return false;
    const a = Buffer.from(code.trim());
    const b = Buffer.from(this.setupCode);
    return a.length === b.length && timingSafeEqual(a, b);
  }

  // Sessions are stateless: an expiry plus an HMAC keyed by the secret and the current password hash,
  // so changing the password signs every browser out.
  private sessionKey(): Buffer {
    return createHmac("sha256", this.secret).update(this.state.passwordHash ?? "").digest();
  }

  createSession(days: number, now = Date.now()): { value: string; maxAgeSeconds: number } {
    const expires = now + days * 86_400_000;
    const body = `${expires}.${randomBytes(12).toString("base64url")}`;
    const mac = createHmac("sha256", this.sessionKey()).update(body).digest("base64url");
    return { value: `${body}.${mac}`, maxAgeSeconds: days * 86_400 };
  }

  verifySession(value: string | undefined, now = Date.now()): boolean {
    if (!value || !this.state.passwordHash) return false;
    const parts = value.split(".");
    if (parts.length !== 3) return false;
    const [expires, nonce, mac] = parts as [string, string, string];
    const expected = createHmac("sha256", this.sessionKey()).update(`${expires}.${nonce}`).digest("base64url");
    const a = Buffer.from(mac);
    const b = Buffer.from(expected);
    return a.length === b.length && timingSafeEqual(a, b) && Number(expires) > now;
  }

  listTokens(): ApiToken[] {
    return this.state.tokens.map(({ hash: _hash, ...token }) => token);
  }

  async createToken(name: string): Promise<{ token: string; info: ApiToken }> {
    const token = `rcp_${randomBytes(32).toString("base64url")}`;
    const info: ApiToken = { id: randomBytes(6).toString("hex"), name, createdAt: isoDate(), lastUsedAt: null };
    await this.lock.run("auth", async () => {
      this.state.tokens.push({ ...info, hash: sha256(token) });
      await this.save();
    });
    return { token, info };
  }

  async revokeToken(id: string): Promise<boolean> {
    return this.lock.run("auth", async () => {
      const before = this.state.tokens.length;
      this.state.tokens = this.state.tokens.filter((token) => token.id !== id);
      if (this.state.tokens.length === before) return false;
      await this.save();
      return true;
    });
  }

  /** Returns true for a live token and records when it was last used (at most once a minute, to spare the disk). */
  verifyToken(token: string, now = new Date()): boolean {
    const hash = sha256(token);
    const found = this.state.tokens.find((candidate) => candidate.hash === hash);
    if (!found) return false;
    const last = found.lastUsedAt ? Date.parse(found.lastUsedAt) : 0;
    if (now.getTime() - last > 60_000) {
      found.lastUsedAt = isoDate(now);
      void this.lock.run("auth", () => this.save()).catch(() => {});
    }
    return true;
  }
}

/** Remembers failed sign-ins per client so a password can't be guessed at speed. */
export class LoginLimiter {
  private failures = new Map<string, { count: number; resetAt: number }>();

  constructor(
    private readonly maxFailures = 10,
    private readonly windowMs = 15 * 60_000,
  ) {}

  /**
   * Counts an attempt before it is checked, so a burst of parallel guesses can't all slip in ahead of the first
   * answer. Returns false once the client is out of attempts; `succeed` gives them back.
   */
  attempt(key: string, now = Date.now()): boolean {
    const entry = this.failures.get(key);
    if (entry && entry.resetAt > now && entry.count >= this.maxFailures) return false;
    if (!entry || entry.resetAt <= now) this.failures.set(key, { count: 1, resetAt: now + this.windowMs });
    else entry.count += 1;
    if (this.failures.size > 5000) {
      for (const [k, v] of this.failures) if (v.resetAt <= now) this.failures.delete(k);
    }
    return true;
  }

  succeed(key: string): void {
    this.failures.delete(key);
  }
}
