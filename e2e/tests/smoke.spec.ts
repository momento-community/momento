import { expect, test } from "@playwright/test";

import * as S from "../selectors";

test.describe("smoke", () => {
  test("app boots without console errors", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });

    await page.goto("/");
    await expect(page).toHaveTitle(/Momentō|momento/i);

    // Splash → Onboarding → Auth all show the wordmark.
    await expect(page.getByText(S.wordmark).first()).toBeVisible({
      timeout: 15_000,
    });

    // Soft-fail on console errors so we still get the report.
    expect(errors, `console errors: ${errors.join("\n")}`).toEqual([]);
  });

  test("onboarding flows to auth", async ({ page }) => {
    await page.goto("/");
    // Wait for splash timer (1.4s) → onboarding mount.
    await page.waitForTimeout(2_000);

    // Tap Next 3 times (or once + Get started on slide 3).
    for (let i = 0; i < 3; i++) {
      const next = page.getByText(S.onboarding.next).or(
        page.getByText(S.onboarding.getStarted),
      );
      await expect(next.first()).toBeVisible();
      await next.first().click();
      await page.waitForTimeout(300);
    }

    // Auth screen should now be visible.
    await expect(page.getByText(S.auth.heading)).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.getByText(S.auth.google)).toBeVisible();
    await expect(page.getByText(S.auth.apple)).toBeVisible();
    await expect(page.getByText(S.auth.email)).toBeVisible();
  });

  test("auth-gated route redirects to /auth when signed out", async ({
    page,
  }) => {
    await page.goto("/#/discover");
    await page.waitForTimeout(1_500);
    // Should land on /auth.
    await expect(page).toHaveURL(/\/auth/);
    await expect(page.getByText(S.auth.heading)).toBeVisible();
  });
});
