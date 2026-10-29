import { mkdirSync } from "node:fs";

// A grain's /var starts empty, and WBO requires its history directory to exist.
mkdirSync("/var/wbo_data", { recursive: true });
mkdirSync("/var/home", { recursive: true });

// WBO resolves its web root and default history path from the working directory.
process.chdir("/opt/app/whitebophir");

const [{ createServerApp }, config] = await Promise.all([
  import("/opt/app/whitebophir/server/server.mjs"),
  import("/opt/app/whitebophir/server/configuration.mjs"),
]);

try {
  await createServerApp(config, { installShutdownHandlers: true });
} catch (error) {
  console.error("WBO failed to start", error);
  process.exit(1);
}
