import { cpSync, existsSync } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const standalone = path.resolve(".next/standalone");
if (!existsSync(path.join(standalone, "server.js"))) {
  console.error("Build the admin application with npm run build before npm start.");
  process.exit(1);
}
cpSync(".next/static", path.join(standalone, ".next/static"), { recursive: true });
if (existsSync("public")) cpSync("public", path.join(standalone, "public"), { recursive: true });
process.env.HOSTNAME ||= "127.0.0.1";
process.env.PORT ||= "3000";
await import(pathToFileURL(path.join(standalone, "server.js")).href);
