import { tagIsIn } from "./categories.js";
import type { Recipe } from "./index.js";

export const COLLECTIONS = ["all", "recent", "up-next", "favorites", "top-rated", "uncategorized"] as const;
export type CollectionId = (typeof COLLECTIONS)[number];

export const collectionTitles: Record<CollectionId, string> = {
  all: "All Recipes",
  recent: "Most Recent",
  "up-next": "Up Next",
  favorites: "Favorites",
  "top-rated": "Top Rated",
  uncategorized: "Uncategorized",
};

type Dated = Pick<Recipe, "createdAt" | "queuedAt">;
const time = (value: string | null | undefined, fallback = 0): number => {
  const parsed = value ? Date.parse(value) : NaN;
  return Number.isNaN(parsed) ? fallback : parsed;
};

export function filterCollection<R extends Recipe>(recipes: R[], collection: CollectionId): R[] {
  switch (collection) {
    case "all":
      return recipes;
    case "recent":
      return [...recipes].sort((a, b) => time(b.createdAt) - time(a.createdAt)).slice(0, 20);
    case "up-next":
      return recipes
        .filter((recipe) => recipe.wantToCook)
        .sort((a, b) => queuedTime(a) - queuedTime(b));
    case "favorites":
      return recipes.filter((recipe) => recipe.isFavorite);
    case "top-rated":
      return recipes.filter((recipe) => (recipe.rating ?? 0) >= 4).sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0));
    case "uncategorized":
      return recipes.filter((recipe) => recipe.tags.length === 0);
  }
}

export const queuedTime = (recipe: Dated): number => time(recipe.queuedAt, time(recipe.createdAt));

export function filterCategory<R extends Recipe>(recipes: R[], category: string): R[] {
  return recipes.filter((recipe) => recipe.tags.some((tag) => tagIsIn(tag, category)));
}

/** Something to cook that has no recipe yet, like "Spaghetti" or "Leftovers": a title and maybe notes. */
export const isIdea = (recipe: Pick<Recipe, "ingredients" | "steps">): boolean => recipe.ingredients.length === 0 && recipe.steps.length === 0;

/** Every word of the query must appear somewhere in the title, summary, notes, ingredients or tags. */
export function recipeMatches(recipe: Recipe, query: string): boolean {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (words.length === 0) return true;
  const haystack = [recipe.title, recipe.summary, recipe.notes, ...recipe.ingredients, ...recipe.tags].join("\n").toLowerCase();
  return words.every((word) => haystack.includes(word));
}
