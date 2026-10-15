import { afterEach, describe, expect, it } from "vitest";
import { client, makeServer, type TestServer } from "./helpers.js";

let server: TestServer;
afterEach(() => server.cleanup());

describe("meal plan", () => {
  it("plans a recipe and takes it out of Up Next", async () => {
    server = await makeServer();
    const api = await client(server);
    const recipe = await (await api.post("/api/recipes", { title: "Pasta", wantToCook: true })).json();
    expect(recipe.wantToCook).toBe(true);

    const entry = await (await api.post("/api/meal-plan", { recipeID: recipe.id, day: "2026-10-15", meal: "dinner" })).json();
    expect(entry).toMatchObject({ title: "Pasta", day: "2026-10-15", meal: "dinner", recipeID: recipe.id });
    expect((await (await api.get(`/api/recipes/${recipe.id}`)).json()).wantToCook).toBe(false);

    await api.post("/api/meal-plan", { title: "Leftovers", day: "2026-10-15", meal: "breakfast" });
    await api.post("/api/meal-plan", { title: "Later", day: "2026-10-20" });
    const week = await (await api.get("/api/meal-plan?from=2026-10-14&to=2026-10-16")).json();
    expect(week.map((e: { title: string }) => e.title)).toEqual(["Leftovers", "Pasta"]);

    const moved = await (await api.put(`/api/meal-plan/${entry.id}`, { day: "2026-10-16", meal: "lunch" })).json();
    expect(moved).toMatchObject({ day: "2026-10-16", meal: "lunch", title: "Pasta" });
    expect((await api.del(`/api/meal-plan/${entry.id}`)).status).toBe(204);
    expect((await api.post("/api/meal-plan", { day: "2026-10-15" })).status).toBe(422);
    expect((await api.post("/api/meal-plan", { title: "x", day: "tomorrow" })).status).toBe(422);
  });
});

describe("groceries", () => {
  it("adds, checks, de-duplicates and clears", async () => {
    server = await makeServer();
    const api = await client(server);
    const added = await (await api.post("/api/groceries", [{ name: "Milk", quantity: "1 l" }, { name: "milk", quantity: "1 l" }, { name: "Eggs" }])).json();
    expect(added.map((i: { name: string }) => i.name)).toEqual(["Milk", "Eggs"]);
    expect(await (await api.post("/api/groceries", { name: "MILK", quantity: "1 l" })).json()).toEqual([]);

    const milk = added[0];
    const checked = await (await api.patch(`/api/groceries/${milk.id}`, { isChecked: true })).json();
    expect(checked.isChecked).toBe(true);
    expect(await (await api.post("/api/groceries/clear", { scope: "completed" })).json()).toEqual({ removed: 1 });
    expect((await (await api.get("/api/groceries")).json()).map((i: { name: string }) => i.name)).toEqual(["Eggs"]);
    expect(await (await api.post("/api/groceries/clear", { scope: "all" })).json()).toEqual({ removed: 1 });
    expect((await api.del(`/api/groceries/${milk.id}`)).status).toBe(404);
  });

  it("writes every field the Swift decoder requires", async () => {
    server = await makeServer();
    const api = await client(server);
    const [item] = await (await api.post("/api/groceries", { name: "Salt" })).json();
    expect(Object.keys(item).sort()).toEqual(["createdAt", "id", "isChecked", "name", "quantity", "updatedAt"]);
  });
});
