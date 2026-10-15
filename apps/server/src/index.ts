import { serve } from "@hono/node-server";
import { createApp } from "./app.js";
import { AuthStore } from "./auth/auth-store.js";
import { loadConfig } from "./config.js";
import { Library } from "./storage/library.js";
import { SyncStore } from "./storage/sync-store.js";

const config = loadConfig();
const library = new Library(config.dataDir);
await library.init();
const auth = new AuthStore(config.dataDir);
await auth.init(config.password);
const app = createApp({ config, library, auth, sync: new SyncStore(config.dataDir, library.lock) });

const server = serve({ fetch: app.fetch, port: config.port, hostname: config.host }, (info) => {
  console.log(`Recipes server ${config.version} listening on http://${info.address}:${info.port}`);
  console.log(`Library: ${config.dataDir}`);
  console.log(config.webDir ? `Web UI: ${config.webDir}` : "Web UI: disabled");
  const code = auth.pendingSetupCode;
  if (code) {
    console.log("");
    console.log(`First run: open the web UI and enter setup code ${code} to choose your password.`);
    console.log("(Or set RECIPES_PASSWORD and restart.)");
  }
});

const shutdown = () => server.close(() => process.exit(0));
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
