# Momentō

[![e2e (Playwright)](https://github.com/momento-community/momento/actions/workflows/e2e.yml/badge.svg)](https://github.com/momento-community/momento/actions/workflows/e2e.yml)
[![Deploy Hosting](https://github.com/momento-community/momento/actions/workflows/deploy-hosting.yml/badge.svg)](https://github.com/momento-community/momento/actions/workflows/deploy-hosting.yml)
[![Deploy Rules](https://github.com/momento-community/momento/actions/workflows/deploy-rules.yml/badge.svg)](https://github.com/momento-community/momento/actions/workflows/deploy-rules.yml)

> Find what's happening around you, right now.

A Pinterest-style local event-discovery app. Events are **Momentos**.
Live at **[momento.community](https://momento.community)**.

## Stack

Flutter 3.38+ · Riverpod 3 · `go_router` · Firebase (Auth / Firestore / Storage / Hosting) · `google_maps_flutter`. Web + iOS + Android, single codebase.

## Layout

| | |
|---|---|
| `lib/` | App source (features-by-folder) |
| `lib/config/` | Env, theme, router, breakpoints |
| `lib/core/` | Repositories, providers, shared widgets, models, seeds |
| `lib/features/` | Discover, Map, Create, Profile, MomentoDetail, Auth, Admin, … |
| `web/`, `android/`, `ios/` | Platform shells |
| `firestore.rules`, `storage.rules` | Security rules (deployed by CI) |
| `e2e/` | Playwright suite (mock-mode) |
| `test/` | Flutter unit + widget tests |
| `tool/` | Build helpers (favicon generator, fonts) |
| `docs/` | Design export, roles plan, responsive plan |

## Run

```bash
# Mock-mode dev (no Firebase calls — instant boot)
flutter run -d chrome --dart-define=USE_MOCK_DATA=true

# Live dev (real Firebase project)
flutter run -d chrome
```

Full command reference + every manual GCP / Firebase Console step in [`CLAUDE.md`](CLAUDE.md).

## Tests

```bash
flutter test                                          # unit + widget
cd e2e && BASE_URL=http://localhost:8080 npm test     # e2e (needs build/web served)
```

## Deploy

CI handles it. Pushes to `main` that touch `lib/`, `web/`, or any rules file auto-deploy.

## Contributing

See [`CLAUDE.md`](CLAUDE.md) (architectural decisions, brand rules, locked identifiers).
Issues + PRs welcome.

## Contact

[info@momento.community](mailto:info@momento.community)
