# Coverage map

## Flow-by-flow: what "covered" means per layer

"End-to-end" has three layers here. The kit owns the first two; true E2E
(app running on device, real DB, server round-trips) is the Maestro bucket
and is NOT covered by this kit.

| Flow | Logic (kit unit) | Config wiring + invariants (kit lints) | True E2E (Maestro) |
|---|---|---|---|
| Login | — (auth bloc: barrel imports; committed `test/pages/login_test.dart` exists) | n/a (no config flow) | Maestro testkit (login probe was pending) |
| Downsync | cursor tests (`test/stock/`) | INVENTORY.json wiring linted | Maestro only (real server + DB) |
| Registration | dates only | REGISTRATION.json: full wiring, cycleIndex stamp, fn registry, transformer links | Maestro |
| Delivery (incl. redose/checklist/refer) | — (eligibility logic: barrel imports, gap) | same REGISTRATION.json lints cover all delivery screens | Maestro |
| HF referral | — | HFREFERRAL.json: full wiring + invariants | Maestro |
| Attendance | session-window tests (`test/dates/`) | ATTENDANCE.json wiring linted | Maestro |
| Inventory/stock recon/reports | cursor tests | INVENTORY/STOCKRECONCILIATION/STOCKREPORTS wiring + fn lints | Maestro |

What the kit covers today, what it deliberately doesn't, and how to extend
it when code, configs, or features change. Update this table whenever a test
is added — it is the kit's table of contents and gap list.

## Covered

| Area | What is checked | Test | Kind |
|---|---|---|---|
| Stock downsync cursor | cutoff resolution, cursor advance from server time only, backward guard, per-user/cycle key scoping | `test/stock/stock_downsync_cursor_test.dart` | unit |
| Date conversions (app-wide) | format branching, garbage → safe defaults, timestamp round trips | `test/dates/date_conversions_test.dart` | unit |
| Attendance session windows | entry/exit epoch per session, parse round trips | `test/dates/date_util_attendance_test.dart` | unit |
| Cycle-verdict stamping | ineligibleConfig FETCH blocks stamp cycleIndex, not via contextData | `test/config/config_invariants_test.dart` | config lint |
| FORM-page context | no contextData.* in FETCH data on FORM screens | same | config lint |
| Transformer three-link | every FETCH configName exists in transformer_config.dart; critical keys (cycleIndex) have `__context:` mappings | same | config lint |
| fn registry | every `fn:` in configs is registered in app/package code | same | config lint |
| Visible text hygiene | no whitespace-only label/text/message/... values | same | config lint |
| Localization dumps | no ""/" " messages (runs when a dump is present) | same | config lint |
| Flow wiring (all journeys) | every NAVIGATION target resolves (dead-button check), every actionType has a handler (silent no-op check), no orphan screens | same | config lint |
| Lint engine itself | every lint proven to fire on bad input and stay quiet on good | `test/lint_selftest/lint_selftest_test.dart` | self-test |

## Known gaps — and which bucket owns them

| Gap | Why not here | Owner bucket |
|---|---|---|
| `StockCalculationUtils`, `function_registries.dart` fn bodies, blocs, repos | Broad/barrel imports — break kit compile on baseline-broken branches | Committed `test/` (with fixes) or later kit entries once imports are split into leaf files |
| flow_builder built-in fns (formatDate, str, ...) | Importing the package risks its known baseline breakage on some branches | Package's own committed tests |
| Eligibility / cycle-continuation logic | Lives behind barrel imports; lesson-backed tests exist on other branches, not portable as-is | Committed `test/` per branch; port via fix_ledger |
| DB-backed behavior, sync flows | Needs Drift/Isar/SQLCipher setup | Maestro / integration_test |
| UI wiring, role gating, blank TEMPLATE rendering | Needs the running app | Maestro |
| Wall-clock behavior (`isToday`, age-from-now) | Kit rule: no `DateTime.now()` | Refactor to injectable clock first, then unit test |

## How to extend (the three recipes)

**A. Code changed / new pure logic added**
1. If the logic is (or can be) in a leaf library with narrow imports, write
   `scenarios/<area>/<case>.md` in plain English, generate
   `test/<area>/<case>_test.dart`, prove it can fail (mutate-and-run), add a
   row above.
2. If it's fix-coupled, the test goes in the app's committed `test/` with
   the fix — not here.
3. If the file has barrel imports, either extract the pure part into a leaf
   file first (preferred — see 2026-08-03 lesson) or record it as a gap.

**B. Config changed / new campaign onboarded**
1. `git pull` in `assets/configs`, run `flutter test test/shared/test/config`.
2. Every red is either a real config bug (fix in HCM-SOLUTION-CONFIG) or a
   config that legitimately moved ahead of this app branch (then the finding
   is "don't ship these together").
3. New config pattern introduced (new transformer config, new must-land
   field, new text key)? Extend the constant lists in
   `lint/config_lint_engine.dart` (`cycleStampedConfigNames`,
   `criticalMappedKeys`, `_textKeys`) — one line each.

**C. New feature / new bug class escaped to QA**
1. Triage into a bucket (see README ratchet).
2. If it's a new *config* bug class: add a `lintX()` function to the engine
   (pure, ~20 lines), a bad+good fixture pair in the self-test, a test() in
   `config_invariants_test.dart`, and a scenario file. The engine's loaders
   and walkers are reusable — no new I/O code.
3. If it's a new *logic* bug class: recipe A.
