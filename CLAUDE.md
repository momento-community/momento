# CLAUDE.md — Momentō

Project context for future sessions. Keep lean.

## What it is

**Momentō** (always with the macron Ō) — a Pinterest-style local event discovery app. Events are **Momentos**. Tagline: "Find what's happening around you, right now." A separate prod Firebase project will split off before public launch.

## Locked identifiers

| | |
|---|---|
| Bundle / applicationId | `community.momento.app` |
| Domain | `momento.community` |
| Support email | `info@momento.community` |
| GitHub | `momento-community/momento` |
| Firebase project | `momento-b23c0` |
| Storage bucket | `gs://momento-b23c0.firebasestorage.app` |
| GCP / Firebase account | `info@momento.community` |
| Functions region | `europe-west1` |

## Stack

Flutter 3.38+ · Riverpod 3 (`Notifier` API) · `go_router` · Firebase Auth/Firestore/Storage · `google_maps_flutter` + `geoflutterfire_plus` · `flutter_staggered_grid_view` · `cached_network_image`. **No** Cloud Functions in v1, **no** Stripe yet (freemium gate stubbed).

## Brand & design rules

- Always render **Momentō** with the macron `Ō` (U+014C) literal — code, copy, UI. Events are always **Momentos** (no "events", no "flares").
- Lucide / Material outlined icons only. **No emoji. No gradients.**
- Cards: 16px radius, 1px `divider` border, `sm` shadow. Buttons: white-bg/charcoal-border default; max one filled `primary` per screen. Inputs: `surface` bg, 12px radius.
- **No visible scrollbars** — `MaterialApp.router` uses a custom `_NoScrollbarBehavior` in [`lib/app.dart`](lib/app.dart) that overrides `buildScrollbar` to return the child as-is. Scrollables still scroll (touch + wheel) but never paint a track. If you re-introduce scrollbars later (e.g. for desktop power users), do it on the specific Scrollable, not globally.
- Theme tokens in [`lib/config/theme.dart`](lib/config/theme.dart) — **never** inline hex.
- Test on iPhone 14 Pro (393×852 in Playwright). Web responsive: adaptive 2 / 3 / 4 cols at tablet (≥720) / desktop (≥1080) / wide (≥1440); two-pane Discover at ultrawide (≥1600). Full plan in [`docs/responsive-plan.md`](docs/responsive-plan.md).

## Key files

- `lib/config/{env,theme,router,breakpoints}.dart` — config, design tokens, go_router with role + auth redirects + `/momento/:id` + `/u/:id` deep links, responsive breakpoints
- `lib/core/firebase/providers.dart` — Riverpod providers + role/freemium derivations + `momentoByIdProvider` + `userDocByIdProvider` + `canEditMomento` helper
- `lib/core/repositories/` — `MomentoRepository` (`updateMomento`, `watchById`), `UserRepository` (`updateProfile` with denormalised fan-out), `StorageRepository`, `AuditLogRepository`, `FollowRepository`, `OrganisorRequestsRepository` (submit / approve / reject for the organisor approval flow). All Firestore writes go through here.
- `lib/core/services/place_search_service.dart` — Photon (OpenStreetMap) autocomplete for location search; CORS-friendly + free + no API key. Used by `lib/features/create/location_search_sheet.dart` (Create flow) and Momento detail's `_editLocation`.
- `lib/features/momento_detail/{momento_detail_screen,momento_detail_route}.dart` — detail UI (with inline-edit affordances) + deep-link wrapper
- `lib/features/profile/profile_screen.dart` — unified profile (self via `/profile`, any user via `/u/:id`)
- `lib/features/organizer/organizer_detail_screen.dart` — only the `Momento.pushOrganizerDetail` extension; the old standalone screen is gone
- `lib/core/widgets/{momento_logo,momento_button,slide_up_route,like_button,follow_button,responsive_content}.dart`
- `lib/core/seeds/demo_seed.dart` — admin-gated demo data flow
- `lib/shared/filter_state.dart` — shared filter state for Discover + Map
- `firestore.rules` · `firestore.indexes.json` · `storage.rules` · `storage.cors.json`
- `docs/{design-export,roles-plan,responsive-plan}.md`
- `.github/workflows/{deploy-hosting,deploy-rules,flutter-test,e2e,webhook-test}.yml`

## Routes

| Route | Shell? | Notes |
|---|---|---|
| `/splash`, `/onboarding`, `/auth` | no | gate |
| `/discover`, `/map`, `/my-moments`, `/create`, `/profile` | yes | bottom-nav / NavigationRail tabs |
| **`/u/:id`** | no | any user's profile — canonical share URL |
| **`/momento/:id`** | no | any momento detail — canonical share URL |
| `/admin` | no | admin-only (redirect to `/discover` for non-admins) |

In-app navigation uses these URL routes wherever an entity has an id (organizer cards push `/u/:id`, momento Share copies `<origin>/#/momento/:id`). The two-pane Discover layout is the one intentional exception — it keeps the URL on `/discover` and renders the selected momento in-place via `selectedMomentoIdProvider`. Tabs (`/discover` etc.) carry no id since they're a feed, not an entity.

## User roles

| Role | Capabilities |
|---|---|
| **user** | read + like + follow |
| **organisor** | + create / edit / delete own + analytics on own |
| **admin** | + edit / delete *any* + admin panel + manage roles + ban/unban |

Default `user` on signup. `user → organisor` is **admin-curated** via the Requests tab in `/admin` (see "Becoming an organisor" below). `organisor → user` (stop hosting) is self-allowed. Other transitions are admin-only. Banned users keep read access but lose every write (rule-enforced via `is_banned`).

**Bootstrap admin:** Firebase Console → Firestore → `users/{uid}` → set `role` = `"admin"`. Full plan: [`docs/roles-plan.md`](docs/roles-plan.md).

**Becoming an organisor — admin-curated:** plain users do NOT self-promote. Profile / Create show a "Request to host" CTA → writes `organisor_requests/{uid}` with `status: pending`. Admin reviews via the Admin panel's **Requests** tab and clicks Approve (atomic batch: `request.status = approved` + `users/{uid}.role = organisor`) or Reject (with optional reason shown to the applicant). Doc id == requesting user's uid, so re-applying after rejection just rewrites the same doc back to pending. Firestore rule for `users/{uid}` only allows the `organisor → user` self-transition (stop hosting); `user → organisor` is admin-only.

**Admin panel** (`/admin`, five tabs): **Momentos** (delete, audited) · **Users** (role dropdown + ban toggle, both audited) · **Requests** (Approve / Reject organisor applications, audited) · **Audit log** (append-only) · **Stats**.

**Audit log** lives in `audit_log/{id}` (append-only, admin-read-only). Action codes: `momento.delete`, `momento.edit`, `user.role_change`, `user.ban`, `user.unban`, `organisor_request.approve`, `organisor_request.reject`. Schema in [`audit_log_repository.dart`](lib/core/repositories/audit_log_repository.dart). Owner self-edits/deletes are NOT logged — only admin actions on someone else's record.

## Architecture decisions

- **No Cloud Functions in v1.** Race window for create-conflicts is tiny; rules + transactions cover ownership/freemium. Re-add as a callable if duplicates surface.
- `autoExpire` replaced by `where('end_datetime', '>', now())`. `onMomentoLikeChange` replaced by transaction-bumped `like_count` inside `toggleLike`.
- **Likes** — heart on every card (top-right overlay) + detail screen. State is `momento.likedBy.contains(uid)`; toggle is a transaction on the momento doc (`liked_by` arrayUnion/Remove + `like_count` increment). Optimistic UI in `LikeButton` for instant feedback.
- **Inline edit (Momento)** — owner + admin (gated by `canEditMomento` in [`providers.dart`](lib/core/firebase/providers.dart)) get pencil affordances next to title/description/dates/location and a chip for category, plus an "Edit photo" pill on the hero. Edits land via `MomentoRepository.updateMomento` (partial patch + optional Storage re-upload). The detail screen watches `momentoByIdProvider(id)` so writes reflect immediately. Admin edits on someone else's Momento append a `momento.edit` audit log entry; owner self-edits don't.
- **Inline edit (Profile)** — display_name / city / bio are tap-to-edit pencils on Profile; avatar is tap-to-upload (camera badge bottom-right of the ring). Display reads from `users/{uid}` via `currentUserDocProvider` (Firestore is the source of truth — Auth fields are only fallbacks for the brief window before `ensureUserDoc` lands the doc). Avatar bytes go to `users/{uid}/avatar.jpg` via `StorageRepository.uploadAvatar`, then the URL is patched into `avatar_url`. The Firestore rule for `users/{uid}` already allows partial updates that don't touch `is_premium` / `is_banned` / `role` — no rule changes needed.
- **Profile fan-out** — `UserRepository.updateProfile` watches for `display_name` / `avatar_url` in the patch and, when present, batch-updates `organizer_name` / `organizer_avatar_url` on every Momento where `organizer_id == uid`. Single batched `WriteBatch` chunked at 450 ops to stay under Firestore's 500-write batch limit. Bio / city / role / freemium patches skip the fan-out (the denormalised fields aren't affected). Without this, edits to your name or photo would only show on **new** Momentos — old ones would keep displaying the snapshot baked in at create time. Tested in [`test/repositories/user_repository_test.dart`](test/repositories/user_repository_test.dart).
- **Unified profile (`/profile` + `/u/:id`)** — one `ProfileScreen(userId)` widget powers both the bottom-nav tab (self) and the deep-link route (any user). `userId == null` or `userId == auth.uid` → self mode (inline edits, role card, freemium, dev seed, logout). Other uid → `_OtherProfileBody` (read-only header + Follow + Message + their active Momentos). Reads the live `users/{uid}` doc via `userDocByIdProvider` — falls back to denormalised fields on a hosted Momento when the doc errors (mock-data builds, transient blips, deleted accounts) so the screen always renders something useful. The old standalone `OrganizerDetailScreen` is gone; the `Momento.pushOrganizerDetail` extension does `Navigator.push(slideUpRoute(ProfileScreen(userId: id)))` for in-app taps (mixing `context.push` here with the Navigator-pushed Momento detail confuses go_router's page list). The `/u/:id` go_router route stays as the canonical share URL for incoming links.
- **Removed in May 2026**: view count on Momentos (`view_count` field, `incrementViewCount`, eye-icon stats, "Total views" admin tile, the related Firestore rule clauses) — not a metric we want to optimise for. Organizer card on Momento detail also flipped from "{N} likes" to "{N} followers" via `followerCountProvider`, so the card reflects the social graph not the per-Momento heart count.
- **Security + perf hardening (May 2026)**:
  - **URL launches are scheme-restricted**: organizer-controlled URLs (event website / IG / Eventbrite / other ticket) are filtered to `http`/`https` with a non-empty host before `launchUrl`. Closes a stored-XSS vector via `javascript:` / `data:` URIs. See `_open` in [`momento_detail_screen.dart`](lib/features/momento_detail/momento_detail_screen.dart).
  - **Storage uploads are MIME-allowlisted**: `isImage()` in [`storage.rules`](storage.rules) accepts `image/jpeg` / `image/png` / `image/webp` only — no more `image/svg+xml` (SVGs can carry script tags).
  - **Storage paths are exact-shape**: `users/{uid}/avatar.jpg` and `momentos/{organizerUid}/{momentoId}/{filename}` — replaced the prior `{allPaths=**}` globs that allowed arbitrary nesting under user/organizer scope.
  - **Audit-log field allowlist**: [`audit_log_repository.dart`](lib/core/repositories/audit_log_repository.dart) silently drops keys outside `_allowedDiffFields`. Defends against careless callers leaking PII into the permanent log. Add new keys deliberately as new audit codes land.
  - **Admin streams are bounded**: `MomentoRepository.watchAll` and `UserRepository.watchAllUsers` cap at 100 newest by default. Switch to cursor pagination if the panel needs to surface older records.
  - **`MomentoCard` images use `memCacheWidth`/`memCacheHeight`** sized to ~300 logical pixels × DPR. Without this, masonry holds the source-resolution bitmap (often 2400px from cover-photo upload) for every visible card.
  - **`followerCountProvider` is a `FutureProvider` using Firestore `count()` aggregate** — billed as 1 read instead of N. One-shot, so a freshly-toggled follow doesn't auto-update the badge until the screen rebuilds; that's intentional. `ref.invalidate(followerCountProvider(uid))` after a follow toggle if you need the count to bump immediately.
- **App Check (May 2026 — client wired, enforcement deferred)**: [`main.dart`](lib/main.dart) calls `FirebaseAppCheck.instance.activate` on every platform — web uses reCAPTCHA v3 (skipped when `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY` is empty), Android uses Play Integrity in release / debug provider in dev, iOS uses DeviceCheck in release / debug provider in dev. The CI deploy passes the site-key dart-define from the `APP_CHECK_RECAPTCHA_SITE_KEY` repo secret. Tokens are advisory until "Enforce" is flipped per-product in Firebase Console (Firestore + Storage). **Don't enforce until a release build with the site key has been live for ≥ 24 h with no spike in token-validation errors** — Enforce-without-working-token = every read/write 403s.
- **Hosting security headers** (`firebase.json` → `hosting.headers["**"]`): `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Content-Type-Options: nosniff`, locked-down `Permissions-Policy` (camera/mic/payment/etc all denied; geolocation kept self-only for the map). `Content-Security-Policy-Report-Only` is shipped first — verify the browser console for a few days, then promote to enforced `Content-Security-Policy`. The CSP allows the Firebase SDKs, Google Maps, reCAPTCHA, and any `https:` image (download URLs come from `firebasestorage.googleapis.com` + `googleusercontent.com` + `picsum.photos`).
- **Admin self-protection rule**: an admin can update any user's doc EXCEPT they can't change their own `role` or `is_banned`. Stops a single fat-finger / compromised admin from locking themselves out. The "must keep ≥ 1 admin" check requires a count, which Firestore rules can't express — that lives in the admin-callable Cloud Function plan (B1).
- **Location search (May 2026)** — replaces the old hardcoded-Berlin stub with real type-ahead via [`place_search_service.dart`](lib/core/services/place_search_service.dart). Uses **Google Places API (New)** at `places.googleapis.com/v1/...` — the *new* endpoint (unlike the legacy `maps.googleapis.com/maps/api/place/...`) supports CORS for direct browser calls, so no backend proxy needed. Two-step flow: `autocomplete` returns lightweight `PlacePrediction`s while typing; `resolve(placeId)` fetches lat/lng + city on tap. Auth re-uses the existing `GOOGLE_MAPS_KEY_WEB` repo secret — same key, just needs **Places API (New)** added to its API restrictions in GCP Console (see "Google Maps keys" section). Picked place lands lat/lng + city + formatted address straight onto the new Momento, so the Map page renders the pin with no extra plumbing.
  - **First swing was Photon** (OpenStreetMap, no API key) — turned out the public `photon.komoot.io` instance does NOT return CORS headers despite some docs claiming otherwise. We hit `Access-Control-Allow-Origin missing` from Chrome on first deploy. Don't go back to it without self-hosting.
- **Deep link `/momento/:id`** — outside the bottom-nav shell, robust to bad ids (loading + not-found state). Used as the **share target**: detail-screen Share / "Copy link" copies `<origin>/#/momento/{id}` to the clipboard (origin mirrors `Uri.base` on web, hardcoded to `https://momento.community` off-web). In-app two-pane Discover keeps its in-place selection (no URL change) by design — the deep link is the *incoming* sharing surface, not the outgoing in-app nav.
- **Follows** — `/follows/{follower}_{following}` doc, deterministic id so create/delete are idempotent. Follower count via Firestore `count()` aggregate stream. `FollowButton` hides when viewing yourself. Profile shows real `followers` count for both self mode (signed-in user) and other mode (the user being viewed).
- **`USE_MOCK_DATA=true`** dart-define bypasses Firestore for offline UI dev + e2e CI. Skips auth gate too.
- Flutter web semantics enabled in `main.dart` so Playwright can query `<flt-semantics>` aria-labels. Icon-only widgets (e.g. `LikeButton`) wrap themselves in `Semantics(label: …)` so they're queryable + screen-readable.
- **Responsive layouts** (`docs/responsive-plan.md`). Breakpoints: tablet 720, desktop 1080, wide 1440, ultrawide 1600. Every screen body sits inside a `ResponsiveContent(maxWidth: …)` (480 / 560 / 720 / 1080 by intent). `MainShell` switches between **bottom nav** (< 720) and **NavigationRail** (≥ 720; collapsed 720–1080, extended ≥ 1080). Discover goes **two-pane** at ≥ 1600 — masonry left, embedded `MomentoDetailScreen` right; tapping a card sets `selectedMomentoIdProvider` (Riverpod `Notifier`) instead of pushing a route, so the URL doesn't change. Below 1600 the slide-up modal is unchanged.

## Brand assets / favicons

Generated by `tool/generate_favicons.py` (Pillow + the OFL Josefin Sans Light file in `tool/fonts/`). Re-run on brand changes. Output:
- `web/favicon.svg` — vector wordmark, modern browsers prefer this
- `web/favicon.png` — 32×32 **Ō glyph only** (wordmark is illegible in tabs)
- `web/icons/Icon-{192,512}.png` — wordmark, 5 % inset (PWA install)
- `web/icons/Icon-maskable-{192,512}.png` — wordmark, 20 % inset (Android adaptive mask)

`manifest.json` background/theme = `#FFFFFF`, name = `Momentō` (with macron).

## Storage layout

Canonical paths (used by repos + seed):
- `users/{uid}/avatar.jpg`
- `momentos/{organizerUid}/{momentoId}/cover.jpg`

All uploads: `Cache-Control: public, max-age=31536000, immutable`.

`storage.rules` uses a cross-service `isAdmin()` that reads `users/{uid}.role` via `firestore.get(...)` so admins can write any path while regular users stay scoped to their own.

## Firestore Storage CORS

Default bucket only allows `*.web.app` / `*.firebaseapp.com`. Custom domains (e.g. `momento.community`) get blocked. Allowed origins in [`storage.cors.json`](storage.cors.json).

**Methods**: `GET`, `HEAD`, `POST`, `PUT`, `DELETE`. Read-only (`GET` + `HEAD`) is enough for browsers to **show** images, but uploads via the Firebase Storage Web SDK use `POST` (multipart) + `PUT` (resumable chunks). If you ever see "Edit photo" / avatar uploads succeed in pickImage but silently fail at the network layer, this is the first thing to check — bucket CORS that's missing `POST`/`PUT` blocks the preflight even before the rule fires.

Apply with:

```bash
gsutil cors set storage.cors.json gs://momento-b23c0.firebasestorage.app
gsutil cors get gs://momento-b23c0.firebasestorage.app   # verify
```

**Important**: this file is NOT auto-deployed by any GitHub workflow. You must run `gsutil cors set ...` manually after editing. If gsutil errors with "Reauthentication required" → `gcloud auth login` first.

## Google Maps keys

Three keys, one per platform. Restrict each one in GCP Console.

**APIs each key must have allowed** (GCP → APIs & Services → Credentials → key → Edit → API restrictions → "Restrict key"):
- **Maps JavaScript API** (Web key only)
- **Maps SDK for Android** (Android key only)
- **Maps SDK for iOS** (iOS key only)
- **Places API (New)** — needed by every key for the location-search feature. Without this enabled the autocomplete endpoint returns 403.

Also enable the **Places API (New)** product in GCP → APIs & Services → Library → search "Places API (New)" → Enable. The legacy "Places API" doesn't help — we use the new one (different endpoint, supports CORS).

Restrict each one in GCP Console:
- **Web** → HTTP referrers — must use **wildcard form**, no scheme:
  `momento.community/*`, `*.momento.community/*`, `momento-b23c0.web.app/*`,
  `localhost:*`. If you see `RefererNotAllowedMapError`, the loaded URL
  (e.g. `https://momento.community/`) doesn't match any pattern — common
  cause is omitting the trailing `/*`.
- **Android** → app restriction `community.momento.app` + SHA-1 (debug + release)
- **iOS** → bundle id `community.momento.app`

**Marker deprecation warning**: `google.maps.Marker is deprecated. Please use
google.maps.marker.AdvancedMarkerElement` is emitted by the
`google_maps_flutter_web` plugin itself — it still wraps the legacy class.
Non-fatal; markers render fine. We'll migrate when the plugin does.

Key wiring per platform:
- **Web** (`web/index.html`) — script tag with `__GOOGLE_MAPS_KEY_WEB__` token. CI (`deploy-hosting.yml`) sed-replaces it from the `GOOGLE_MAPS_KEY_WEB` repo secret. For local web dev, replace the token by hand in `web/index.html` or set `android/local.properties`-style override (see below).
- **Android** (`AndroidManifest.xml`) — `${GOOGLE_MAPS_KEY_ANDROID}` placeholder filled by gradle `manifestPlaceholders`. Resolution: env var → `android/local.properties` (`googleMapsKeyAndroid=...`).
- **iOS** (`Info.plist` → `GMSApiKey = $(GOOGLE_MAPS_KEY_IOS)`) — set the `GOOGLE_MAPS_KEY_IOS` user-defined build setting in Xcode (Runner target → Build Settings → +) or in an xcconfig file. `AppDelegate.swift` reads it and skips `provideAPIKey` if empty.

## Firebase deploy token rotation

Both deploy workflows authenticate with the `FIREBASE_TOKEN` secret (output of `firebase login:ci`). Google occasionally invalidates these tokens — when that happens both deploys fail with `Authentication Error: Your credentials are no longer valid`. Refresh:

```bash
npm install -g firebase-tools@13.29.x
firebase login:ci
# browser flow → token printed at the end → copy it
```

Then GitHub → Settings → Secrets and variables → Actions → `FIREBASE_TOKEN` → **Update secret**.

Re-trigger the failed deploy via Actions → Deploy Hosting / Deploy Rules → **Run workflow**.

**Trap to know about:** the deploy steps pipe through `tail -120`. Bash by default returns the exit code of the LAST command in a pipeline (always 0 for tail), so a failed deploy looks "green" in the Actions UI. Both workflows now `set -o pipefail` to surface failures correctly. If you ever rewrite these steps, keep `pipefail` on or drop the pipe entirely.

Long-term: switch to **Workload Identity Federation** (GitHub OIDC → GCP, no long-lived secrets, never expires). Blocked today by the org policy `iam.disableServiceAccountKeyCreation` that pushed us to FIREBASE_TOKEN in the first place — WIF is the policy-friendly path forward.

## CI alerts (Slack webhook)

Every workflow (`deploy-hosting`, `deploy-rules`, `flutter-test`, `e2e`) ships a final on-failure step that POSTs to the `CI_FAILURE_WEBHOOK_URL` repo secret. Slack incoming webhook URLs work directly; Discord URLs work too if you append `/slack` to the webhook URL.

Failure pings only fire on `push`/`schedule`/`workflow_dispatch` runs against `main` (PR runs are silenced — they're the author's responsibility) and skip cleanly when the secret isn't set.

**Verify Slack delivery on demand**: GitHub → Actions → **Webhook test** → Run workflow → main → Run. Uses `curl -fsS` so the run goes red iff the secret is missing or Slack rejects the payload, green iff a "✅ Webhook test from Momentō CI" message lands in Slack.

## OAuth authorized domains

Custom domains aren't auto-added by Firebase Hosting. Manual:

> Firebase Console → Authentication → Settings → **Authorized domains** → add `momento.community` (and `www.` if used).

Without this, Google/Apple sign-in popups fail with `auth/unauthorized-domain`. Email/password unaffected.

## e2e coverage (mock-mode)

Specs live in `e2e/tests/`. CI (`.github/workflows/e2e.yml`) runs them all against a `--dart-define=USE_MOCK_DATA=true` build (no Firebase calls). Auth-dependent flows live in `auth.spec.ts` and stay out of CI until the Firebase emulator lands (PLAN P3).

| Spec | What it pins |
|---|---|
| `smoke` | App boots → /discover, auth screen reachable, brand assets (`favicon.svg/png`, `manifest.json`) serve correctly |
| `discover` | Masonry renders mock fixture, card tap → detail, organizer card → ProfileScreen (other-mode) header with "X active Momentos · Y followers" + Message |
| `filter` | Filter sheet opens, categories visible, Apply / Reset |
| `map` | Search + filter chrome + Map/Grid toggle |
| `roles` | Plain user sees "Want to host? / Request to host" upgrade card; analytics card hidden |
| `social` | Like-button heart present on cards + detail (substring aria-label match — Tooltip's label is merged into the card group) |
| `profile` | "Created Momentos" / "Liked" tabs, "Created" / "Liked" / "Followers" stats, freemium card |
| `responsive` | Mobile shows bottom nav; tablet shows collapsed rail; desktop shows extended rail with labels. Discover masonry has 2 / 2 / ≥3 cols at mobile / tablet / desktop. At ultrawide (≥ 1600), Discover goes two-pane: empty placeholder on the right by default, tapping a card populates the detail there in-place (no URL change), masonry stays at 2 cols in the narrower left pane. |

**Selector rules of thumb:**
- Visible Flutter text → `flutterText(page, "…")` (substring aria-label OR `getByText` fallback).
- Icon-only widgets (Like, Follow) → wrap in `Tooltip(message: …)` and query with `[aria-label*="…"]`. Flutter merges the tooltip label into the parent group, so substring is mandatory.
- Use `toBeAttached()` not `toBeVisible()` for `<flt-semantics>` nodes — they have zero-size bounding rects.

## Demo seed

[`lib/core/seeds/demo_seed.dart`](lib/core/seeds/demo_seed.dart). Triggered by the debug-mode "Seed demo data" button on Profile (admin-gated). Writes:
- 11 organisor user docs + avatars
- 3 plain-user docs + avatars
- 12 momento docs + cover photos

Images fetched from picsum.photos at run time, uploaded to Storage at canonical paths, URLs stored in Firestore.

## Firebase Console / GCP — manual steps still required

| Item | Status |
|---|---|
| Auth providers (Google + Email/Password) | ✅ Apple deferred to v2 / iOS launch |
| Firestore in `eur3 (europe-west)` | ✅ |
| Storage default bucket | ✅ |
| Storage CORS applied | ✅ (re-apply via `gsutil` after edits to `storage.cors.json`) |
| `momento.community` in Authorized domains (Auth → Settings) | ☐ — required, Firebase does **not** auto-add custom hosting domains |
| GitHub secret `FIREBASE_TOKEN` (`firebase login:ci`) | ✅ |
| GitHub secret `GOOGLE_MAPS_KEY_WEB` | ☐ (paste web key — CI injects into index.html) |
| GCP: enable **Maps JavaScript API**, **Maps SDK for Android**, **Maps SDK for iOS** | ☐ |
| GCP: create + restrict Web / Android / iOS keys | ☐ (see "Google Maps keys") |
| Android key in `android/local.properties` (`googleMapsKeyAndroid=...`) | ☐ (when building Android) |
| iOS key as `GOOGLE_MAPS_KEY_IOS` xcconfig user-defined setting | ☐ (when building iOS) |
| First admin role set on a user doc | ✅ |
| **App Check** Web reCAPTCHA v3 site key created (Console → App Check → Web) | ☐ — paste into GitHub secret `APP_CHECK_RECAPTCHA_SITE_KEY` |
| **App Check** Android Play Integrity provider configured | ☐ (release builds only) |
| **App Check** iOS DeviceCheck / App Attest configured | ☐ (release builds only) |
| **App Check** Firestore + Storage set to **Enforce** mode | ☐ — only after a release build with the site key has been live for ≥ 24h without errors |

## Common commands

```bash
# Dev
flutter run -d chrome                                          # default
flutter run -d chrome --dart-define=USE_MOCK_DATA=true         # offline UI dev (bypasses auth + Firestore)
flutter analyze

# Local web dev with Maps — replace the token in web/index.html before run.
# CI does this automatically; this is only for `flutter run -d chrome`.
sed -i "s|__GOOGLE_MAPS_KEY_WEB__|$GOOGLE_MAPS_KEY_WEB|g" web/index.html  # bash
# (PowerShell:)
# (Get-Content web/index.html) -replace '__GOOGLE_MAPS_KEY_WEB__', $env:GOOGLE_MAPS_KEY_WEB | Set-Content web/index.html

# Manual deploys (CI runs these on push to main when relevant files change)
firebase deploy --only hosting --project momento-b23c0
firebase deploy --only firestore:rules,firestore:indexes,storage --project momento-b23c0

# Re-link Firebase
"$LOCALAPPDATA/Pub/Cache/bin/flutterfire.bat" configure --project=momento-b23c0 \
  --platforms=android,ios,web \
  --android-package-name=community.momento.app \
  --ios-bundle-id=community.momento.app --yes

# Mobile builds (manual)
flutter build ipa
flutter build appbundle

# E2e — full CI matrix (mobile + tablet + desktop + ultrawide)
flutter build web --release --no-tree-shake-icons --dart-define=USE_MOCK_DATA=true
npx -y http-server build/web -p 8080 -s &
cd e2e && BASE_URL=http://localhost:8080 npx playwright test \
  smoke discover filter map roles social profile responsive --reporter=list
```

## Development rules

- Update this file on every architectural / branding / infra change.
- Keep widgets under ~300 lines; extract to `lib/core/widgets/`.
- All colors + text styles via theme tokens.
- v2 only: Stripe, Instagram OAuth, push notifications, RSVPs, comments, analytics.
- "Contact" / footer email link → `info@momento.community`.
- Never invent project IDs, API keys, or secrets. Read from `env.dart`/`--dart-define`.
