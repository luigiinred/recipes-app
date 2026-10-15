import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { logger } from "hono/logger";
import { HTTPException } from "hono/http-exception";
import { LoginLimiter, type AuthStore } from "./auth/auth-store.js";
import { requireAuth } from "./auth/middleware.js";
import type { Config } from "./config.js";
import { HttpError } from "./errors.js";
import { accountRoutes, publicAuthRoutes } from "./routes/auth.js";
import { groceryRoutes } from "./routes/groceries.js";
import { libraryRoutes } from "./routes/library.js";
import { planRoutes } from "./routes/plan.js";
import { recipeRoutes } from "./routes/recipes.js";
import { syncRoutes } from "./routes/sync.js";
import { serveWeb } from "./static.js";
import type { Library } from "./storage/library.js";
import type { SyncStore } from "./storage/sync-store.js";

export interface AppDeps {
  config: Config;
  library: Library;
  auth: AuthStore;
  sync: SyncStore;
  quiet?: boolean;
}

const UPLOAD_PATHS = /^\/api\/(recipes\/[^/]+\/image|export\/restore|sync\/files\/)/;

const CSP = [
  "default-src 'self'",
  "img-src 'self' data: blob:",
  "style-src 'self' 'unsafe-inline'",
  "frame-src https://www.youtube-nocookie.com",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
].join("; ");

export function createApp({ config, library, auth, sync, quiet }: AppDeps): Hono {
  const app = new Hono();
  const limiter = new LoginLimiter();

  if (!quiet) app.use(logger());

  app.use(async (c, next) => {
    await next();
    c.header("x-content-type-options", "nosniff");
    c.header("referrer-policy", "same-origin");
    c.header("x-frame-options", "DENY");
    if (!c.res.headers.has("content-security-policy") && c.res.headers.get("content-type")?.startsWith("text/html")) {
      c.header("content-security-policy", CSP);
    }
  });

  app.onError((error, c) => {
    if (error instanceof HttpError) {
      return c.json({ error: error.message, details: error.details }, error.status);
    }
    if (error instanceof HTTPException) return c.json({ error: error.message }, error.status);
    console.error(error);
    return c.json({ error: "Something went wrong on the server." }, 500);
  });

  const api = new Hono();
  // Uploads (signed-in only) set their own, larger limits; everything else, sign-in included, is small.
  const jsonLimit = bodyLimit({ maxSize: 2 * 1024 * 1024, onError: () => { throw new HttpError(413, "That request is too large."); } });
  api.use((c, next) => (UPLOAD_PATHS.test(c.req.path) ? next() : jsonLimit(c, next)));
  api.route("/", publicAuthRoutes(auth, config, limiter));
  api.use(requireAuth(auth, config));
  api.use(async (c, next) => {
    await next();
    if (!c.res.headers.has("cache-control")) c.header("cache-control", "no-store");
  });
  api.route("/", accountRoutes(auth, config, limiter));
  api.route("/", recipeRoutes(library));
  api.route("/", planRoutes(library));
  api.route("/", groceryRoutes(library));
  api.route("/", libraryRoutes(library, config.allowPrivateImports));
  api.route("/", syncRoutes(sync));
  app.route("/api", api);

  if (config.webDir) serveWeb(app, config.webDir);
  return app;
}
