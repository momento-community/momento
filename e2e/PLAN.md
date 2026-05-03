# Playwright e2e plan — Momentō

End-to-end smoke + flow tests against the running Flutter web build, using
Playwright's Chromium engine. Designed to catch regressions in the user-facing
flows that `flutter analyze` and unit tests can't.

## Tech choices

| Concern | Decision | Why |
|---|---|---|
| Runner | `@playwright/test` | Standard, parallel, retries, traces |
| Language | TypeScript | Best ecosystem support, autocomplete on selectors |
| Browsers | Chromium only (v1) | Matches "test in chrome browser" requirement; can fan out later |
| App target | Local `flutter run -d chrome` *or* deployed `momento-b23c0.web.app` | Both supported via `BASE_URL` env var |
| Auth strategy | Firebase Auth emulator + storage state | Hermetic, fast, no live-account churn |
| Data | Mock-data dart-define **or** Firestore emulator | Hermetic; the mock path skips Firebase entirely for pure UI tests |
| CI | GitHub Actions on PR + push to main | Same workflow as deploys |

## Test selector strategy

Flutter web renders the canvas/HTML hybrid — text-based selectors via
`getByText` work for visible labels, but tap-targets often have no
deterministic CSS. We add `Semantics(label: …)` wrappers on key widgets and
target via Playwright's `getByLabel` / `getByRole`. Pattern:

```dart
Semantics(
  label: 'discover_card_${momento.id}',
  button: true,
  child: MomentoCard(...),
)
```

Selectors live in `e2e/selectors.ts` so refactors only touch one file.

## Test buckets

### 1. Smoke (`smoke.spec.ts`)
- App boots without console errors
- Splash → Onboarding renders within 5s
- Onboarding → 3 slides via Next button → Auth screen
- Auth screen has all 3 social buttons + segmented Sign-in/Sign-up

### 2. Auth (`auth.spec.ts`)
- Email sign-up: switches to Sign-up tab, fills form, submits, lands on `/discover`
- Email sign-in: with seeded test user, lands on `/discover`
- Sign-out from Profile redirects to `/auth`
- Auth-gated route redirect: hitting `/discover` while signed out → `/auth`

### 3. Discover (`discover.spec.ts`) — needs seeded data
- Masonry renders ≥ 12 cards
- Tap card → slide-up Momento detail visible (assert title text)
- Back button dismisses
- Swipe-down (Playwright `mouse.down`/`up`) dismisses
- Filter icon → bottom sheet appears
- Toggle a category in sheet → Apply → feed filtered (assert subset)
- "Now ▾" pill opens date picker (just assert dialog opens)

### 4. Filter sheet (`filter.spec.ts`)
- All 12 category chips render
- Distance slider min/max bounds (0.5 / 50 km)
- Sort segmented control changes selection
- Reset clears all selections
- Apply persists state across navigations (Discover → Map → back)

### 5. Map (`map.spec.ts`)
- Map placeholder renders + ≥ 5 sage markers visible
- Tap marker → compact card appears at bottom
- Tap "Grid" toggle → `/discover`
- Tap "Filters" pill → bottom sheet (same as Discover)

### 6. Create (`create.spec.ts`)
- Empty form publish → validation toast
- Fill all required + skip photo → publish succeeds → toast + nav back to Discover
- Freemium counter (in Profile) increments by 1
- After 5 successful creates, button switches to "Pay & Publish — coming soon" and tapping it shows the v2 toast (no actual Stripe call)

### 7. My Moments + Profile (`account.spec.ts`)
- My Moments default tab is Organised → list renders
- Switch to Liked → masonry renders
- Profile shows display name derived from email
- Freemium card progress matches `freemium_used / 5`
- Edit Profile button visible
- Logout link triggers sign-out

### 8. Visual regression (optional, `visual.spec.ts`)
- Screenshot diff on each main screen at iPhone 14 Pro frame (390×844)
- Tolerates 0.1% pixel diff
- Baselines committed under `e2e/__screenshots__/`

## Test scaffold

```
e2e/
├── PLAN.md                   # this doc
├── package.json              # @playwright/test
├── playwright.config.ts      # baseURL, projects, retries, traces
├── tsconfig.json
├── selectors.ts              # all data-test / semantics labels
├── fixtures/
│   ├── auth.ts               # creates test user, returns storageState
│   └── seed.ts               # batch-writes mock momentos via Firestore emulator
├── tests/
│   ├── smoke.spec.ts
│   ├── auth.spec.ts
│   ├── discover.spec.ts
│   ├── filter.spec.ts
│   ├── map.spec.ts
│   ├── create.spec.ts
│   ├── account.spec.ts
│   └── visual.spec.ts
└── README.md
```

## Run modes

| Mode | Command | Use case |
|---|---|---|
| Local against running dev server | `BASE_URL=http://localhost:8080 npm run test` | Day-to-day dev — start `flutter run -d web-server --web-port 8080` first |
| Local against built artifacts | `npm run test:built` | Mirrors prod; runs `flutter build web` then serves `build/web` |
| Against deployed env | `BASE_URL=https://momento-b23c0.web.app npm run test` | Post-deploy smoke |
| Headed for debugging | `npm run test:headed` | Visual inspection |
| Single test, debugger | `npx playwright test smoke.spec.ts --debug` | Step through |

## CI integration

`.github/workflows/e2e.yml`:
- On PR + push to main
- Spin up Firebase emulators, build web with `--dart-define=USE_MOCK_DATA=false`
- Serve `build/web` via `npx http-server` on port 8080
- `npx playwright test`
- Upload `playwright-report/` and `test-results/` as artifacts on failure

## Phases

| Phase | Scope | Time estimate |
|---|---|---|
| **P1** | Scaffold + smoke + auth (no emulator) | 2-3h |
| **P2** | Discover + filter + map (with seeded mock-data run mode) | 2-3h |
| **P3** | Create + account, Firebase emulator wiring | 3-4h |
| **P4** | Visual regression baselines + CI workflow | 1-2h |

P1 ships first — covers the "is the app even loading" smoke + the auth flow,
which are the highest-value tests.
