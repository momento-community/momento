import { expect, test } from "@playwright/test";

import { flutterText } from "../helpers";
import * as S from "../selectors";

/**
 * Profile-screen copy lock-in. The rename from "My Momentos" → "Created
 * Momentos" was an intentional UX call to make the contrast with "Liked"
 * unmistakable, so we pin it via e2e to catch any future accidental
 * regression. Stats row copy ("Created / Liked / Followers") is locked
 * for the same reason.
 *
 * Mock-mode auth bypass means /profile renders with `user?.email == null`,
 * which the screen handles by falling back to "Momento member". That's
 * why we don't assert any user-specific name here.
 */

test.describe("profile — labels (mock-data)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/#/profile");
    await page.waitForTimeout(1_500);
  });

  test("tab labels read 'Created Momentos' and 'Liked'", async ({ page }) => {
    await expect(flutterText(page, S.profile.createdTab)).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, S.profile.likedTab)).toBeVisible();
  });

  test("stats row reads Created / Liked / Followers", async ({ page }) => {
    await expect(flutterText(page, S.profile.createdStat)).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, S.profile.likedTab)).toBeVisible();
    await expect(flutterText(page, S.profile.followersStat)).toBeVisible();
  });

  test("freemium card renders", async ({ page }) => {
    await expect(flutterText(page, S.profile.freemiumHeading)).toBeVisible({
      timeout: 8_000,
    });
    // The Logout link sits at the very bottom of the Profile sliver,
    // off-viewport on phone layouts. Flutter's internal scrollable
    // doesn't react reliably to `page.mouse.wheel`, so we don't assert
    // it here — the auth-emulator suite (PLAN P3) covers the sign-out
    // round-trip end-to-end.
  });
});
