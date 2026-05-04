import { expect, test } from "@playwright/test";

import { flutterText, waitForRoute } from "../helpers";
import * as S from "../selectors";

/**
 * Social-graph UI presence — Like (heart) and Follow buttons. Mock-mode
 * runs against an unauthenticated client (no Firebase Auth instance), so:
 *
 *   - **LikeButton**: visible regardless of auth state — renders the heart
 *     with a Semantics label, just disables `onTap` when signed out. We
 *     can assert the label is present on cards + detail screen.
 *   - **FollowButton**: hides itself when `me == null` (you can't follow
 *     anyone without a user id). Presence tests for it live in P3 once
 *     the Firebase Auth emulator is wired in.
 */

const FIRST_TITLE = "Abstract Realities Vernissage";

test.describe("social — likes (mock-data)", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await waitForRoute(page, /\/discover/);
  });

  test("heart overlay renders on Discover cards", async ({ page }) => {
    // 12 mock momentos × one heart each = at least 12 like-buttons in the
    // semantics tree. We assert "≥ 1" for resilience against off-screen
    // virtualization, but the masonry currently mounts them all.
    //
    // `<flt-semantics>` nodes have a zero-size bounding rect — Playwright's
    // `toBeVisible()` rejects them. Use `toBeAttached()` for DOM-presence.
    //
    // Selector is a SUBSTRING match: Flutter merges the LikeButton's
    // Tooltip-derived label into its containing card group, so the
    // resulting `aria-label` is e.g.
    // "Like Momento\nART\nAbstract Realities…\nToday · 6 PM\n142\n428".
    const hearts = page.locator(`[aria-label*="${S.social.likeIdle}"]`);
    await expect(hearts.first()).toBeAttached({ timeout: 10_000 });
    // ≥1 (mock fixture has 12, but iPhone-portrait masonry virtualizes
    // off-screen rows; on parallel CI workers fewer may be mounted at the
    // moment we sample).
    expect(await hearts.count()).toBeGreaterThanOrEqual(1);
  });

  test("heart appears in Momento detail action row", async ({ page }) => {
    await flutterText(page, FIRST_TITLE).click();
    await expect(flutterText(page, "Reserve Spot")).toBeVisible({
      timeout: 8_000,
    });
    const hearts = page.locator(`[aria-label*="${S.social.likeIdle}"]`);
    await expect(hearts.first()).toBeAttached({ timeout: 8_000 });
  });
});
