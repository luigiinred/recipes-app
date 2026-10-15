import type { Context, MiddlewareHandler } from "hono";
import { getCookie } from "hono/cookie";
import { getConnInfo } from "@hono/node-server/conninfo";
import type { Config } from "../config.js";
import { HttpError } from "../errors.js";
import type { AuthStore } from "./auth-store.js";

export const SESSION_COOKIE = "recipes_session";

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

let warnedAboutProxy = false;

export function clientAddress(c: Context, config: Config): string {
  if (!config.trustProxy && !warnedAboutProxy && c.req.header("x-forwarded-for")) {
    warnedAboutProxy = true;
    console.warn("Requests carry X-Forwarded-For but TRUST_PROXY is off: every client shares the proxy's address for rate limiting, and cookies won't be marked Secure. Set TRUST_PROXY=true if a reverse proxy is in front.");
  }
  if (config.trustProxy) {
    // The last entry is the one our own proxy appended; earlier ones are whatever the client claimed.
    const forwarded = c.req.header("x-forwarded-for")?.split(",").at(-1)?.trim();
    if (forwarded) return forwarded;
  }
  try {
    return getConnInfo(c).remote.address ?? "unknown";
  } catch {
    return "unknown";
  }
}

export function isSecureRequest(c: Context, config: Config): boolean {
  if (config.trustProxy && c.req.header("x-forwarded-proto")?.split(",")[0]?.trim() === "https") return true;
  return new URL(c.req.url).protocol === "https:";
}

/** Browsers attach cookies to cross-site requests; a state-changing one must come from this server's own pages. */
function fromOwnPages(c: Context, config: Config): boolean {
  const site = c.req.header("sec-fetch-site");
  if (site && site !== "same-origin" && site !== "none") return false;
  const origin = c.req.header("origin");
  if (!origin) return true;
  const host = (config.trustProxy ? c.req.header("x-forwarded-host") : undefined) ?? c.req.header("host");
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}

export function requireAuth(auth: AuthStore, config: Config): MiddlewareHandler {
  return async (c, next) => {
    const header = c.req.header("authorization");
    const bearer = header?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (bearer) {
      if (!auth.verifyToken(bearer.trim())) throw new HttpError(401, "That token isn't valid.");
      return next();
    }
    if (auth.verifySession(getCookie(c, SESSION_COOKIE))) {
      if (!SAFE_METHODS.has(c.req.method) && !fromOwnPages(c, config)) throw new HttpError(403, "Cross-site request blocked.");
      return next();
    }
    throw new HttpError(401, "Sign in required.");
  };
}
