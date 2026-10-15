import { afterEach, describe, expect, it } from "vitest";
import { client, makeServer, TINY_JPEG, type TestServer } from "./helpers.js";

let server: TestServer;
afterEach(() => server.cleanup());

const ID = "e621e1f8-c36c-495a-93fc-0c247a3e6e5f";
const doc = (overrides: object = {}) =>
  new TextEncoder().encode(JSON.stringify({ id: ID.toUpperCase(), title: "Synced", createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", ...overrides }));

describe("file sync", () => {
  it("lists, reads, writes and deletes library files with etags", async () => {
    server = await makeServer();
    const api = await client(server);
    expect((await (await api.get("/api/sync/files")).json()).files).toEqual([]);

    const put = await api.put(`/api/sync/files/Recipes/${ID}.json`, doc(), { "if-none-match": "*" });
    expect(put.status).toBe(200);
    const entry = await put.json();
    expect(entry).toMatchObject({ path: `Recipes/${ID}.json` });
    expect(entry.etag).toMatch(/^[0-9a-f]{64}$/);

    const listed = (await (await api.get("/api/sync/files")).json()).files;
    expect(listed.map((f: { path: string }) => f.path)).toEqual([`Recipes/${ID}.json`]);

    const read = await api.get(`/api/sync/files/Recipes/${ID}.json`);
    expect(read.headers.get("etag")).toBe(`"${entry.etag}"`);
    expect(JSON.parse(await read.text()).title).toBe("Synced");

    // The web API sees what sync wrote.
    expect((await (await api.get(`/api/recipes/${ID}`)).json()).title).toBe("Synced");

    expect((await api.del(`/api/sync/files/Recipes/${ID}.json`)).status).toBe(204);
    expect((await api.get(`/api/sync/files/Recipes/${ID}.json`)).status).toBe(404);
  });

  it("refuses to overwrite a file somebody else changed", async () => {
    server = await makeServer();
    const api = await client(server);
    const first = await (await api.put(`/api/sync/files/Recipes/${ID}.json`, doc())).json();
    expect((await api.put(`/api/sync/files/Recipes/${ID}.json`, doc(), { "if-none-match": "*" })).status).toBe(412);

    const second = await api.put(`/api/sync/files/Recipes/${ID}.json`, doc({ title: "Edited" }), { "if-match": `"${first.etag}"` });
    expect(second.status).toBe(200);
    expect((await api.put(`/api/sync/files/Recipes/${ID}.json`, doc({ title: "Stale" }), { "if-match": `"${first.etag}"` })).status).toBe(412);
    expect((await api.call("DELETE", `/api/sync/files/Recipes/${ID}.json`, undefined, { "if-match": `"${first.etag}"` })).status).toBe(412);
    expect((await (await api.get(`/api/recipes/${ID}`)).json()).title).toBe("Edited");
  });

  it("stores photos and checks that documents are what their path says", async () => {
    server = await makeServer();
    const api = await client(server);
    expect((await api.put(`/api/sync/files/Images/${ID}.jpg`, TINY_JPEG)).status).toBe(200);
    expect((await api.put(`/api/sync/files/Images/${ID}.jpg`, new TextEncoder().encode("<html>"))).status).toBe(415);
    expect((await api.put(`/api/sync/files/Recipes/${ID}.json`, new TextEncoder().encode("{nope"))).status).toBe(422);
    expect((await api.put(`/api/sync/files/Recipes/${ID}.json`, doc({ id: "00000000-0000-4000-8000-000000000001" }))).status).toBe(422);
    expect((await api.put(`/api/sync/files/Groceries/${ID}.json`, doc())).status).toBe(422);
    expect((await api.put(`/api/sync/files/Recipes/${ID}.jpg`, TINY_JPEG)).status).toBe(404);
  });

  it("only addresses the library's own folders and file names", async () => {
    server = await makeServer();
    const api = await client(server);
    for (const target of ["Recipes/..%2Fauth.json", ".server/auth.json", "Recipes/notes.txt", `Recipes/${ID.toUpperCase()}.json`, "Elsewhere/x.json"]) {
      expect((await api.get(`/api/sync/files/${target}`)).status).toBe(404);
      expect((await api.put(`/api/sync/files/${target}`, doc())).status).toBe(404);
    }
  });

  it("notices files that were edited on disk behind the server's back", async () => {
    server = await makeServer();
    const api = await client(server);
    const first = await (await api.put(`/api/sync/files/Recipes/${ID}.json`, doc())).json();
    const { writeFile } = await import("node:fs/promises");
    await writeFile(`${server.dataDir}/Recipes/${ID}.json`, doc({ title: "Edited by hand, longer" }));
    const files = (await (await api.get("/api/sync/files")).json()).files;
    expect(files[0].etag).not.toBe(first.etag);
    expect((await (await api.get(`/api/recipes/${ID}`)).json()).title).toBe("Edited by hand, longer");
  });

  it("treats If-Match: * as \"must exist\" and unknown folder names as plain 404s", async () => {
    server = await makeServer();
    const api = await client(server);
    expect((await api.put(`/api/sync/files/Recipes/${ID}.json`, doc(), { "if-match": "*" })).status).toBe(412);
    await api.put(`/api/sync/files/Recipes/${ID}.json`, doc());
    expect((await api.put(`/api/sync/files/Recipes/${ID}.json`, doc({ title: "Again" }), { "if-match": "*" })).status).toBe(200);
    for (const dir of ["constructor", "__proto__", "toString", "hasOwnProperty"]) {
      expect((await api.put(`/api/sync/files/${dir}/${ID}.jpg`, doc())).status).toBe(404);
      expect((await api.get(`/api/sync/files/${dir}/${ID}.json`)).status).toBe(404);
    }
  });
});
