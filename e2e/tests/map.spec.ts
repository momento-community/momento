import { expect, test } from "@playwright/test";

/**
 * Map screen against the mock-data build. Until real Google Maps wires up,
 * markers are positioned widgets — we don't assert exact pixel positions,
 * just that the chrome and at least one marker exist.
 */

test.describe("map (mock-data)", () => {
  test("map screen has search bar + filter pill + Map/Grid toggle", async ({
    page,
  }) => {
    await page.goto("/#/map");
    await page.waitForTimeout(1_500);

    await expect(page.getByText("Search location…")).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.getByText("Filters")).toBeVisible();
    await expect(page.getByText("Map", { exact: true })).toBeVisible();
    await expect(page.getByText("Grid", { exact: true })).toBeVisible();
  });

  test("Grid toggle navigates to /discover", async ({ page }) => {
    await page.goto("/#/map");
    await page.waitForTimeout(1_500);
    await page.getByText("Grid", { exact: true }).click();
    await page.waitForURL(/\/discover/, { timeout: 5_000 });
  });

  test("Filters pill opens the shared filter sheet", async ({ page }) => {
    await page.goto("/#/map");
    await page.waitForTimeout(1_500);
    await page.getByText("Filters").click();
    await expect(page.getByText("Filter Momentos")).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.getByText("CATEGORIES")).toBeVisible();
  });
});
