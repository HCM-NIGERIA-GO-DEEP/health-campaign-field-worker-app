# Config invariants (one lint per past config-bug class)

**Area:** campaign config lint (`assets/configs/` = HCM-SOLUTION-CONFIG clone)
**Test:** `test/config/config_invariants_test.dart`
**Engine:** `lint/config_lint_engine.dart` (pure Dart, no app imports)
**Self-proof:** `test/lint_selftest/lint_selftest_test.dart` — every lint
fires on a bad fixture on every run.

## Invariants (plain English)

1. **Cycle-verdict stamping** — every `ineligibleConfig` FETCH block stamps
   `cycleIndex`, and not via `contextData.*`. (Stuck-ineligible bug,
   2026-07-20; reappeared on taraba 2026-08-06.)
2. **FORM-page context** — FETCH_TRANSFORMER_CONFIG data on screens with
   `screenType: FORM` never reads `contextData.*` — the submit context is
   only {formData, navigation, entities}; the field silently drops.
3. **Transformer three-link** — every `configName` a FETCH references must
   exist in `transformer_config.dart`, and critical keys the config passes
   (`cycleIndex`) must have a `__context:<key>` mapping in that section.
   (orsDelivery had links 1+2 but not 3 — ORS tasks silently unstamped.)
4. **fn registry** — every `fn:NAME` in configs must be literally registered
   (`FunctionRegistry.register('NAME'`) somewhere in `lib/` or
   `../../packages/`. Unknown fns hide gated widgets and can blank TEMPLATE
   bodies; the app registering a fn must ship BEFORE the config using it.
5. **Visible text hygiene** — no whitespace-only values under text-ish keys
   (label/text/message/title/hint/...). A single space renders invisible and
   defeats every `isNotEmpty` guard.
6. **Localization dumps** — if a scraped `[{code, message, module}]` JSON is
   present in `assets/configs/`, no message may be ""/" " (blank campaign
   records shadow base-module text app-wide). Skips when no dump present.

## Interpreting a red

- Fix configs in HCM-SOLUTION-CONFIG (local JSON is a clone; `git pull`
  first — a stale clone gives stale verdicts).
- A red fn-registry finding can also mean the CONFIG branch is ahead of the
  APP branch — then the finding is "don't ship these two together".

## Extending

New invariant = one pure `lintX()` in the engine + bad/good fixtures in the
self-test + one `test()` in the wrapper + a bullet here. Extensible constant
lists: `cycleStampedConfigNames`, `criticalMappedKeys`, `_textKeys`.
