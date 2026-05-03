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
    await page.getByRole("button", { name: "Filter" }).click();
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

    await page.getByRole("button", { name: "Filter" }).click();
    await expect(flutterText(page, "Filter Momentos")).toBeVisible();

    // CategoryChip's a11y name is exactly the chip label.
    await page.getByRole("button", { name: "Art", exact: true }).click();
    await page.getByRole("button", { name: "Apply Filters" }).click();

    // The Music card uses category badge "MUSIC" (caps); CSS substring match
    // is case-sensitive so this filter actually removes the row.
    await expect(
      page.locator('[aria-label*="Blue Note Jazz Session"]'),
    ).toHaveCount(0, { timeout: 8_000 });
    await expect(
      flutterText(page, "Abstract Realities Vernissage"),
    ).toBeVisible();
  });

  test("reset clears all filter selections", async ({ page }) => {
    await page.getByRole("button", { name: "Filter" }).click();
    await page.getByRole("button", { name: "Music", exact: true }).click();
    await page.getByRole("button", { name: "Reset" }).click();
    await page.getByRole("button", { name: "Apply Filters" }).click();

    await expect(
      flutterText(page, "Blue Note Jazz Session"),
    ).toBeVisible({ timeout: 10_000 });
  });
});
