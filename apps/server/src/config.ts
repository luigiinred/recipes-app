import path from "node:path";
import { fileURLToPath } from "node:url";
import pkg from "../package.json" with { type: "json" };

export interface Config {
  port: number;
  host: string;
  /** The library folder: same layout as the iCloud container's Documents folder. */
  dataDir: string;
  /** Built web UI to serve, or null to run API-only. */
  webDir: string | null;
  /** Seeds the owner password on first start instead of the setup page. */
  password: string | null;
  trustProxy: boolean;
  allowPrivateImports: boolean;
  sessionDays: number;
  version: string;
}

const flag = (value: string | undefined): boolean => ["1", "true", "yes", "on"].includes((value ?? "").toLowerCase());

function integer(env: NodeJS.ProcessEnv, name: string, fallback: number): number {
  const raw = env[name];
  if (raw === undefined || raw === "") return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) throw new Error(`${name} must be a positive integer, got "${raw}"`);
  return value;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const builtWeb = fileURLToPath(new URL("../../web/dist", import.meta.url));
  return {
    port: integer(env, "PORT", 8080),
    host: env.HOST || "127.0.0.1",
    dataDir: path.resolve(env.DATA_DIR || "./data"),
    webDir: env.WEB_DIR === "none" ? null : path.resolve(env.WEB_DIR || builtWeb),
    password: env.RECIPES_PASSWORD || null,
    trustProxy: flag(env.TRUST_PROXY),
    allowPrivateImports: flag(env.ALLOW_PRIVATE_IMPORTS),
    sessionDays: integer(env, "SESSION_DAYS", 30),
    version: pkg.version,
  };
}
