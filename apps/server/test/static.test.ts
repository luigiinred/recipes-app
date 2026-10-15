import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { makeServer, type TestServer } from "./helpers.js";

let server: TestServer;
let webDir: string;
afterEach(async () => {
  await server.cleanup();
  await fs.rm(webDir, { recursive: true, force: true });
  await fs.rm(path.join(path.dirname(webDir), "outside-secret.txt"), { force: true });
});

async function serverWithWeb() {
  webDir = await fs.mkdtemp(path.join(os.tmpdir(), "recipes-web-"));
  await fs.mkdir(path.join(webDir, "assets"));
  await fs.writeFile(path.join(webDir, "index.html"), '<!doctype html><div id="root"></div>');
  await fs.writeFile(path.join(webDir, "assets", "app-abc123.js"), "console.log(1)");
  await fs.writeFile(path.join(path.dirname(webDir), "outside-secret.txt"), "secret");
  server = await makeServer({ webDir });
}

describe("web UI hosting", () => {
  it("serves the app, long-caches hashed assets and falls back to index.html for client routes", async () => {
    await serverWithWeb();
    const index = await server.app.request("/");
    expect(index.status).toBe(200);
    expect(index.headers.get("content-type")).toMatch(/text\/html/);
    expect(index.headers.get("content-security-policy")).toContain("default-src 'self'");
    expect(index.headers.get("x-frame-options")).toBe("DENY");

    const asset = await server.app.request("/assets/app-abc123.js");
    expect(asset.headers.get("cache-control")).toContain("immutable");
    expect(asset.headers.get("content-type")).toMatch(/javascript/);

    expect(await (await server.app.request("/recipes/some-id/edit")).text()).toContain('id="root"');
    expect((await server.app.request("/missing.js")).status).toBe(404);
  });

  it("can't be talked into reading outside the web folder or answering API paths with HTML", async () => {
    await serverWithWeb();
    for (const target of ["/../outside-secret.txt", "/%2e%2e/outside-secret.txt", "/..%2foutside-secret.txt", "/assets/../../outside-secret.txt"]) {
      const response = await server.app.request(target);
      expect(await response.text()).not.toContain("secret");
    }
    const api = await server.app.request("/api/nope");
    expect(api.status).toBe(401);
  });

  it("answers a malformed address with 400", async () => {
    await serverWithWeb();
    expect((await server.app.request("/%E0%A4%A")).status).toBe(400);
  });
});
