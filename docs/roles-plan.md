# User roles plan — Momentō

Three roles: **user**, **organisor**, **admin**. Stored as `users/{uid}.role`.
Default on user-doc creation = `user`. The role drives both Firestore rules
and which surfaces the app shows.

## 1. Capability matrix

| Action | user | organisor | admin |
|---|:---:|:---:|:---:|
| Read momentos (Discover, Map, Detail) | ✅ | ✅ | ✅ |
| Like / unlike a momento | ✅ | ✅ | ✅ |
| Follow / unfollow an organisor | ✅ | ✅ | ✅ |
| Reserve a spot (when wired) | ✅ | ✅ | ✅ |
| Create a momento | ❌ | ✅ (own only) | ✅ |
| Edit / delete **own** momento | n/a | ✅ | ✅ |
| Edit / delete **any** momento | ❌ | ❌ | ✅ |
| See analytics on **own** momento | n/a | ✅ | ✅ |
| See analytics on **any** momento | ❌ | ❌ | ✅ |
| Access `/admin` panel | ❌ | ❌ | ✅ |
| Promote / demote any user | ❌ | ❌ | ✅ |
| Self-promote `user → organisor` | ✅ (one-tap on Profile) | — | — |
| Self-promote to `admin` | ❌ | ❌ | — |

## 2. Role transitions

| Transition | Who can trigger | Where | Notes |
|---|---|---|---|
| `user → organisor` | the user themselves | Profile → "Become an organisor" CTA | Single doc update. No moderation queue in v1; we'll layer one if abuse appears. |
| `organisor → user` | the user, or any admin | Profile → "Stop hosting" link OR admin panel | Doesn't delete past momentos. |
| any → `admin` | an existing admin only | Admin panel → user row → role dropdown | Hard requirement — never self-grantable. |
| `admin → user/organisor` | another admin (or self) | Admin panel | Can demote yourself; the rule allows it. Keep at least one admin alive (manual responsibility, no automatic check). |

**Bootstrap.** The first admin doesn't exist until set manually:
```text
Firebase Console → Firestore → users/{uid} → set role = "admin"
```
Document this in CLAUDE.md so any new operator knows.

## 3. Data model

### `users/{uid}` (additive)
- `role: string` — `user | organisor | admin`. Defaults to `user` on creation.

Existing fields unchanged. Backwards-compat: any user doc that pre-dates this
plan and is missing the field is treated as `user` by both rules
(`data.get('role', 'user')`) and the app (`(doc['role'] as String?) ?? 'user'`).

### `momentos/{id}`
Unchanged. Role checks happen in rules at write-time and in the UI at
render-time, not on the doc itself. The organizer's identity is already
captured by `organizer_id`.

### (v2) `audit_log/{id}` — out of scope for v1
Eventually we want a write-only audit trail for admin-initiated changes
(role promotions, momento deletions). One doc per action with `actor_id`,
`target_id`, `action`, `before`, `after`, `created_at`. Defer.

## 4. Firestore rules

The change centres on three new helpers + tightened `users` and `momentos`
rules. See `firestore.rules` after this plan lands.

```
function roleOf() { return userDoc().data.get('role', 'user'); }
function isAdmin() { return isSignedIn() && roleOf() == 'admin'; }
function isOrganisor() { return isSignedIn() && roleOf() in ['organisor', 'admin']; }
```

Rule changes:
- `users/{uid}` create: `request.resource.data.role == 'user'` (no self-grant via initial doc).
- `users/{uid}` self-update: `role` may stay the same OR transition `user → organisor` only. Other transitions are admin-only.
- `users/{uid}` admin update: any field, any role transition.
- `momentos/{id}` create: must be `isOrganisor()` (admin counts) AND match existing freemium/ownership/format checks.
- `momentos/{id}` update: organizer-only by default; admin can update any.
- `momentos/{id}` delete: organizer or admin.

The freemium quota check still applies to organisors. Admins are exempt
(they generally won't be hosting at scale; if we want to apply the cap to
them too, easy to add later).

## 5. App-side logic

### Providers (Riverpod)
- `userRoleProvider` — `Provider<String>`. Reads `currentUserDocProvider.data['role']`. Returns `"user"` while loading or for missing field.
- `isAdminProvider`, `isOrganisorProvider` — derived booleans for branch-light gating.

### Surfaces
- **Bottom nav**: the centre Ō and the four corner icons stay 5-up for everyone (visual stability beats perfect role gating). The actual gate is on the Create *screen*, not the tab.
- **Create screen**:
  - role `user` → render an upgrade CTA: "Want to host? Become an organisor" + button that triggers `upgradeToOrganisor()`. After upgrade, the screen rebuilds into the form.
  - role `organisor`/`admin` → existing form.
- **Profile**:
  - role `user` → "Become an organisor" card at the top of the screen (above the freemium card).
  - role `organisor` → analytics summary card per organised momento (Phase R2).
  - role `admin` → "Open admin panel" card linking to `/admin` (Phase R3).
- **Momento detail (Phase R2)**:
  - If `momento.organizer_id == auth.uid` OR `isAdmin()`: show an analytics block under the action row (impressions, likes, followers gained, reservations once wired).

### Routes
- `/admin` (Phase R3): admin-only. Redirects to `/discover` for non-admins.
- All existing routes remain.

## 6. Implementation phases

| Phase | Scope | Status |
|---|---|---|
| **R1** | Plan doc, role field default in `ensureUserDoc`, `userRoleProvider`, `upgradeToOrganisor()` repo method, Create-screen role gate, Profile "Become organisor" CTA, Firestore rules with role helpers. | landing now |
| **R2** | Analytics card on Momento detail (visible only to `organizer_id` or admin). Pulls from existing `view_count`, `like_count`, `liked_by`, plus a small follower-count derivation. | next |
| **R3** | `/admin` route. Three tabs: All Momentos, All Users, Stats. Filter + edit + delete on momentos; role-change dropdown + ban toggle on users. Behind `isAdminProvider` redirect. | follow-up |
| **R4** | Audit log, ban/suspend, optional moderation queue for organisor self-promotion. | later |
