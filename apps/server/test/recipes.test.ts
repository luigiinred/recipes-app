import fs from "node:fs/promises";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { client, makeServer, TINY_JPEG, TINY_PNG, type TestServer } from "./helpers.js";

let server: TestServer;
afterEach(() => server.cleanup());

const created = async (api: Awaited<ReturnType<typeof client>>, body: object) => {
  const response = await api.post("/api/recipes", body);
  expect(response.status).toBe(201);
  return response.json();
};

describe("recipes", () => {
  it("creates, reads, updates and deletes a recipe", async () => {
    server = await makeServer();
    const api = await client(server);
    const recipe = await created(api, { title: "  Tomato   Soup ", ingredients: ["2 Tablespoons butter", "1½ cup stock"], steps: ["Step 1: simmer", "stir"] });
    expect(recipe).toMatchObject({
      title: "Tomato Soup",
      ingredients: ["2 tbsp butter", "1 1/2 cups stock"],
      steps: ["Simmer.", "Stir."],
      imageVersion: null,
    });
    expect(recipe.id).toMatch(/^[0-9a-f-]{36}$/);

    const listed = await (await api.get("/api/recipes")).json();
    expect(listed.map((r: { title: string }) => r.title)).toEqual(["Tomato Soup"]);

    const updated = await (await api.put(`/api/recipes/${recipe.id}`, { ...recipe, title: "Tomato Basil Soup", isFavorite: true })).json();
    expect(updated).toMatchObject({ title: "Tomato Basil Soup", isFavorite: true, createdAt: recipe.createdAt });

    expect((await api.del(`/api/recipes/${recipe.id}`)).status).toBe(204);
    expect((await api.get(`/api/recipes/${recipe.id}`)).status).toBe(404);
  });

  it("writes the same files the iOS app does", async () => {
    server = await makeServer();
    const api = await client(server);
    const recipe = await created(api, { title: "Eggs", servings: null, rating: null, tags: ["Breakfast"] });
    const raw = JSON.parse(await fs.readFile(path.join(server.dataDir, "Recipes", `${recipe.id}.json`), "utf8"));
    expect(raw).not.toHaveProperty("servings");
    expect(raw).not.toHaveProperty("rating");
    expect(raw).not.toHaveProperty("imageVersion");
    expect(raw).toMatchObject({ title: "Eggs", tags: ["Breakfast"], isFavorite: false, wantToCook: false });
    expect(raw.createdAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
  });

  it("reads recipes written by the iOS app, with uppercase ids", async () => {
    server = await makeServer();
    const id = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F";
    await fs.writeFile(
      path.join(server.dataDir, "Recipes", `${id.toLowerCase()}.json`),
      JSON.stringify({ id, title: "From iPhone", stepImages: [id], createdAt: "2026-01-01T10:00:00Z", updatedAt: "2026-01-01T10:00:00Z" }),
    );
    const api = await client(server);
    const recipe = await (await api.get(`/api/recipes/${id}`)).json();
    expect(recipe).toMatchObject({ id: id.toLowerCase(), title: "From iPhone", stepImages: [id.toLowerCase()], steps: [] });
  });

  it("keeps step timestamps and photos lined up when a blank step is dropped", async () => {
    server = await makeServer();
    const api = await client(server);
    const a = "00000000-0000-4000-8000-00000000000a";
    const c = "00000000-0000-4000-8000-00000000000c";
    const recipe = await created(api, { title: "R", steps: ["One", "  ", "Three"], stepTimestamps: [5, 10, 15], stepImages: [a, null, c] });
    expect(recipe.steps).toEqual(["One.", "Three."]);
    expect(recipe.stepTimestamps).toEqual([5, 15]);
    expect(recipe.stepImages).toEqual([a, c]);
  });

  it("turns DRESSING: lines into ingredient sections", async () => {
    server = await makeServer();
    const api = await client(server);
    const recipe = await created(api, { title: "Salad", ingredients: ["DRESSING:", "1/3 cup olive oil", "SALAD:", "5 cups romaine"] });
    expect(recipe.ingredients).toEqual(["1/3 cup olive oil", "5 cups romaine"]);
    expect(recipe.ingredientSections).toEqual([{ title: "Dressing", start: 0 }, { title: "Salad", start: 1 }]);
  });

  it("refuses absurdly long lines instead of grinding on them", async () => {
    server = await makeServer();
    const api = await client(server);
    expect((await api.post("/api/recipes", { title: "R", ingredients: ["1 cup " + "x".repeat(400_000)] })).status).toBe(422);
    expect((await api.post("/api/recipes", { title: "R", steps: ["y".repeat(50_000)] })).status).toBe(422);
  });

  it("refuses a recipe without a title and non-web links", async () => {
    server = await makeServer();
    const api = await client(server);
    expect((await api.post("/api/recipes", { title: "   " })).status).toBe(422);
    const recipe = await created(api, { title: "Link", sourceURL: "javascript:alert(1)", imageURL: "data:text/html,x" });
    expect(recipe.sourceURL).toBeUndefined();
    expect(recipe.imageURL).toBeUndefined();
  });

  it("queues, rates and favorites with PATCH", async () => {
    server = await makeServer();
    const api = await client(server);
    const recipe = await created(api, { title: "R" });
    const queued = await (await api.patch(`/api/recipes/${recipe.id}`, { wantToCook: true, rating: 5, isFavorite: true })).json();
    expect(queued).toMatchObject({ wantToCook: true, rating: 5, isFavorite: true });
    expect(queued.queuedAt).toBeTruthy();
    const cleared = await (await api.patch(`/api/recipes/${recipe.id}`, { wantToCook: false, rating: null })).json();
    expect(cleared.queuedAt).toBeUndefined();
    expect(cleared.rating).toBeUndefined();
    expect((await api.patch(`/api/recipes/${recipe.id}`, { rating: 9 })).status).toBe(422);
    expect((await api.patch(`/api/recipes/${recipe.id}`, { title: "x" })).status).toBe(422);
  });

  it("searches and filters", async () => {
    server = await makeServer();
    const api = await client(server);
    await created(api, { title: "Lemon Cake", tags: ["Dessert/Cake"], isFavorite: true });
    await created(api, { title: "Beef Stew", ingredients: ["1 lb beef"], tags: ["Dinner"] });
    const titles = async (query: string) => (await (await api.get(`/api/recipes?${query}`)).json()).map((r: { title: string }) => r.title);
    expect(await titles("q=beef")).toEqual(["Beef Stew"]);
    expect(await titles("tag=dessert")).toEqual(["Lemon Cake"]);
    expect(await titles("collection=favorites")).toEqual(["Lemon Cake"]);
    expect((await api.get("/api/recipes?collection=bogus")).status).toBe(400);
  });

  it("stores a cover photo and removes it with the recipe", async () => {
    server = await makeServer();
    const api = await client(server);
    const recipe = await created(api, { title: "Photo" });
    expect((await api.get(`/api/recipes/${recipe.id}/image`)).status).toBe(404);

    expect((await api.put(`/api/recipes/${recipe.id}/image`, new TextEncoder().encode("<svg onload=alert(1)>"), { "content-type": "image/svg+xml" })).status).toBe(415);
    const stored = await api.put(`/api/recipes/${recipe.id}/image`, TINY_JPEG, { "content-type": "image/jpeg" });
    expect((await stored.json()).imageVersion).toBeGreaterThan(0);

    const image = await api.get(`/api/recipes/${recipe.id}/image`);
    expect(image.headers.get("content-type")).toBe("image/jpeg");
    expect(image.headers.get("x-content-type-options")).toBe("nosniff");
    expect(new Uint8Array(await image.arrayBuffer())).toEqual(TINY_JPEG);
    expect((await api.get(`/api/recipes/${recipe.id}/image`)).status).toBe(200);

    await api.put(`/api/recipes/${recipe.id}/image`, TINY_PNG, { "content-type": "image/png" });
    expect((await api.get(`/api/recipes/${recipe.id}/image`)).headers.get("content-type")).toBe("image/png");

    await api.del(`/api/recipes/${recipe.id}`);
    expect(await server.library.images.read(recipe.id)).toBeNull();
  });

  it("deletes step photos that a save no longer references", async () => {
    server = await makeServer();
    const api = await client(server);
    const photo = "00000000-0000-4000-8000-0000000000aa";
    await server.library.stepImages.write(photo, TINY_JPEG);
    const recipe = await created(api, { title: "R", steps: ["Mix"], stepImages: [photo] });
    expect((await api.get(`/api/step-images/${photo}`)).status).toBe(200);
    await api.put(`/api/recipes/${recipe.id}`, { ...recipe, stepImages: [] });
    expect((await api.get(`/api/step-images/${photo}`)).status).toBe(404);
  });

  it("answers 404 for ids that aren't ids instead of touching the disk", async () => {
    server = await makeServer();
    const api = await client(server);
    expect((await api.get("/api/recipes/..%2F..%2Fetc%2Fpasswd")).status).toBe(404);
    expect((await api.get("/api/step-images/not-a-uuid")).status).toBe(404);
  });
});

describe("large bodies and unknown fields", () => {
  it("takes photos far bigger than a JSON body is allowed to be", async () => {
    server = await makeServer();
    const api = await client(server);
    const recipe = await created(api, { title: "Big photo" });
    const photo = new Uint8Array(5 * 1024 * 1024);
    photo.set(TINY_JPEG);
    expect((await api.put(`/api/recipes/${recipe.id}/image`, photo, { "content-type": "image/jpeg" })).status).toBe(200);
    expect((await api.put(`/api/sync/files/Images/${recipe.id}.jpg`, photo)).status).toBe(200);

    const tooBig = await api.post("/api/recipes", { title: "Huge", notes: "x".repeat(3 * 1024 * 1024) });
    expect(tooBig.status).toBe(413);
  });

  it("keeps fields it doesn't know about when a recipe is edited", async () => {
    server = await makeServer();
    const id = "0f0f0f0f-0f0f-4f0f-8f0f-0f0f0f0f0f0f";
    const file = path.join(server.dataDir, "Recipes", `${id}.json`);
    await fs.writeFile(file, JSON.stringify({ id, title: "Future", servings: 4, difficulty: "easy", createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z" }));
    const api = await client(server);
    await api.patch(`/api/recipes/${id}`, { isFavorite: true });
    await api.put(`/api/recipes/${id}`, { title: "Future 2" });
    const raw = JSON.parse(await fs.readFile(file, "utf8"));
    expect(raw).toMatchObject({ title: "Future 2", difficulty: "easy" });
    expect(raw).not.toHaveProperty("servings");
  });

  it("sends API answers without caching", async () => {
    server = await makeServer();
    const api = await client(server);
    expect((await api.get("/api/recipes")).headers.get("cache-control")).toBe("no-store");
  });
});
