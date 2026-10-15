import { afterEach, describe, expect, it } from "vitest";
import { client, makeServer, TINY_JPEG, type TestServer } from "./helpers.js";

let server: TestServer;
const servers: TestServer[] = [];
afterEach(async () => {
  await Promise.all(servers.splice(0).map((s) => s.cleanup()));
});
const fresh = async () => {
  server = await makeServer();
  servers.push(server);
  return server;
};

describe("export and restore", () => {
  it("moves a whole library, photos included, from one server to another", async () => {
    const source = await client(await fresh());
    const recipe = await (await source.post("/api/recipes", { title: "Soup", ingredients: ["2 cups stock"], isFavorite: true })).json();
    await source.put(`/api/recipes/${recipe.id}/image`, TINY_JPEG, { "content-type": "image/jpeg" });
    await source.post("/api/meal-plan", { recipeID: recipe.id, day: "2026-10-15" });
    await source.post("/api/groceries", { name: "Bread" });

    const exported = await (await source.get("/api/export")).json();
    expect(exported).toMatchObject({ version: 1 });
    expect(Object.keys(exported.images)).toEqual([recipe.id]);

    const target = await client(await fresh());
    const counts = await (await target.post("/api/export/restore", exported)).json();
    expect(counts).toEqual({ recipes: 1, mealPlan: 1, groceries: 1, feeds: 0, images: 1 });
    const restored = await (await target.get(`/api/recipes/${recipe.id}`)).json();
    expect(restored).toMatchObject({ title: "Soup", isFavorite: true });
    expect(restored.imageVersion).toBeGreaterThan(0);
    expect((await (await target.get("/api/meal-plan")).json()).length).toBe(1);
  });

  it("ignores photo keys that aren't ids", async () => {
    const api = await client(await fresh());
    const bad = { version: 1, exportedAt: "2026-01-01T00:00:00Z", recipes: [], mealPlan: [], groceries: [], feeds: [], images: { "../../escape": "AAAA" } };
    expect(await (await api.post("/api/export/restore", bad)).json()).toMatchObject({ images: 0 });
  });

  it("accepts the document the iOS app exports", async () => {
    const api = await client(await fresh());
    const id = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F";
    const fromApp = {
      version: 1,
      exportedAt: "2026-10-14T12:00:00Z",
      recipes: [{ id, title: "Cake", createdAt: "2026-10-14T12:00:00Z", updatedAt: "2026-10-14T12:00:00Z" }],
      mealPlan: [],
      groceries: [],
      feeds: [],
      images: { [id.toLowerCase()]: Buffer.from(TINY_JPEG).toString("base64") },
    };
    expect((await api.post("/api/export/restore", fromApp)).status).toBe(200);
    expect((await (await api.get(`/api/recipes/${id}`)).json()).title).toBe("Cake");
  });
});
