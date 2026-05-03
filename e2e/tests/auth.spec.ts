import { expect, test } from "@playwright/test";

import * as S from "../selectors";

/**
 * Email-based sign up + sign in flow. Requires:
 *   - Firebase Auth Email/Password provider enabled (already done).
 *   - The dev hosted environment OR a local Firebase Auth emulator.
 *
 * Because tests against a live project create real users, we use a
 * timestamp-based email so each run produces a fresh account. Replace this
 * with the Firebase Auth emulator + cleanup hook when wiring P3 of the plan.
 */

const uniqueEmail = () =>
  `e2e+${Date.now().toString(36)}@momento.community`;

test.describe("email auth", () => {
  test("sign up flow lands on Discover", async ({ page }) => {
    await page.goto("/#/auth");
    // Tap "Continue with email" → bottom sheet.
    await page.getByText(S.auth.email).click();
    // Switch to "Sign up" tab.
    await page.getByText(S.auth.signUpTab).click();

    const email = uniqueEmail();
    await page
      .getByPlaceholder(S.auth.emailHint)
      .fill(email);
    await page.getByPlaceholder(S.auth.passwordHint).fill("MomentoTest1!");

    // Submit.
    await page.getByRole("button", { name: "Sign up" }).click();

    // Discover loads — wordmark and (initially empty) feed.
    await expect(page).toHaveURL(/\/discover/, { timeout: 15_000 });
    await expect(page.getByText(S.wordmark).first()).toBeVisible();
  });

  test("sign in with bad credentials shows error toast", async ({ page }) => {
    await page.goto("/#/auth");
    await page.getByText(S.auth.email).click();
    // Default tab is Sign in.
    await page
      .getByPlaceholder(S.auth.emailHint)
      .fill("nope@momento.community");
    await page.getByPlaceholder(S.auth.passwordHint).fill("definitely-wrong");
    await page.getByRole("button", { name: "Sign in" }).click();

    // Snackbar appears (any text from Firebase auth error).
    await expect(page.locator("text=/no.user|wrong|invalid/i")).toBeVisible({
      timeout: 5_000,
    });

    // Stays on auth.
    await expect(page).toHaveURL(/\/auth/);
  });
});
