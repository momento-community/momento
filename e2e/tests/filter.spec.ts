import { expect, test } from "@playwright/test";

import { flutterText, waitForRoute } from "../helpers";

/**
 * Filter bottom sheet against the mock-data build. The fixture has Momentos
 * across all 12 categories — toggling "Art" should narrow the feed.
 */

test.describe("filter (mock-data)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await waitForRoute(page, /\/discover/);
  });

  test("opens the filter sheet from the tune icon", async ({ page }) => {
    // The tune icon is in an IconButton with tooltip 'Filter'. In Flutter
    // semantics that's exposed as aria-label="Filter".
    await page.locator('[aria-label="Filter"]').first().click();
    await expect(flutterText(page, "Filter Momentos")).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, "CATEGORIES")).toBeVisible();
    await expect(flutterText(page, "DISTANCE")).toBeVisible();
    await expect(flutterText(page, "TIME RANGE")).toBeVisible();
    await expect(flutterText(page, "SORT BY")).toBeVisible();
  });

  test("toggling a category narrows the feed", async ({ page }) => {
    await expect(
      flutterText(page, "Blue Note Jazz Session"),
    ).toBeVisible({ timeout: 10_000 });

    await page.locator('[aria-label="Filter"]').first().click();
    await expect(flutterText(page, "Filter Momentos")).toBeVisible();

    // Tap the "Art" chip inside the sheet.
    await flutterText(page, "Art").click();
    await flutterText(page, "Apply Filters").click();

    await expect(
      page.locator('[aria-label="Blue Note Jazz Session"]'),
    ).toHaveCount(0, { timeout: 8_000 });
    await expect(
      flutterText(page, "Abstract Realities Vernissage"),
    ).toBeVisible();
  });

  test("reset clears all filter selections", async ({ page }) => {
    await page.locator('[aria-label="Filter"]').first().click();
    await flutterText(page, "Music").click();
    await flutterText(page, "Reset").click();
    await flutterText(page, "Apply Filters").click();

    await expect(
      flutterText(page, "Blue Note Jazz Session"),
    ).toBeVisible({ timeout: 10_000 });
  });
});
