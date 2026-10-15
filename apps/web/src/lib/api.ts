import type {
  ApiToken,
  GroceryInput,
  GroceryItem,
  ImportResponse,
  LibraryExport,
  MealPlanEntry,
  MealPlanInput,
  RecipeInput,
  RecipePatch,
  RecipeView,
  SessionInfo,
} from "@recipes/schema";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export const AUTH_LOST = "recipes:auth-lost";

async function request<T>(method: string, url: string, body?: unknown, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  let payload: BodyInit | undefined;
  if (body instanceof Blob) {
    payload = body;
  } else if (body !== undefined) {
    headers.set("content-type", "application/json");
    payload = JSON.stringify(body);
  }
  let response: Response;
  try {
    response = await fetch(url, { ...init, method, headers, body: payload, credentials: "same-origin" });
  } catch {
    throw new ApiError(0, "Can't reach the server.");
  }
  if (!response.ok) {
    let message = `The server answered ${response.status}.`;
    try {
      const data = (await response.json()) as { error?: string };
      if (data.error) message = data.error;
    } catch {
      /* keep the generic message */
    }
    if (response.status === 401 && !url.startsWith("/api/login") && !url.startsWith("/api/session")) {
      window.dispatchEvent(new Event(AUTH_LOST));
    }
    throw new ApiError(response.status, message);
  }
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

export const api = {
  session: () => request<SessionInfo>("GET", "/api/session"),
  login: (password: string) => request<{ ok: true }>("POST", "/api/login", { password }),
  setup: (code: string, password: string) => request<{ ok: true }>("POST", "/api/setup", { code, password }),
  logout: () => request<{ ok: true }>("POST", "/api/logout", {}),
  changePassword: (current: string, next: string) => request<{ ok: true }>("POST", "/api/password", { current, next }),

  recipes: {
    listRaw: () => fetch("/api/recipes", { credentials: "same-origin" }),
    create: (recipe: RecipeInput) => request<RecipeView>("POST", "/api/recipes", recipe),
    update: (id: string, recipe: RecipeInput) => request<RecipeView>("PUT", `/api/recipes/${id}`, recipe),
    patch: (id: string, patch: RecipePatch) => request<RecipeView>("PATCH", `/api/recipes/${id}`, patch),
    remove: (id: string) => request<void>("DELETE", `/api/recipes/${id}`),
    putImage: (id: string, image: Blob) =>
      request<RecipeView>("PUT", `/api/recipes/${id}/image`, image, { headers: { "content-type": image.type || "image/jpeg" } }),
    removeImage: (id: string) => request<void>("DELETE", `/api/recipes/${id}/image`),
  },

  plan: {
    create: (entry: MealPlanInput) => request<MealPlanEntry>("POST", "/api/meal-plan", entry),
    update: (id: string, entry: MealPlanInput) => request<MealPlanEntry>("PUT", `/api/meal-plan/${id}`, entry),
    remove: (id: string) => request<void>("DELETE", `/api/meal-plan/${id}`),
  },

  groceries: {
    add: (items: GroceryInput[]) => request<GroceryItem[]>("POST", "/api/groceries", items),
    patch: (id: string, patch: Partial<Pick<GroceryItem, "name" | "quantity" | "isChecked">>) =>
      request<GroceryItem>("PATCH", `/api/groceries/${id}`, patch),
    remove: (id: string) => request<void>("DELETE", `/api/groceries/${id}`),
    clear: (scope: "completed" | "all") => request<{ removed: number }>("POST", "/api/groceries/clear", { scope }),
  },

  importUrl: (url: string) => request<ImportResponse>("POST", "/api/import", { url }),
  restore: (data: LibraryExport) =>
    request<Record<"recipes" | "mealPlan" | "groceries" | "feeds" | "images", number>>("POST", "/api/export/restore", data),

  tokens: {
    list: () => request<ApiToken[]>("GET", "/api/tokens"),
    create: (name: string) => request<{ token: string; info: ApiToken }>("POST", "/api/tokens", { name }),
    revoke: (id: string) => request<void>("DELETE", `/api/tokens/${id}`),
  },
};

export const recipeImageUrl = (recipe: Pick<RecipeView, "id" | "imageVersion">): string | null =>
  recipe.imageVersion === null ? null : `/api/recipes/${recipe.id}/image?v=${Math.round(recipe.imageVersion)}`;

export const stepImageUrl = (id: string): string => `/api/step-images/${id}`;
