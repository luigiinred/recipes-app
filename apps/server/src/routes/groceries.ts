import { groceryInputSchema, groceryPatchSchema, isoDate, type GroceryItem } from "@recipes/schema";
import { Hono } from "hono";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { HttpError } from "../errors.js";
import { idParam, jsonBody } from "../http.js";
import type { Library } from "../storage/library.js";

const addSchema = z.union([groceryInputSchema, z.array(groceryInputSchema).max(500)]);
const clearSchema = z.object({ scope: z.enum(["completed", "all"]) });

export function groceryRoutes(library: Library): Hono {
  const app = new Hono();

  app.get("/groceries", async (c) => {
    const items = await library.groceries.list();
    return c.json(items.sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt)));
  });

  // Skips an item that is already waiting on the list with the same name and quantity.
  app.post("/groceries", async (c) => {
    const body = await jsonBody(c, addSchema);
    const inputs = Array.isArray(body) ? body : [body];
    const waiting = (await library.groceries.list()).filter((item) => !item.isChecked);
    const added: GroceryItem[] = [];
    for (const input of inputs) {
      const duplicate = [...waiting, ...added].some(
        (item) => item.name.toLowerCase() === input.name.toLowerCase() && item.quantity === input.quantity,
      );
      if (duplicate) continue;
      const now = isoDate();
      const item: GroceryItem = {
        id: randomUUID(),
        name: input.name,
        quantity: input.quantity,
        isChecked: input.isChecked,
        recipeID: input.recipeID,
        createdAt: now,
        updatedAt: now,
      };
      await library.groceries.put(item);
      added.push(item);
    }
    return c.json(added, 201);
  });

  app.patch("/groceries/:id", async (c) => {
    const id = idParam(c);
    const patch = await jsonBody(c, groceryPatchSchema);
    const item = await library.lock.run(`Groceries/${id}.json`, async () => {
      const existing = await library.groceries.get(id);
      if (!existing) throw new HttpError(404, "No such item.");
      const changed: GroceryItem = { ...existing, ...patch, updatedAt: isoDate() };
      await library.groceries.put(changed);
      return changed;
    });
    return c.json(item);
  });

  app.delete("/groceries/:id", async (c) => {
    if (!(await library.groceries.delete(idParam(c)))) throw new HttpError(404, "No such item.");
    return c.body(null, 204);
  });

  app.post("/groceries/clear", async (c) => {
    const { scope } = await jsonBody(c, clearSchema);
    const doomed = (await library.groceries.list()).filter((item) => scope === "all" || item.isChecked);
    for (const item of doomed) await library.groceries.delete(item.id);
    return c.json({ removed: doomed.length });
  });

  return app;
}
