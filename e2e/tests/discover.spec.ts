import { expect, test } from "@playwright/test";

import { flutterText, waitForRoute } from "../helpers";

/**
 * Discover masonry against the mock-data build. The mock fixture in
 * `lib/core/mock/mock_momentos.dart` ships 12 Momentos with deterministic
 * titles, so we can assert by text without seeded Firestore state.
 */

const KNOWN_TITLES = [
  "Abstract Realities Vernissage",
  "Organic Saturday Market",
  "Blue Note Jazz Session",
  "Sunrise Vinyasa Flow",
];

test.describe("discover (mock-data)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await waitForRoute(page, /\/discover/);
  });

  test("masonry renders multiple known mock cards", async ({ page }) => {
    for (const title of KNOWN_TITLES) {
      await expect(flutterText(page, title)).toBeVisible({ timeout: 10_000 });
    }
  });

  test("tap a card opens the slide-up detail", async ({ page }) => {
    await flutterText(page, KNOWN_TITLES[0]).click();
    await expect(flutterText(page, "Reserve Spot")).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, "Studio Ō")).toBeVisible();
  });

  test("organizer card pushes to organizer detail", async ({ page }) => {
    await flutterText(page, KNOWN_TITLES[0]).click();
    await expect(flutterText(page, "Studio Ō")).toBeVisible({
      timeout: 8_000,
    });
    await flutterText(page, "Studio Ō").click();
    // Organizer detail header has the active-count line + Message button.
    // We use `flutterText` (which falls back to getByText) instead of a
    // raw aria-label selector — the unified ProfileScreen renders this
    // text as DOM content rather than a merged parent-group aria-label,
    // which the raw locator misses. Substring match keeps the assertion
    // robust to "1 active Momento" vs "5 active Momentos".
    await expect(flutterText(page, "active Momento")).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, "Message")).toBeVisible();
  });
});
