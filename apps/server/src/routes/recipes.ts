import {
  collectionTitles,
  COLLECTIONS,
  filterCategory,
  filterCollection,
  recipeInputSchema,
  recipeMatches,
  recipePatchSchema,
  type CollectionId,
} from "@recipes/schema";
import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { randomUUID } from "node:crypto";
import { HttpError } from "../errors.js";
import { idParam, imageResponse, jsonBody } from "../http.js";
import { sniffImage } from "../storage/image-store.js";
import type { Library } from "../storage/library.js";

const MAX_PHOTO_BYTES = 15 * 1024 * 1024;

export function recipeRoutes(library: Library): Hono {
  const app = new Hono();

  app.get("/recipes", async (c) => {
    let recipes = await library.listRecipeViews();
    const collection = c.req.query("collection");
    if (collection) {
      if (!(COLLECTIONS as readonly string[]).includes(collection)) {
        throw new HttpError(400, `Unknown collection. Use one of: ${Object.keys(collectionTitles).join(", ")}.`);
      }
      recipes = filterCollection(recipes, collection as CollectionId);
    }
    const tag = c.req.query("tag");
    if (tag) recipes = filterCategory(recipes, tag);
    const q = c.req.query("q");
    if (q) recipes = recipes.filter((recipe) => recipeMatches(recipe, q));
    return c.json(recipes);
  });

  app.post("/recipes", async (c) => {
    const input = await jsonBody(c, recipeInputSchema);
    const id = input.id ?? randomUUID();
    await library.lock.run(`Recipes/${id}.json`, async () => {
      if (await library.recipes.get(id)) throw new HttpError(409, "A recipe with that id already exists.");
      await library.saveRecipe(input, id);
    });
    return c.json(await library.recipeView(id), 201);
  });

  app.get("/recipes/:id", async (c) => {
    const view = await library.recipeView(idParam(c));
    if (!view) throw new HttpError(404, "No such recipe.");
    return c.json(view);
  });

  app.put("/recipes/:id", async (c) => {
    const id = idParam(c);
    const input = await jsonBody(c, recipeInputSchema);
    if (input.id && input.id !== id) throw new HttpError(422, "The recipe's id doesn't match the address.");
    await library.lock.run(`Recipes/${id}.json`, () => library.saveRecipe(input, id));
    return c.json(await library.recipeView(id));
  });

  app.patch("/recipes/:id", async (c) => {
    const id = idParam(c);
    const patch = await jsonBody(c, recipePatchSchema);
    await library.lock.run(`Recipes/${id}.json`, async () => {
      const existing = await library.recipes.get(id);
      if (!existing) throw new HttpError(404, "No such recipe.");
      await library.saveRecipe({ ...existing, ...patch }, id);
    });
    return c.json(await library.recipeView(id));
  });

  app.delete("/recipes/:id", async (c) => {
    if (!(await library.deleteRecipe(idParam(c)))) throw new HttpError(404, "No such recipe.");
    return c.body(null, 204);
  });

  app.get("/recipes/:id/image", async (c) => {
    const image = await library.images.read(idParam(c));
    const kind = image && sniffImage(image.data);
    if (!image || !kind) throw new HttpError(404, "This recipe has no photo.");
    return imageResponse(c, image, kind);
  });

  app.put("/recipes/:id/image", bodyLimit({ maxSize: MAX_PHOTO_BYTES, onError: () => { throw new HttpError(413, "That photo is too large."); } }), async (c) => {
    const id = idParam(c);
    if (!(await library.recipes.get(id))) throw new HttpError(404, "No such recipe.");
    const data = Buffer.from(await c.req.arrayBuffer());
    if (!sniffImage(data)) throw new HttpError(415, "That isn't a JPEG, PNG, WebP or GIF image.");
    await library.images.write(id, data);
    return c.json(await library.recipeView(id));
  });

  app.delete("/recipes/:id/image", async (c) => {
    const id = idParam(c);
    if (!(await library.recipes.get(id))) throw new HttpError(404, "No such recipe.");
    await library.images.delete(id);
    return c.body(null, 204);
  });

  app.get("/step-images/:id", async (c) => {
    const image = await library.stepImages.read(idParam(c));
    const kind = image && sniffImage(image.data);
    if (!image || !kind) throw new HttpError(404, "No such photo.");
    return imageResponse(c, image, kind);
  });

  return app;
}
