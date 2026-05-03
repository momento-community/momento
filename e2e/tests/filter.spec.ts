import { expect, test } from "@playwright/test";

import * as S from "../selectors";

/**
 * Filter bottom sheet against the mock-data build. The fixture has Momentos
 * across all 12 categories — toggling "Art" should narrow the feed to the
 * Art-only Momentos (Abstract Realities Vernissage, Pottery Workshop).
 */

test.describe("filter (mock-data)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await page.waitForURL(/\/discover/, { timeout: 8_000 });
  });

  test("opens the filter sheet from the tune icon", async ({ page }) => {
    await page.getByRole("button", { name: S.discover.filterTooltip }).click();
    await expect(page.getByText(S.filter.sheetTitle)).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.getByText("CATEGORIES")).toBeVisible();
    await expect(page.getByText("DISTANCE")).toBeVisible();
    await expect(page.getByText("TIME RANGE")).toBeVisible();
    await expect(page.getByText("SORT BY")).toBeVisible();
  });

  test("toggling a category narrows the feed", async ({ page }) => {
    // Pre-condition: Music + Art Momentos both visible.
    await expect(page.getByText("Blue Note Jazz Session")).toBeVisible();
    await expect(
      page.getByText("Abstract Realities Vernissage"),
    ).toBeVisible();

    await page.getByRole("button", { name: S.discover.filterTooltip }).click();
    await expect(page.getByText(S.filter.sheetTitle)).toBeVisible();

    // Tap "Art" chip inside the sheet (the chip text is unique within sheet).
    await page.getByText("Art", { exact: true }).click();
    await page.getByRole("button", { name: S.filter.apply }).click();

    // Music Momentos should be gone, Art Momentos should remain.
    await expect(page.getByText("Blue Note Jazz Session")).toHaveCount(0, {
      timeout: 5_000,
    });
    await expect(
      page.getByText("Abstract Realities Vernissage").first(),
    ).toBeVisible();
  });

  test("reset clears all filter selections", async ({ page }) => {
    await page.getByRole("button", { name: S.discover.filterTooltip }).click();
    await page.getByText("Music", { exact: true }).click();
    await page.getByRole("button", { name: S.filter.reset }).click();
    await page.getByRole("button", { name: S.filter.apply }).click();

    // Both Art and Music are back.
    await expect(page.getByText("Blue Note Jazz Session")).toBeVisible({
      timeout: 5_000,
    });
    await expect(
      page.getByText("Abstract Realities Vernissage").first(),
    ).toBeVisible();
  });
});
