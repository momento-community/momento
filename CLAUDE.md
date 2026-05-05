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
- Theme tokens in [`lib/config/theme.dart`](lib/config/theme.dart) — **never** inline hex.
- Test on iPhone 14 Pro (390×844). Web responsive: 1 col `<600px`, 2 cols `600–1200px`.

## Key files

- `lib/config/{env,theme,router}.dart` — config, design tokens, go_router with role + auth redirects
- `lib/core/firebase/providers.dart` — Riverpod providers + role/freemium derivations
- `lib/core/repositories/` — `MomentoRepository`, `UserRepository`, `StorageRepository`, `AuditLogRepository`, `FollowRepository`. All Firestore writes go through here.
- `lib/core/widgets/{momento_logo,momento_button,slide_up_route,like_button,follow_button}.dart`
- `lib/core/seeds/demo_seed.dart` — admin-gated demo data flow
- `lib/shared/filter_state.dart` — shared filter state for Discover + Map
- `firestore.rules` · `firestore.indexes.json` · `storage.rules` · `storage.cors.json`
- `docs/{design-export,roles-plan}.md`
- `.github/workflows/{deploy-hosting,deploy-rules,e2e}.yml`

## User roles

| Role | Capabilities |
|---|---|
| **user** | read + like + follow |
| **organisor** | + create / edit / delete own + analytics on own |
| **admin** | + edit / delete *any* + admin panel + manage roles + ban/unban |

Default `user` on signup. Self-service `user → organisor` from Profile or Create. Admin-only-grantable. Banned users keep read access but lose every write (rule-enforced via `is_banned`).

**Bootstrap admin:** Firebase Console → Firestore → `users/{uid}` → set `role` = `"admin"`. Full plan: [`docs/roles-plan.md`](docs/roles-plan.md).

**Admin panel** (`/admin`, four tabs): **Momentos** (delete, audited) · **Users** (role dropdown + ban toggle, both audited) · **Audit log** (append-only) · **Stats**.

**Audit log** lives in `audit_log/{id}` (append-only, admin-read-only). Action codes: `momento.delete`, `user.role_change`, `user.ban`, `user.unban`. Schema in [`audit_log_repository.dart`](lib/core/repositories/audit_log_repository.dart).

## Architecture decisions

- **No Cloud Functions in v1.** Race window for create-conflicts is tiny; rules + transactions cover ownership/freemium. Re-add as a callable if duplicates surface.
- `autoExpire` replaced by `where('end_datetime', '>', now())`. `onMomentoLikeChange` replaced by transaction-bumped `like_count` inside `toggleLike`.
- **Likes** — heart on every card (top-right overlay) + detail screen. State is `momento.likedBy.contains(uid)`; toggle is a transaction on the momento doc (`liked_by` arrayUnion/Remove + `like_count` increment). Optimistic UI in `LikeButton` for instant feedback.
- **Follows** — `/follows/{follower}_{following}` doc, deterministic id so create/delete are idempotent. Follower count via Firestore `count()` aggregate stream. `FollowButton` hides when viewing yourself. Profile shows real `followers` count for the signed-in user; organizer detail shows it for the organizer.
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

Default bucket only allows `*.web.app` / `*.firebaseapp.com`. Custom domains (e.g. `momento.community`) get blocked. Allowed origins in [`storage.cors.json`](storage.cors.json). Apply with:

```bash
gsutil cors set storage.cors.json gs://momento-b23c0.firebasestorage.app
gsutil cors get gs://momento-b23c0.firebasestorage.app   # verify
```

If gsutil errors with "Reauthentication required" → `gcloud auth login` first. Re-apply when adding origins.

## Google Maps keys

Three keys, one per platform. Restrict each one in GCP Console:
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

## OAuth authorized domains

Custom domains aren't auto-added by Firebase Hosting. Manual:

> Firebase Console → Authentication → Settings → **Authorized domains** → add `momento.community` (and `www.` if used).

Without this, Google/Apple sign-in popups fail with `auth/unauthorized-domain`. Email/password unaffected.

## e2e coverage (mock-mode)

Specs live in `e2e/tests/`. CI (`.github/workflows/e2e.yml`) runs them all against a `--dart-define=USE_MOCK_DATA=true` build (no Firebase calls). Auth-dependent flows live in `auth.spec.ts` and stay out of CI until the Firebase emulator lands (PLAN P3).

| Spec | What it pins |
|---|---|
| `smoke` | App boots → /discover, auth screen reachable, brand assets (`favicon.svg/png`, `manifest.json`) serve correctly |
| `discover` | Masonry renders mock fixture, card tap → detail, organizer card → organizer screen |
| `filter` | Filter sheet opens, categories visible, Apply / Reset |
| `map` | Search + filter chrome + Map/Grid toggle |
| `roles` | Plain user sees "Become an organisor" upgrade card; analytics card hidden |
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

# E2e
cd e2e && BASE_URL=http://localhost:8080 npm test    # against `flutter run -d web-server --web-port 8080`
```

## Development rules

- Update this file on every architectural / branding / infra change.
- Keep widgets under ~300 lines; extract to `lib/core/widgets/`.
- All colors + text styles via theme tokens.
- v2 only: Stripe, Instagram OAuth, push notifications, RSVPs, comments, analytics.
- "Contact" / footer email link → `info@momento.community`.
- Never invent project IDs, API keys, or secrets. Read from `env.dart`/`--dart-define`.
