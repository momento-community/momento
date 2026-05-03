import { expect, test } from "@playwright/test";

import * as S from "../selectors";

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
    await page.waitForURL(/\/discover/, { timeout: 8_000 });
  });

  test("masonry renders multiple known mock cards", async ({ page }) => {
    for (const title of KNOWN_TITLES) {
      await expect(page.getByText(title).first()).toBeVisible({
        timeout: 6_000,
      });
    }
  });

  test("tap a card opens the slide-up detail", async ({ page }) => {
    const card = page.getByText(KNOWN_TITLES[0]).first();
    await card.click();
    // Detail screen renders the full title + sticky reserve CTA.
    await expect(page.getByText("Reserve Spot")).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.getByText("Studio Ō")).toBeVisible();
    // Back button dismisses.
    await page.getByRole("button").first().click();
    await expect(page.getByText(KNOWN_TITLES[1]).first()).toBeVisible({
      timeout: 5_000,
    });
  });

  test("organizer card on detail pushes to organizer detail", async ({
    page,
  }) => {
    await page.getByText(KNOWN_TITLES[0]).first().click();
    await expect(page.getByText("Studio Ō")).toBeVisible();
    await page.getByText("Studio Ō").click();
    // Organizer detail header shows the count and Follow / Message buttons.
    await expect(page.getByText(/\d+ active Momento/)).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.getByText("Message")).toBeVisible();
  });
});
