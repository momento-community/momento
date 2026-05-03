import type { Locator, Page } from "@playwright/test";

/**
 * Flutter web with CanvasKit renders text into the canvas, not the DOM. With
 * accessibility semantics enabled (see `lib/main.dart`), Flutter emits
 * `<flt-semantics>` elements whose `aria-label` carries the visible text.
 *
 * Important: Flutter often consolidates child text into one combined
 * accessible-name on a parent group — e.g. a Momento card surfaces as
 * `aria-label="ART Abstract Realities Vernissage Today · 6:00 PM 142 428"`
 * rather than separate per-text nodes. Default match is therefore substring
 * (`[aria-label*="..."]`); pass `{ exact: true }` for top-level chrome
 * widgets that have a clean, standalone aria-label.
 *
 * CSS attribute selectors are case-sensitive — useful here because the card
 * shows `ART` while the chip shows `Art`, so substring match for "Art" only
 * hits the chip even when both surfaces are in the DOM.
 */
export function flutterText(
  page: Page | Locator,
  text: string,
  opts: { exact?: boolean } = {},
): Locator {
  const safe = text.replace(/"/g, '\\"');
  const op = opts.exact ? "=" : "*=";
  return page.locator(`[aria-label${op}"${safe}"]`).first();
}

/**
 * Wait for Flutter's bootstrap sequence: the splash route finishes its 1.4s
 * timer and the next route mounts. CI machines can be slow on cold starts —
 * give it 12s by default and add a tiny settle for semantic-tree population.
 */
export async function waitForRoute(
  page: Page,
  routePattern: RegExp,
  timeout = 12_000,
): Promise<void> {
  await page.waitForURL(routePattern, { timeout });
  await page.waitForTimeout(400);
}
