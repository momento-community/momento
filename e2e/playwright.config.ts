import { defineConfig, devices } from "@playwright/test";

const BASE_URL = process.env.BASE_URL ?? "http://localhost:8080";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ["list"],
    ["html", { open: "never" }],
  ],
  use: {
    baseURL: BASE_URL,
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      // iPhone 14 Pro frame is the design canvas (393×852). The default
      // `devices["iPhone 14 Pro"]` preset uses WebKit; we override to
      // Chromium so the same browser binary covers both projects (smaller
      // CI install, no Safari-specific quirks for now).
      name: "iphone-14-pro-viewport",
      use: {
        browserName: "chromium",
        viewport: { width: 393, height: 852 },
        deviceScaleFactor: 3,
        isMobile: true,
        hasTouch: true,
      },
    },
    {
      // 1024×768 sits between Breakpoints.tablet (720) and
      // Breakpoints.desktop (1080), so this project exercises the
      // collapsed-NavigationRail variant (icons only, no labels).
      name: "tablet-viewport",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1024, height: 768 },
      },
    },
    {
      // 1440 wide so that with the extended NavigationRail (~220 px) the
      // remaining content width still clears Breakpoints.desktop (1080)
      // and the Discover masonry flips to 3-col. Anything narrower than
      // ~1300 lets the rail eat the desktop breakpoint.
      name: "chromium-desktop",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1440, height: 900 },
      },
    },
    {
      // ≥ Breakpoints.ultrawide (1600) → two-pane Discover layout.
      // 1920 leaves comfortable room on both sides of the split.
      name: "chromium-ultrawide",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1920, height: 1080 },
      },
    },
  ],
});
