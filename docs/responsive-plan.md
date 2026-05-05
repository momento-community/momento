# Responsive design plan

Status: Phase 1 + Phase 2 + Phase 3 (Discover two-pane) shipped. The two remaining Phase 3 niceties — MomentoDetail 2-column body and Map split-pane — kept on the back burner for v2 polish.

## 0. Diagnosis

Symptoms across desktop screenshots:
- Cards too wide (single column on a 1920px viewport, or 2 cols × ~900px-wide).
- Full-bleed CTAs ("Become an organisor" green pill stretches edge to edge).
- Stats spread across full viewport (`0 / 0 / 1.2k` with hundreds of px gap).
- Bottom nav lingers on desktop where a side rail belongs.

Root cause: no max-content-width primitive. Every body just `Padding`s to viewport edges and the masonry hardcodes `crossAxisCount: 2` regardless of screen width.

Bonus issues caught during review (fixing alongside):
- `Organised` (My Moments) vs `Created Momentos` (Profile) — same data, different copy.
- Stale-SW cache showing fake `1.2k` followers — clears on hard refresh.
- Map `RefererNotAllowedMapError` — user-side GCP referrer config (must include `https://momento.community/*`, scheme included for some browsers).

## 1. Breakpoints — single source of truth

`lib/config/breakpoints.dart`:

```dart
class Breakpoints {
  static const double tablet  = 720;   // 600 felt cramped
  static const double desktop = 1080;
  static const double wide    = 1440;
}
```

Why these specific values: 600 (Material default) is too narrow — at 600 px you still want a single-column reading layout. 720 is the "side-by-side feels comfortable" line. 1080 is where 3-col masonry starts breathing. 1440 reserves a hook for two-pane (Phase 3).

## 2. Shared primitive — `ResponsiveContent`

`lib/core/widgets/responsive_content.dart`:

```dart
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  });
  // Center > ConstrainedBox > Padding > child
}
```

Three flavours by intent:
- **560** — auth, create form, sticky reserve bar (focused-input width)
- **720** — Profile, MyMoments, MomentoDetail body (reading width)
- **1080** — Discover masonry, OrganizerDetail (gallery width)

## 3. Adaptive masonry helper

`adaptiveCols(double width)` returns `2 | 3 | 4` based on the *constrained* width (not viewport — important because Profile masonry is inside a 720 column even on a 4K screen, so it should stay 2-col).

Wrap masonry call sites in `LayoutBuilder` and pass `constraints.maxWidth`.

## 4. Phase 1 — per-screen wiring

Done in this PR. **Zero new behaviour, just centering.** Fixes ~80 % of the symptoms.

| Screen | Wrap | Notes |
|---|---|---|
| `discover_screen.dart` | 1080 | Adaptive cols via `LayoutBuilder` |
| `profile_screen.dart` | 720 | Per-sliver wrap so the scrollable stays viewport-wide |
| `my_moments_screen.dart` | 720 | Plus rename `Organised` → `Created Momentos` |
| `create_screen.dart` | 560 | Form + Become-an-organiser CTA |
| `momento_detail_screen.dart` | 720 body / 560 sticky bar | Hero stays full-bleed |
| `organizer_detail_screen.dart` | 1080 | Adaptive masonry |
| `auth_screen.dart` | 480 | Wordmark + buttons |
| `splash_screen.dart` | 480 | |
| `onboarding_screen.dart` | 480 | |
| `admin_screen.dart` | 1080 | |
| `map_screen.dart` | n/a (map full-bleed) | Top chrome wrapped at 720 |
| `filter_bottom_sheet.dart` | 560 | Cap modal width |

## 5. Phase 2 — NavigationRail (≥ tablet) — DONE

`MainShell` switches between `BottomNavigationBar` (mobile) and `NavigationRail` (≥ 720 px) based on `context.isMobile` from the breakpoint extension.

- Bottom nav: unchanged on mobile (centre Ō badge denotes My Moments).
- NavigationRail: 5 destinations. Leading slot shows **OBadge** (collapsed) or **MOMENTŌ wordmark** (extended) as branding; My Moments uses a regular bookmark icon in the rail (the centre-Ō treatment lives only in the bottom nav).
- The rail is **collapsed** (icon only) below 1080, **extended** (icon + text labels) at ≥ 1080.
- Selected destination uses the primary tint + a soft pill indicator.

**Caveat surfaced during e2e:** Flutter Web paints NavigationRail destination labels and the leading wordmark to canvas without queryable semantics, so DOM-level text assertions for rail copy are flaky. We instead test geometry signals — first-card column count and X-offset — which capture the same outcome reliably. See `e2e/tests/responsive.spec.ts`.

**Viewport sizing for tests:** the desktop project is 1440 (not 1280) so that with the extended rail (~220 px), the remaining content width still clears the 1080 breakpoint and the masonry flips to 3 cols. A 1280 viewport leaves only ~1060 px of content area — *just below* the breakpoint.

## 6. Phase 3 — deferred

Documented for v2 reference; not building now:
- Two-pane on `≥wide` (1440+): list left, detail right. Slide-up modal becomes a side panel.
- Wider hero on MomentoDetail desktop: 2-column hero + meta on left, description + CTA right.
- Map: split-pane with cards strip + map.

## 7. Tests

Add to a follow-up commit (after Phase 1 lands so we're testing the new geometry):
- `e2e/playwright.config.ts`: add tablet project (1024 × 768).
- `e2e/tests/responsive.spec.ts`:
  - At desktop viewport: assert ≥3 columns visible on Discover (group MomentoCard aria-labels by Y, count distinct X-bands).
  - At desktop: assert main content sits inside a max-1080 box (snapshot the masonry's bounding rect; expect width ≤ 1080).
  - At tablet: assert exactly 2 cols on Discover.

## 8. Decisions — recorded

1. **Phase 2 → NavigationRail** ✅
2. **Phase 3 → defer** ✅
3. **Plan committed as `docs/responsive-plan.md`** ✅
4. **Phase 1 alone first**, then pause for review ✅
