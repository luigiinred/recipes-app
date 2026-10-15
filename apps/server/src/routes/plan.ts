import { isoDate, mealPlanInputSchema, type MealPlanEntry } from "@recipes/schema";
import { Hono } from "hono";
import { randomUUID } from "node:crypto";
import { HttpError } from "../errors.js";
import { idParam, jsonBody } from "../http.js";
import type { Library } from "../storage/library.js";

const sortEntries = (entries: MealPlanEntry[]): MealPlanEntry[] =>
  entries.sort((a, b) => a.day.localeCompare(b.day) || ["breakfast", "lunch", "dinner", "snack"].indexOf(a.meal) - ["breakfast", "lunch", "dinner", "snack"].indexOf(b.meal) || a.createdAt.localeCompare(b.createdAt));

export function planRoutes(library: Library): Hono {
  const app = new Hono();

  app.get("/meal-plan", async (c) => {
    const from = c.req.query("from");
    const to = c.req.query("to");
    const entries = (await library.mealPlan.list()).filter((entry) => (!from || entry.day >= from) && (!to || entry.day <= to));
    return c.json(sortEntries(entries));
  });

  // Planning a recipe takes it out of the Up Next queue, as in the apps.
  app.post("/meal-plan", async (c) => {
    const input = await jsonBody(c, mealPlanInputSchema);
    const recipe = input.recipeID ? await library.recipes.get(input.recipeID) : null;
    if (input.recipeID && !recipe) throw new HttpError(422, "recipeID: No such recipe.");
    const title = input.title || recipe?.title;
    if (!title) throw new HttpError(422, "title: A planned meal needs a title or a recipe.");
    const now = isoDate();
    const entry: MealPlanEntry = { id: randomUUID(), recipeID: recipe?.id, title, day: input.day, meal: input.meal, createdAt: now, updatedAt: now };
    await library.mealPlan.put(entry);
    if (recipe?.wantToCook) await library.saveRecipe({ ...recipe, wantToCook: false, queuedAt: undefined }, recipe.id);
    return c.json(entry, 201);
  });

  app.put("/meal-plan/:id", async (c) => {
    const id = idParam(c);
    const input = await jsonBody(c, mealPlanInputSchema);
    const entry = await library.lock.run(`Calendar/${id}.json`, async () => {
      const existing = await library.mealPlan.get(id);
      if (!existing) throw new HttpError(404, "No such meal.");
      const changed: MealPlanEntry = {
        ...existing,
        recipeID: input.recipeID ?? existing.recipeID,
        title: input.title || existing.title,
        day: input.day,
        meal: input.meal,
        updatedAt: isoDate(),
      };
      await library.mealPlan.put(changed);
      return changed;
    });
    return c.json(entry);
  });

  app.delete("/meal-plan/:id", async (c) => {
    if (!(await library.mealPlan.delete(idParam(c)))) throw new HttpError(404, "No such meal.");
    return c.body(null, 204);
  });

  return app;
}
