import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createApp } from "../src/app.js";
import { AuthStore } from "../src/auth/auth-store.js";
import { loadConfig, type Config } from "../src/config.js";
import { Library } from "../src/storage/library.js";
import { SyncStore } from "../src/storage/sync-store.js";

export const PASSWORD = "correct horse battery";

export async function makeServer(overrides: Partial<Config> & { seedPassword?: boolean } = {}) {
  const dataDir = await fs.mkdtemp(path.join(os.tmpdir(), "recipes-server-"));
  const { seedPassword = true, ...configOverrides } = overrides;
  const config: Config = {
    ...loadConfig({ DATA_DIR: dataDir, WEB_DIR: "none" }),
    password: seedPassword ? PASSWORD : null,
    ...configOverrides,
  };
  const library = new Library(dataDir);
  await library.init();
  const auth = new AuthStore(dataDir);
  await auth.init(config.password);
  const app = createApp({ config, library, auth, sync: new SyncStore(dataDir, library.lock), quiet: true });
  return {
    app,
    auth,
    library,
    config,
    dataDir,
    cleanup: () => fs.rm(dataDir, { recursive: true, force: true }),
  };
}

export type TestServer = Awaited<ReturnType<typeof makeServer>>;

export async function signIn(server: TestServer): Promise<string> {
  const response = await server.app.request("/api/login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ password: PASSWORD }),
  });
  if (response.status !== 200) throw new Error(`login failed: ${response.status}`);
  return response.headers.get("set-cookie")!.split(";")[0]!;
}

/** A tiny client that signs in once and speaks JSON. */
export async function client(server: TestServer) {
  const cookie = await signIn(server);
  const call = (method: string, url: string, body?: unknown, headers: Record<string, string> = {}) =>
    server.app.request(url, {
      method,
      headers: { cookie, ...(body !== undefined && !(body instanceof Uint8Array) ? { "content-type": "application/json" } : {}), ...headers },
      body: body === undefined ? undefined : body instanceof Uint8Array ? body : JSON.stringify(body),
    });
  return {
    cookie,
    call,
    get: (url: string) => call("GET", url),
    post: (url: string, body?: unknown) => call("POST", url, body ?? {}),
    put: (url: string, body?: unknown, headers?: Record<string, string>) => call("PUT", url, body, headers),
    patch: (url: string, body: unknown) => call("PATCH", url, body),
    del: (url: string) => call("DELETE", url),
  };
}

// 1×1 JPEG, enough for magic-byte sniffing.
export const TINY_JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0xff, 0xd9]);
export const TINY_PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
