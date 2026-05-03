import type { Locator, Page } from "@playwright/test";

/**
 * Flutter web with CanvasKit renders text into the canvas, not the DOM. With
 * accessibility semantics enabled (see `lib/main.dart`), Flutter creates
 * `<flt-semantics>` elements with an `aria-label` attribute carrying the
 * visible text. Some widgets also expose the text as DOM content. This
 * helper tries both so tests don't need to know which path was taken.
 */
export function flutterText(page: Page | Locator, text: string): Locator {
  // Escape double quotes for the attribute selector.
  const safe = text.replace(/"/g, '\\"');
  return page
    .locator(`[aria-label="${safe}"]`)
    .or(page.getByText(text, { exact: true }))
    .first();
}

/**
 * Wait for Flutter's bootstrap sequence: the splash route finishes its 1.4s
 * timer and the next route mounts. CI machines can be slow on cold starts —
 * give it 12s by default.
 */
export async function waitForRoute(
  page: Page,
  routePattern: RegExp,
  timeout = 12_000,
): Promise<void> {
  await page.waitForURL(routePattern, { timeout });
  // Tiny settle so semantic nodes finish populating after the page change.
  await page.waitForTimeout(400);
}
