import { afterEach, describe, expect, it } from "vitest";
import { client, makeServer, PASSWORD, type TestServer } from "./helpers.js";

let server: TestServer;
afterEach(() => server.cleanup());

const json = (body: unknown) => ({ method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });

describe("authentication", () => {
  it("keeps the API closed until you sign in", async () => {
    server = await makeServer();
    expect((await server.app.request("/api/recipes")).status).toBe(401);
    expect((await server.app.request("/api/sync/files")).status).toBe(401);
    expect((await server.app.request("/api/health")).status).toBe(200);
    const session = await (await server.app.request("/api/session")).json();
    expect(session).toMatchObject({ authenticated: false, setupRequired: false });
  });

  it("signs in with the seeded password and rejects a wrong one", async () => {
    server = await makeServer();
    expect((await server.app.request("/api/login", json({ password: "nope nope nope" }))).status).toBe(401);
    const api = await client(server);
    expect((await api.get("/api/recipes")).status).toBe(200);
    const session = await (await api.get("/api/session")).json();
    expect(session.authenticated).toBe(true);
  });

  it("marks the session cookie HttpOnly and SameSite", async () => {
    server = await makeServer();
    const response = await server.app.request("/api/login", json({ password: PASSWORD }));
    const cookie = response.headers.get("set-cookie")!;
    expect(cookie).toMatch(/HttpOnly/i);
    expect(cookie).toMatch(/SameSite=Lax/i);
  });

  it("walks a new server through setup with the code from the log", async () => {
    server = await makeServer({ seedPassword: false });
    expect((await (await server.app.request("/api/session")).json()).setupRequired).toBe(true);
    expect((await server.app.request("/api/login", json({ password: PASSWORD }))).status).toBe(401);
    expect((await server.app.request("/api/setup", json({ code: "wrong", password: PASSWORD }))).status).toBe(403);
    expect((await server.app.request("/api/setup", json({ code: server.auth.pendingSetupCode, password: "short" }))).status).toBe(422);
    const done = await server.app.request("/api/setup", json({ code: server.auth.pendingSetupCode, password: PASSWORD }));
    expect(done.status).toBe(200);
    expect(done.headers.get("set-cookie")).toMatch(/recipes_session=/);
    expect((await server.app.request("/api/setup", json({ code: "anything", password: PASSWORD }))).status).toBe(409);
  });

  it("slows down password guessing", async () => {
    server = await makeServer();
    for (let i = 0; i < 10; i += 1) await server.app.request("/api/login", json({ password: `guess ${i} guess` }));
    expect((await server.app.request("/api/login", json({ password: PASSWORD }))).status).toBe(429);
  });

  it("issues API tokens that work as bearer credentials and can be revoked", async () => {
    server = await makeServer();
    const api = await client(server);
    const created = await (await api.post("/api/tokens", { name: "iPhone" })).json();
    expect(created.token).toMatch(/^rcp_/);
    expect(JSON.stringify(await (await api.get("/api/tokens")).json())).not.toContain(created.token);

    const bearer = { authorization: `Bearer ${created.token}` };
    expect((await server.app.request("/api/recipes", { headers: bearer })).status).toBe(200);
    expect((await server.app.request("/api/recipes", { headers: { authorization: "Bearer rcp_bogus" } })).status).toBe(401);

    expect((await api.del(`/api/tokens/${created.info.id}`)).status).toBe(204);
    expect((await server.app.request("/api/recipes", { headers: bearer })).status).toBe(401);
  });

  it("blocks state-changing requests that come from another site", async () => {
    server = await makeServer();
    const api = await client(server);
    const forged = await api.call("POST", "/api/groceries", { name: "Milk" }, { origin: "https://evil.example", host: "recipes.local" });
    expect(forged.status).toBe(403);
    const sameSite = await api.call("POST", "/api/groceries", { name: "Milk" }, { "sec-fetch-site": "cross-site" });
    expect(sameSite.status).toBe(403);
    const own = await api.call("POST", "/api/groceries", { name: "Milk" }, { origin: "http://recipes.local", host: "recipes.local" });
    expect(own.status).toBe(201);
  });

  it("signs every browser out when the password changes", async () => {
    server = await makeServer();
    const api = await client(server);
    const other = await client(server);
    const changed = await api.post("/api/password", { current: PASSWORD, next: "a brand new password" });
    expect(changed.status).toBe(200);
    expect((await other.get("/api/recipes")).status).toBe(401);
    const fresh = changed.headers.get("set-cookie")!.split(";")[0]!;
    expect((await server.app.request("/api/recipes", { headers: { cookie: fresh } })).status).toBe(200);
    expect((await server.app.request("/api/login", json({ password: PASSWORD }))).status).toBe(401);
  });

  it("rejects a forged or expired cookie", async () => {
    server = await makeServer();
    expect((await server.app.request("/api/recipes", { headers: { cookie: "recipes_session=9999999999999.abc.def" } })).status).toBe(401);
    const expired = server.auth.createSession(30, Date.now() - 31 * 86_400_000);
    expect((await server.app.request("/api/recipes", { headers: { cookie: `recipes_session=${expired.value}` } })).status).toBe(401);
  });
});

describe("abuse resistance", () => {
  it("counts parallel guesses instead of letting them all through", async () => {
    server = await makeServer();
    const attempts = await Promise.all(
      Array.from({ length: 30 }, (_, i) => server.app.request("/api/login", json({ password: `wrong guess ${i}` }))),
    );
    const statuses = attempts.map((response) => response.status);
    expect(statuses.filter((status) => status === 401)).toHaveLength(10);
    expect(statuses.filter((status) => status === 429)).toHaveLength(20);
  });

  it("refuses oversized bodies on the sign-in routes before reading them", async () => {
    server = await makeServer();
    const huge = JSON.stringify({ password: "a".repeat(3 * 1024 * 1024) });
    for (const path of ["/api/login", "/api/setup"]) {
      const response = await server.app.request(path, { method: "POST", headers: { "content-type": "application/json", "content-length": String(huge.length) }, body: huge });
      expect(response.status).toBe(413);
    }
  });
});
