import { useSyncExternalStore } from "react";
import type { Meal } from "./format.js";

export interface Prefs {
  ratingStyle: "favorites" | "stars";
  listStyle: "list" | "cards";
  weekStart: 0 | 1;
  defaultMeal: "automatic" | Meal;
  keepAwake: boolean;
}

const DEFAULTS: Prefs = { ratingStyle: "favorites", listStyle: "list", weekStart: 0, defaultMeal: "automatic", keepAwake: true };
const KEY = "recipes.prefs";

function read(): Prefs {
  try {
    return { ...DEFAULTS, ...(JSON.parse(localStorage.getItem(KEY) ?? "{}") as Partial<Prefs>) };
  } catch {
    return DEFAULTS;
  }
}

let current = read();
const listeners = new Set<() => void>();

export function setPref<K extends keyof Prefs>(key: K, value: Prefs[K]): void {
  current = { ...current, [key]: value };
  try {
    localStorage.setItem(KEY, JSON.stringify(current));
  } catch {
    /* private mode: keep it for this session */
  }
  listeners.forEach((listener) => listener());
}

export function usePrefs(): Prefs {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    () => current,
  );
}
