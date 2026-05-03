import { expect, test } from "@playwright/test";

import { flutterText } from "../helpers";

/**
 * Map screen against the mock-data build. Until real Google Maps wires up,
 * markers are positioned widgets — we only assert the chrome elements.
 */

test.describe("map (mock-data)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/#/map");
    await page.waitForTimeout(2_000);
  });

  test("map screen has search bar + filter pill + Map/Grid toggle", async ({
    page,
  }) => {
    await expect(flutterText(page, "Search location…")).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, "Filters")).toBeVisible();
    await expect(flutterText(page, "Map")).toBeVisible();
    await expect(flutterText(page, "Grid")).toBeVisible();
  });

  test("Grid toggle navigates to /discover", async ({ page }) => {
    await flutterText(page, "Grid").click();
    await page.waitForURL(/\/discover/, { timeout: 8_000 });
  });

  test("Filters pill opens the shared filter sheet", async ({ page }) => {
    await flutterText(page, "Filters").click();
    await expect(flutterText(page, "Filter Momentos")).toBeVisible({
      timeout: 8_000,
    });
    await expect(flutterText(page, "CATEGORIES")).toBeVisible();
  });
});
