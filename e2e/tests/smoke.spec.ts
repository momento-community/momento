import { expect, test } from "@playwright/test";

import { flutterText, waitForRoute } from "../helpers";
import * as S from "../selectors";

/**
 * Smoke against a build with `--dart-define=USE_MOCK_DATA=true`. In that
 * mode the splash routes directly to /discover (no auth gate, no Firebase
 * traffic). Tests that exercise the real auth flow live in `auth.spec.ts`
 * and require either the live project or a Firebase Auth emulator.
 */

test.describe("smoke (mock-data build)", () => {
  test("app boots and reaches /discover", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });

    await page.goto("/");
    await waitForRoute(page, /\/discover/);

    // Wordmark is in Flutter's semantic DOM tree.
    await expect(flutterText(page, S.wordmark)).toBeVisible({
      timeout: 8_000,
    });

    // Surface fatal errors but ignore CanvasKit/init noise.
    const fatal = errors.filter(
      (e) =>
        !/canvaskit|fontconfig|google-fonts|favicon|chrome-extension/i.test(e),
    );
    expect(fatal, `console errors:\n${fatal.join("\n")}`).toEqual([]);
  });

  test("auth screen reachable directly", async ({ page }) => {
    await page.goto("/#/auth");
    await page.waitForTimeout(1_500);
    await expect(flutterText(page, S.auth.heading)).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, S.auth.google)).toBeVisible();
    await expect(flutterText(page, S.auth.email)).toBeVisible();
  });
});
