import type { GroceryItem, MealPlanEntry, RecipeView } from "@recipes/schema";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { ApiError } from "./api.js";

interface LibraryState {
  recipes: RecipeView[];
  plan: MealPlanEntry[];
  groceries: GroceryItem[];
  loaded: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  /** Replaces one recipe with the server's copy, without waiting for the next refresh. */
  adopt: (recipe: RecipeView) => void;
  setGroceries: (update: (items: GroceryItem[]) => GroceryItem[]) => void;
  recipe: (id: string | null | undefined) => RecipeView | undefined;
}

const Context = createContext<LibraryState | null>(null);

export function useLibrary(): LibraryState {
  const value = useContext(Context);
  if (!value) throw new Error("useLibrary outside LibraryProvider");
  return value;
}

const REFRESH_MS = 15_000;

async function fetchText(url: string): Promise<string> {
  const response = await fetch(url, { credentials: "same-origin" });
  if (!response.ok) throw new ApiError(response.status, `The server answered ${response.status}.`);
  return response.text();
}

/** Keeps the whole library in memory; it refreshes on focus and every few seconds so edits from the apps show up. */
export function LibraryProvider({ children, onSignedOut }: { children: ReactNode; onSignedOut: () => void }) {
  const [recipes, setRecipes] = useState<RecipeView[]>([]);
  const [plan, setPlan] = useState<MealPlanEntry[]>([]);
  const [groceries, setGroceriesState] = useState<GroceryItem[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const seen = useRef({ recipes: "", plan: "", groceries: "" });

  const refresh = useCallback(async () => {
    try {
      const [r, p, g] = await Promise.all([fetchText("/api/recipes"), fetchText("/api/meal-plan"), fetchText("/api/groceries")]);
      if (r !== seen.current.recipes) {
        seen.current.recipes = r;
        setRecipes(JSON.parse(r) as RecipeView[]);
      }
      if (p !== seen.current.plan) {
        seen.current.plan = p;
        setPlan(JSON.parse(p) as MealPlanEntry[]);
      }
      if (g !== seen.current.groceries) {
        seen.current.groceries = g;
        setGroceriesState(JSON.parse(g) as GroceryItem[]);
      }
      setLoaded(true);
      setError(null);
    } catch (caught) {
      if (caught instanceof ApiError && caught.status === 401) onSignedOut();
      else setError(caught instanceof Error ? caught.message : "Couldn't load your library.");
    }
  }, [onSignedOut]);

  useEffect(() => {
    void refresh();
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible") void refresh();
    }, REFRESH_MS);
    const onFocus = () => void refresh();
    window.addEventListener("focus", onFocus);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener("focus", onFocus);
    };
  }, [refresh]);

  const adopt = useCallback((recipe: RecipeView) => {
    seen.current.recipes = "";
    setRecipes((list) => {
      const index = list.findIndex((item) => item.id === recipe.id);
      if (index < 0) return [...list, recipe].sort((a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: "base" }));
      const next = [...list];
      next[index] = recipe;
      return next;
    });
  }, []);

  const setGroceries = useCallback((update: (items: GroceryItem[]) => GroceryItem[]) => {
    seen.current.groceries = "";
    setGroceriesState(update);
  }, []);

  const byId = useMemo(() => new Map(recipes.map((recipe) => [recipe.id, recipe])), [recipes]);
  const recipe = useCallback((id: string | null | undefined) => (id ? byId.get(id) : undefined), [byId]);

  const value = useMemo(
    () => ({ recipes, plan, groceries, loaded, error, refresh, adopt, setGroceries, recipe }),
    [recipes, plan, groceries, loaded, error, refresh, adopt, setGroceries, recipe],
  );
  return <Context.Provider value={value}>{children}</Context.Provider>;
}
