# hcm-shared-tests

Shared, **deliberately uncommitted** test kit for the HCM field worker app.
One suite, run against every campaign branch — because config fixes and code
fixes don't propagate between per-campaign copies/branches, and this kit is
how their regressions get caught anyway.

> **Do not commit this folder into the app repo.** That migration is planned
> for later (once CI runs `flutter test` and the suite stabilizes). Until
> then it stays a separate repo so one current version applies to all
> branches at once.

## Setup (one-time, per app-repo clone)

1. Clone this repo into the app:
   `git clone <kit-remote> apps/health_campaign_field_worker_app/test/shared`
2. Tell your app clone to ignore it (never committed, works on all branches):
   add this line to `<app-repo>/.git/info/exclude`:
   ```
   apps/health_campaign_field_worker_app/test/shared/
   ```
3. If you run config lints, refresh `assets/configs/` from
   HCM-SOLUTION-CONFIG first — a stale local copy gives stale verdicts.

## Run

From `apps/health_campaign_field_worker_app`:

```
flutter test test/shared/test            # whole kit
flutter test test/shared/test/config     # config lints only
```

## Layout

- `scenarios/<area>/<case>.md` — plain-English test cases (Given/When/Then +
  expected values). Anyone can write these; Claude converts them to Dart.
- `test/<area>/<case>_test.dart` — the generated tests. A test enters the kit
  only after it's proven able to fail — for lints that proof is permanent and
  automatic via `test/lint_selftest/` (bad/good fixtures per lint).
- `lint/config_lint_engine.dart` — pure-Dart lint engine: loaders, walkers,
  and one pure function per config invariant. New invariant ≈ 20 lines +
  fixtures. Extensible constant lists for new configs/keys.
- `COVERAGE.md` — what's covered, known gaps with owning bucket, and the
  three extension recipes (code change / config change / new feature).
- `COMPAT.md` — which kit commit runs green on which app branches.

## Rules (each one exists because of a real bug)

1. **Narrow imports only.** Import leaf libraries (e.g.
   `utils/stock_downsync_cursor.dart`) or no app code at all (config lints).
   Barrel imports (`extensions.dart`, `constants.dart`) transitively pull
   baseline compile errors that exist on some branches and take the whole
   kit down with them.
2. **Only dev-dependencies already in the app's pubspec.yaml**
   (flutter_test, bloc_test, mocktail). Needing a new one means a committed
   pubspec change on every branch — that's a team decision, not a kit PR.
3. **Config lints must skip, not fail, when configs are absent** — CI and
   fresh clones have no `assets/configs/` (gitignored).
4. **Fix-coupled tests do NOT belong here.** A test written alongside a fix
   goes in the committed `test/` folder in the same commit as the fix, so it
   rides cherry-picks. The kit is for cross-branch suites and config lints.
5. **No wall-clock dependence.** Tests must not depend on `DateTime.now()` —
   pass fixed timestamps.

## Triage ratchet (how the kit grows)

Every bug that reaches QA gets a regression test in exactly one bucket:

| Bucket | When |
|---|---|
| Committed `test/` (with the fix) | The test guards the fixed code path and should travel with cherry-picks |
| Kit unit test | Cross-branch logic that keeps regressing or was never ported everywhere |
| Kit config lint | The bug was config/data (missing stamps, blank localization, missing mappings) |
| Maestro flow | Only visible through the running app (UI wiring, sync round-trips, release builds) |

## Future: committing this kit

Trigger conditions: CI extended to run `flutter test` on campaign branches
(the 4 baseline-broken test files must be fixed first), or the suite is
stable and campaign-agnostic. Migration: move `test/` contents into the
app's committed `test/` folder per branch, delete the exclude line, add a
test step to `.github/workflows/dart.yml`.
