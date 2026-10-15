import type { ApiToken, SessionInfo } from "@recipes/schema";
import { Hono } from "hono";
import { deleteCookie, getCookie, setCookie } from "hono/cookie";
import { z } from "zod";
import { AuthStore, LoginLimiter, MIN_PASSWORD_LENGTH } from "../auth/auth-store.js";
import { clientAddress, isSecureRequest, SESSION_COOKIE } from "../auth/middleware.js";
import type { Config } from "../config.js";
import { HttpError } from "../errors.js";
import { jsonBody } from "../http.js";

const password = z.string().min(MIN_PASSWORD_LENGTH, `Use at least ${MIN_PASSWORD_LENGTH} characters.`).max(256);
const setupSchema = z.object({ code: z.string(), password });
const loginSchema = z.object({ password: z.string().max(256) });
const changePasswordSchema = z.object({ current: z.string().max(256), next: password });
const tokenSchema = z.object({ name: z.string().trim().min(1).max(80) });

/** Routes anyone may call: they are how a person gets signed in. */
export function publicAuthRoutes(auth: AuthStore, config: Config, limiter: LoginLimiter): Hono {
  const app = new Hono();

  const startSession = (c: Parameters<typeof setCookie>[0]) => {
    const session = auth.createSession(config.sessionDays);
    setCookie(c, SESSION_COOKIE, session.value, {
      httpOnly: true,
      sameSite: "Lax",
      secure: isSecureRequest(c, config),
      path: "/",
      maxAge: session.maxAgeSeconds,
    });
  };

  app.get("/health", (c) => c.json({ ok: true }));

  app.get("/session", (c) => {
    const info: SessionInfo = {
      authenticated: auth.verifySession(getCookie(c, SESSION_COOKIE)),
      setupRequired: auth.setupRequired,
      version: config.version,
    };
    return c.json(info);
  });

  app.post("/setup", async (c) => {
    const key = clientAddress(c, config);
    if (!auth.setupRequired) throw new HttpError(409, "This server is already set up.");
    if (!limiter.attempt(key)) throw new HttpError(429, "Too many attempts. Try again later.");
    const body = await jsonBody(c, setupSchema);
    if (!auth.checkSetupCode(body.code)) {
      throw new HttpError(403, "That setup code isn't right. It's printed in the server log and saved in the data folder.");
    }
    await auth.setPassword(body.password);
    limiter.succeed(key);
    startSession(c);
    return c.json({ ok: true });
  });

  app.post("/login", async (c) => {
    const key = clientAddress(c, config);
    if (!limiter.attempt(key)) throw new HttpError(429, "Too many attempts. Try again later.");
    const body = await jsonBody(c, loginSchema);
    if (auth.setupRequired || !(await auth.checkPassword(body.password))) {
      throw new HttpError(401, "Wrong password.");
    }
    limiter.succeed(key);
    startSession(c);
    return c.json({ ok: true });
  });

  app.post("/logout", (c) => {
    deleteCookie(c, SESSION_COOKIE, { path: "/" });
    return c.json({ ok: true });
  });

  return app;
}

/** Account management, behind sign-in. */
export function accountRoutes(auth: AuthStore, config: Config, limiter: LoginLimiter): Hono {
  const app = new Hono();

  app.post("/password", async (c) => {
    const key = clientAddress(c, config);
    if (!limiter.attempt(key)) throw new HttpError(429, "Too many attempts. Try again later.");
    const body = await jsonBody(c, changePasswordSchema);
    if (!(await auth.checkPassword(body.current))) {
      throw new HttpError(403, "The current password isn't right.");
    }
    limiter.succeed(key);
    await auth.setPassword(body.next);
    // Changing the password signs every browser out, this one included, so start a fresh session.
    const session = auth.createSession(config.sessionDays);
    setCookie(c, SESSION_COOKIE, session.value, {
      httpOnly: true, sameSite: "Lax", secure: isSecureRequest(c, config), path: "/", maxAge: session.maxAgeSeconds,
    });
    return c.json({ ok: true });
  });

  app.get("/tokens", (c) => c.json(auth.listTokens()));

  app.post("/tokens", async (c) => {
    const { name } = await jsonBody(c, tokenSchema);
    const { token, info } = await auth.createToken(name);
    const body: { token: string; info: ApiToken } = { token, info };
    return c.json(body, 201);
  });

  app.delete("/tokens/:id", async (c) => {
    if (!(await auth.revokeToken(c.req.param("id")))) throw new HttpError(404, "No such token.");
    return c.body(null, 204);
  });

  return app;
}
