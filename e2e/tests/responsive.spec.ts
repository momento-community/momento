import { expect, test } from "@playwright/test";

import { waitForRoute } from "../helpers";

/**
 * Adaptive-layout assertions for Phase 2.
 *
 * What we actually test (and why):
 *
 *   * **Masonry column count.** This is the meaningful user-visible
 *     outcome of `adaptiveCols(constrained-width)` and the rail eating
 *     into available width. We measure first-row card count by grouping
 *     bounding rects.
 *
 *   * **Content X-offset.** When the rail is rendered (≥ tablet) the
 *     first card sits noticeably to the right of the viewport's left
 *     edge — that's the rail's footprint. On mobile the first card
 *     starts close to the left edge.
 *
 * What we deliberately don't test:
 *
 *   * NavigationRail destination labels ("Discover", "My Moments", …)
 *     and the leading wordmark are painted to canvas without
 *     queryable semantics in Flutter Web's CanvasKit, so DOM-level text
 *     assertions are unreliable. The geometry signals above cover the
 *     same ground without flake.
 */

async function readCardRects(page: import("@playwright/test").Page) {
  await page.goto("/");
  await waitForRoute(page, /\/discover/);
  await page.waitForTimeout(2_500);
  return page.evaluate(() => {
    return Array.from(
      document.querySelectorAll('[aria-label*="Like Momento"]'),
    )
      .map((e) => (e as HTMLElement).getBoundingClientRect())
      .filter((r) => r.width > 0)
      .sort((a, b) => a.top - b.top || a.left - b.left);
  });
}

function firstRowCount(rects: DOMRect[]): number {
  if (rects.length === 0) return 0;
  const firstTop = rects[0].top;
  return rects.filter((r) => Math.abs(r.top - firstTop) < 20).length;
}

test.describe("responsive — Discover masonry", () => {
  test("mobile (< 720) ⇒ 2 cols, content near left edge", async ({
    page,
    viewport,
  }) => {
    test.skip((viewport?.width ?? 0) >= 720, "mobile-only");
    const rects = await readCardRects(page);
    expect(firstRowCount(rects)).toBe(2);
    // No rail → first card starts close to left (just card padding).
    expect(rects[0].left).toBeLessThan(40);
  });

  test("tablet (720 ≤ w < 1080) ⇒ 2 cols, content shifted by rail", async ({
    page,
    viewport,
  }) => {
    const w = viewport?.width ?? 0;
    test.skip(w < 720 || w >= 1080, "tablet-only");
    const rects = await readCardRects(page);
    expect(firstRowCount(rects)).toBe(2);
    // Collapsed rail is ~80 px — first card starts after it.
    expect(rects[0].left).toBeGreaterThan(60);
  });

  test("desktop (≥ 1080 effective) ⇒ ≥ 3 cols, content shifted by extended rail",
      async ({ page, viewport }) => {
    test.skip((viewport?.width ?? 0) < 1080, "desktop-only");
    const rects = await readCardRects(page);
    expect(firstRowCount(rects)).toBeGreaterThanOrEqual(3);
    // Extended rail is ~220 px — first card starts well after it.
    expect(rects[0].left).toBeGreaterThan(180);
  });
});
