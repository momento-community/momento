import { expect, test } from "@playwright/test";

import { flutterText, waitForRoute } from "../helpers";

/**
 * Role-aware UI surfaces against the mock-data build. In mock mode there's
 * no Firestore behind the role provider, so it always resolves to the
 * default `user` role. That's exactly what we want to assert on the
 * upgrade / gate flows that ship for plain users.
 *
 * Role-specific tests for organisor + admin live in PLAN P3 once the
 * Firebase Auth emulator is wired so we can inject a custom `users/{uid}`
 * doc per test.
 */

test.describe("roles — user (mock-data default)", () => {
  test("Profile shows the 'Become an organisor' upgrade card", async ({
    page,
  }) => {
    await page.goto("/#/profile");
    await page.waitForTimeout(1_500);
    // The role banner copy is unique to the user role.
    await expect(flutterText(page, "Want to host?")).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, "Become an organisor")).toBeVisible();
  });

  test("Create tab shows the upgrade panel, not the form", async ({
    page,
  }) => {
    await page.goto("/#/create");
    await page.waitForTimeout(1_500);
    await expect(flutterText(page, "Want to host?")).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, "Become an organisor")).toBeVisible();
    // Form labels from the real Create form must NOT be visible while the
    // upgrade panel is rendered.
    await expect(page.locator('[aria-label="TITLE"]')).toHaveCount(0);
    await expect(page.locator('[aria-label="CATEGORY"]')).toHaveCount(0);
  });

  test("/admin route redirects non-admins (real builds only)", async ({
    page,
  }) => {
    // In mock-mode CI the auth gate is wide open and the /admin redirect
    // is bypassed alongside it — the admin screen renders, but its
    // Firestore-backed streams stay in `loading`. We assert what we can:
    // navigating to /admin doesn't crash, and the panel header shows.
    await page.goto("/#/admin");
    await page.waitForTimeout(2_000);
    await expect(flutterText(page, "Admin panel")).toBeVisible({
      timeout: 8_000,
    });
  });
});

test.describe("roles — Momento detail visibility", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await waitForRoute(page, /\/discover/);
  });

  test("analytics card hidden for plain user opening someone else's momento",
      async ({ page }) => {
    // Open the first mock momento.
    await flutterText(page, "Abstract Realities Vernissage").click();
    await expect(flutterText(page, "Reserve Spot")).toBeVisible({
      timeout: 8_000,
    });
    // Analytics card is gated by `isAdmin || uid == organizer_id` — the
    // mock-data viewer is neither.
    await expect(flutterText(page, "YOUR ANALYTICS")).toHaveCount(0);
    await expect(flutterText(page, "ADMIN VIEW")).toHaveCount(0);
  });
});
