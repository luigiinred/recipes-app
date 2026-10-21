import { z } from "zod";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isUUID = (value: string): boolean => UUID_RE.test(value);

/** Ids are lowercased everywhere; the iOS app writes them uppercase but reads either. */
export const uuidSchema = z
  .string()
  .regex(UUID_RE, "Expected a UUID")
  .transform((value) => value.toLowerCase());

const dateSchema = z
  .string()
  .refine((value) => !Number.isNaN(Date.parse(value)), "Expected an ISO 8601 date");

const nonNegativeInt = z.number().int().min(0);

export const ingredientSectionSchema = z.object({
  title: z.string(),
  start: nonNegativeInt,
});

export const timelineEventSchema = z.object({
  id: uuidSchema,
  date: dateSchema,
  note: z.string().default(""),
});

/** One recipe as stored in `Recipes/<id>.json`. Lenient like the Swift decoder: only `title` is required. */
export const recipeSchema = z.object({
  id: uuidSchema,
  title: z.string(),
  summary: z.string().default(""),
  servings: z.number().int().nullish(),
  prepMinutes: z.number().int().nullish(),
  cookMinutes: z.number().int().nullish(),
  ingredients: z.array(z.string()).default([]),
  ingredientSections: z.array(ingredientSectionSchema).default([]),
  steps: z.array(z.string()).default([]),
  stepTimestamps: z.array(z.number().int().nullable()).default([]),
  stepImages: z.array(uuidSchema.nullable()).default([]),
  tags: z.array(z.string()).default([]),
  sourceURL: z.string().nullish(),
  imageURL: z.string().nullish(),
  notes: z.string().default(""),
  isFavorite: z.boolean().default(false),
  rating: z.number().int().nullish(),
  wantToCook: z.boolean().default(false),
  queuedAt: dateSchema.nullish(),
  timeline: z.array(timelineEventSchema).default([]),
  createdAt: dateSchema,
  updatedAt: dateSchema,
});
export type Recipe = z.infer<typeof recipeSchema>;

/** A recipe as the web API returns it, with the version of its photo (null when it has none). */
export type RecipeView = Recipe & { imageVersion: number | null };

/** What a client may send to create or replace a recipe: ids and timestamps are the server's to fill in. */
export const recipeInputSchema = recipeSchema
  .extend({
    id: uuidSchema.optional(),
    createdAt: dateSchema.optional(),
    updatedAt: dateSchema.optional(),
    title: z.string().max(300),
    ingredients: z.array(z.string().max(1000)).max(500).default([]),
    steps: z.array(z.string().max(10_000)).max(500).default([]),
  })
  .refine((recipe) => recipe.title.trim().length > 0, { message: "A recipe needs a title.", path: ["title"] });
export type RecipeInput = z.input<typeof recipeInputSchema>;

export const recipePatchSchema = z
  .object({
    isFavorite: z.boolean(),
    rating: z.number().int().min(1).max(5).nullable(),
    wantToCook: z.boolean(),
    tags: z.array(z.string()),
    notes: z.string(),
  })
  .partial()
  .strict();
export type RecipePatch = z.infer<typeof recipePatchSchema>;

export const MEALS = ["breakfast", "lunch", "dinner", "snack"] as const;
export type Meal = (typeof MEALS)[number];
export const mealSchema = z.enum(MEALS);

export const dayKeySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD");

/** Plan entries, groceries and feeds are strict: the Swift decoder has no defaults for their fields. */
export const mealPlanEntrySchema = z.object({
  id: uuidSchema,
  recipeID: uuidSchema.nullish(),
  title: z.string(),
  day: dayKeySchema,
  meal: mealSchema,
  createdAt: dateSchema,
  updatedAt: dateSchema,
});
export type MealPlanEntry = z.infer<typeof mealPlanEntrySchema>;

export const mealPlanInputSchema = z.object({
  recipeID: uuidSchema.nullish(),
  /** Defaults to the recipe's title when a recipe is given. */
  title: z.string().trim().optional(),
  day: dayKeySchema,
  meal: mealSchema.default("dinner"),
});
export type MealPlanInput = z.input<typeof mealPlanInputSchema>;

export const groceryItemSchema = z.object({
  id: uuidSchema,
  name: z.string(),
  quantity: z.string(),
  isChecked: z.boolean(),
  recipeID: uuidSchema.nullish(),
  reminderID: z.string().nullish(),
  createdAt: dateSchema,
  updatedAt: dateSchema,
});
export type GroceryItem = z.infer<typeof groceryItemSchema>;

export const groceryInputSchema = z.object({
  name: z.string().trim().min(1),
  quantity: z.string().default(""),
  isChecked: z.boolean().default(false),
  recipeID: uuidSchema.nullish(),
});
export type GroceryInput = z.input<typeof groceryInputSchema>;

export const groceryPatchSchema = z
  .object({ name: z.string().trim().min(1), quantity: z.string(), isChecked: z.boolean() })
  .partial()
  .strict();

export const feedSchema = z.object({
  id: uuidSchema,
  url: z.string(),
  title: z.string(),
  createdAt: dateSchema,
});
export type Feed = z.infer<typeof feedSchema>;

export const feedInputSchema = z.object({ url: z.url(), title: z.string().trim().default("") });

/** Same document the iOS app's "Export all data" produces, so a library can move in either direction. */
export const libraryExportSchema = z.object({
  version: z.literal(1),
  exportedAt: dateSchema,
  recipes: z.array(recipeSchema),
  mealPlan: z.array(mealPlanEntrySchema),
  groceries: z.array(groceryItemSchema),
  feeds: z.array(feedSchema),
  images: z.record(z.string(), z.string()),
  stepImages: z.record(z.string(), z.string()).default({}),
});
export type LibraryExport = z.infer<typeof libraryExportSchema>;

export const importRequestSchema = z.object({ url: z.url() });

export interface ImportResponse {
  /** A recipe read from a web page, for the user to review before saving. */
  draft: RecipeInput;
  /** The cover photo as a data URL, when the page has one. */
  image: string | null;
}

export interface SessionInfo {
  authenticated: boolean;
  setupRequired: boolean;
  version: string;
}

export interface ApiToken {
  id: string;
  name: string;
  createdAt: string;
  lastUsedAt: string | null;
}

export interface SyncFileEntry {
  /** Library-relative path such as `Recipes/<id>.json`. */
  path: string;
  size: number;
  /** Hex SHA-256 of the file's bytes. */
  etag: string;
  /** Milliseconds since the epoch. */
  mtimeMs: number;
}

/** Serializes dates the way the iOS app does: ISO 8601 in UTC with whole seconds. */
export const isoDate = (date: Date = new Date()): string => date.toISOString().replace(/\.\d{3}Z$/, "Z");

export * from "./lib.js";
