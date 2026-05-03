# Momentō e2e (Playwright)

End-to-end tests against the running Flutter web build.

See **[PLAN.md](./PLAN.md)** for the full strategy. This README is the quick
"how to run it" guide.

## First-time setup

```bash
cd e2e
npm install
npx playwright install chromium       # downloads the browser binary
```

## Run modes

### A. Against a local dev server (fastest iteration)

In one terminal — start the Flutter web server:

```bash
# From repo root
flutter run -d web-server --web-port 8080
```

In a second terminal:

```bash
cd e2e
BASE_URL=http://localhost:8080 npm run test
```

### B. Against the deployed environment

```bash
cd e2e
BASE_URL=https://momento-b23c0.web.app npm run test
```

### C. Headed for debugging a single test

```bash
cd e2e
BASE_URL=http://localhost:8080 npx playwright test smoke.spec.ts --headed --debug
```

## Inspecting failures

```bash
cd e2e
npm run report                        # opens last HTML report
```

Failed tests retain a Playwright trace at `test-results/<test>/trace.zip` —
open via `npx playwright show-trace test-results/.../trace.zip`.

## What's implemented today

- **`smoke.spec.ts`** — app boots, wordmark visible, onboarding → auth flow,
  auth-gated redirect.
- **`auth.spec.ts`** — email sign-up + bad-credentials sign-in.

## What's planned

See [PLAN.md](./PLAN.md) for the full bucket list. Discover / Map / Filter /
Create / Profile flow tests are scaffolded next once selectors are stable.
