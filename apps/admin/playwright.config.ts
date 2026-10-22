import { defineConfig } from "@playwright/test";
import path from "node:path";

export default defineConfig({
  testDir: "./e2e",
  testMatch: "**/*.e2e.ts",
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: "http://127.0.0.1:13000",
    channel: process.env.PLAYWRIGHT_CHANNEL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: [
    {
      command: ".venv/bin/python -m tests.browser_server",
      cwd: path.resolve(__dirname, "../../services/api"),
      url: "http://127.0.0.1:18080/api/v1/ready",
      timeout: 60_000,
      reuseExistingServer: false,
    },
    {
      command: "npm start",
      url: "http://127.0.0.1:13000/api/health",
      timeout: 60_000,
      reuseExistingServer: false,
      env: { MEDIEXPLAIN_API_URL: "http://127.0.0.1:18080/api/v1", ADMIN_COOKIE_SECURE: "false", HOSTNAME: "127.0.0.1", PORT: "13000" },
    },
  ],
});
