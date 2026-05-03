import { expect, test } from "@playwright/test";

import * as S from "../selectors";

/**
 * Smoke against a build with `--dart-define=USE_MOCK_DATA=true`. In that
 * mode the splash routes directly to /discover (no auth gate, no Firebase
 * traffic). Tests that exercise the real auth flow live in `auth.spec.ts`
 * and require either the live project or a Firebase Auth emulator.
 */

test.describe("smoke (mock-data build)", () => {
  test("app boots without console errors", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });

    await page.goto("/");
    await expect(page).toHaveTitle(/Momentō|momento/i);

    // Splash → Discover should mount within ~3s.
    await expect(page.getByText(S.wordmark).first()).toBeVisible({
      timeout: 15_000,
    });

    // Surface the errors but don't fail on Flutter-internal warnings (often
    // fonts / canvas-kit init that don't break the app).
    const fatal = errors.filter(
      (e) => !/canvaskit|fontconfig|google-fonts/i.test(e),
    );
    expect(fatal, `console errors: ${fatal.join("\n")}`).toEqual([]);
  });

  test("splash routes to discover within 3s", async ({ page }) => {
    await page.goto("/");
    await page.waitForURL(/\/discover/, { timeout: 5_000 });
    await expect(page.getByText(S.wordmark).first()).toBeVisible();
  });

  test("auth screen still reachable directly", async ({ page }) => {
    await page.goto("/#/auth");
    await expect(page.getByText(S.auth.heading)).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.getByText(S.auth.google)).toBeVisible();
    await expect(page.getByText(S.auth.apple)).toBeVisible();
    await expect(page.getByText(S.auth.email)).toBeVisible();
  });
});
