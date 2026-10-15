import fs from "node:fs/promises";
import path from "node:path";
import {
  feedSchema,
  groceryItemSchema,
  isUUID,
  isoDate,
  mealPlanEntrySchema,
  recipeSchema,
  type Feed,
  type GroceryItem,
  type LibraryExport,
  type MealPlanEntry,
  type Recipe,
  type RecipeView,
} from "@recipes/schema";
import { normalizeRecipe, webURL } from "../domain/normalize.js";
import { DocStore } from "./doc-store.js";
import { KeyedLock } from "./fsutil.js";
import { ImageStore } from "./image-store.js";
import type { z } from "zod";
import type { recipeInputSchema } from "@recipes/schema";

/** Folder names are the iCloud container's, so a library can be copied between iCloud and a server as is. */
export const LIBRARY_DIRS = {
  recipes: "Recipes",
  mealPlan: "Calendar",
  groceries: "Groceries",
  feeds: "Feeds",
  images: "Images",
  stepImages: "StepImages",
} as const;

const parser =
  <S extends z.ZodType>(schema: S) =>
  (raw: unknown): z.output<S> | null => {
    const result = schema.safeParse(raw);
    return result.success ? result.data : null;
  };

const parseRecipe = (raw: unknown): Recipe | null => {
  const result = recipeSchema.safeParse(raw);
  return result.success && result.data.title.trim() ? result.data : null;
};

export class Library {
  readonly recipes: DocStore<Recipe>;
  readonly mealPlan: DocStore<MealPlanEntry>;
  readonly groceries: DocStore<GroceryItem>;
  readonly feeds: DocStore<Feed>;
  readonly images: ImageStore;
  readonly stepImages: ImageStore;
  /** Serializes read-modify-write on one file, keyed `<folder>/<id>.json`; the sync endpoints take the same locks. */
  readonly lock = new KeyedLock();

  constructor(readonly root: string) {
    const dir = (name: string) => path.join(root, name);
    const keys = (schema: { shape: object }) => new Set(Object.keys(schema.shape));
    this.recipes = new DocStore(dir(LIBRARY_DIRS.recipes), parseRecipe, keys(recipeSchema));
    this.mealPlan = new DocStore(dir(LIBRARY_DIRS.mealPlan), parser(mealPlanEntrySchema), keys(mealPlanEntrySchema));
    this.groceries = new DocStore(dir(LIBRARY_DIRS.groceries), parser(groceryItemSchema), keys(groceryItemSchema));
    this.feeds = new DocStore(dir(LIBRARY_DIRS.feeds), parser(feedSchema), keys(feedSchema));
    this.images = new ImageStore(dir(LIBRARY_DIRS.images));
    this.stepImages = new ImageStore(dir(LIBRARY_DIRS.stepImages));
  }

  async init(): Promise<void> {
    await Promise.all(Object.values(LIBRARY_DIRS).map((name) => fs.mkdir(path.join(this.root, name), { recursive: true })));
  }

  /** Recipes sorted by title, each with the version of its photo (or null) for cache busting. */
  async listRecipeViews(): Promise<RecipeView[]> {
    const [recipes, stamps] = await Promise.all([this.recipes.list(), this.images.stamps()]);
    return recipes
      .sort((a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: "base" }))
      .map((recipe) => ({ ...recipe, imageVersion: stamps.get(recipe.id) ?? null }));
  }

  async recipeView(id: string): Promise<RecipeView | null> {
    const recipe = await this.recipes.get(id);
    if (!recipe) return null;
    return { ...recipe, imageVersion: (await this.images.stamps()).get(recipe.id) ?? null };
  }

  async saveRecipe(input: z.output<typeof recipeInputSchema>, id: string, now = new Date()): Promise<Recipe> {
    const existing = await this.recipes.get(id);
    const recipe = normalizeRecipe(input, id, existing, now);
    await this.recipes.put(recipe);
    const kept = new Set(recipe.stepImages.filter((image): image is string => image !== null));
    for (const old of existing?.stepImages ?? []) {
      if (old && !kept.has(old)) await this.stepImages.delete(old);
    }
    return recipe;
  }

  async deleteRecipe(id: string): Promise<boolean> {
    const recipe = await this.recipes.get(id);
    if (!recipe) return false;
    await this.recipes.delete(id);
    await this.images.delete(id);
    for (const image of recipe.stepImages) if (image) await this.stepImages.delete(image);
    return true;
  }

  async export(now = new Date()): Promise<LibraryExport> {
    const recipes = await this.recipes.list();
    const images: Record<string, string> = {};
    const stepImages: Record<string, string> = {};
    for (const recipe of recipes) {
      const photo = await this.images.read(recipe.id);
      if (photo) images[recipe.id] = photo.data.toString("base64");
      for (const id of recipe.stepImages) {
        if (!id) continue;
        const step = await this.stepImages.read(id);
        if (step) stepImages[id] = step.data.toString("base64");
      }
    }
    const byCreated = <T extends { createdAt: string }>(items: T[]) =>
      items.sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt));
    return {
      version: 1,
      exportedAt: isoDate(now),
      recipes: recipes.sort((a, b) => a.title.localeCompare(b.title)),
      mealPlan: (await this.mealPlan.list()).sort((a, b) => a.day.localeCompare(b.day)),
      groceries: byCreated(await this.groceries.list()),
      feeds: byCreated(await this.feeds.list()),
      images,
      stepImages,
    };
  }

  /** Writes everything in an export into this library; items with the same id are replaced, nothing is deleted. */
  async importExport(data: LibraryExport): Promise<Record<"recipes" | "mealPlan" | "groceries" | "feeds" | "images", number>> {
    for (const recipe of data.recipes) {
      if (!recipe.title.trim()) continue;
      await this.recipes.put({ ...recipe, sourceURL: webURL(recipe.sourceURL), imageURL: webURL(recipe.imageURL) });
    }
    for (const entry of data.mealPlan) await this.mealPlan.put(entry);
    for (const item of data.groceries) await this.groceries.put(item);
    for (const feed of data.feeds) await this.feeds.put(feed);
    let images = 0;
    for (const [store, photos] of [[this.images, data.images], [this.stepImages, data.stepImages]] as const) {
      for (const [id, base64] of Object.entries(photos)) {
        if (!isUUID(id)) continue;
        await store.write(id, Buffer.from(base64, "base64"));
        images += 1;
      }
    }
    return {
      recipes: data.recipes.filter((recipe) => recipe.title.trim()).length,
      mealPlan: data.mealPlan.length,
      groceries: data.groceries.length,
      feeds: data.feeds.length,
      images,
    };
  }
}
