# Flow-graph wiring — every journey navigable end-to-end (config layer)

**Area:** all config-driven journeys (registration, delivery, redose,
checklist, referral, HF referral, inventory/downsync UI, attendance,
complaints, close-household)
**Tests:** the three flow-graph tests in
`test/config/config_invariants_test.dart`
**Engine:** `lintNavigationTargets`, `lintUnknownActionTypes`,
`lintOrphanScreens` in `lint/config_lint_engine.dart`

## Why these exist (engine behavior, verified 2026-08-20)

- A NAVIGATION whose `name`/`popUntilPageName` matches no screen in
  FlowRegistry shows an error toast ("No route found for key") and goes
  NOWHERE (`navigation_service.dart`) — a dead button.
- An actionType with no executor is a silent no-op
  (`action_executor_registry.dart` "No executor found") — the step simply
  does not happen. actionType is a map lookup: expressions like
  `"cond ? A : B"` are never evaluated.
- A screen no string anywhere references cannot be reached at all.

## Scenarios (plain English)

1. Every non-templated NAVIGATION target (name and popUntilPageName) is a
   screen defined in SOME loaded config, or HOME, or an allowlisted
   MDMS-only screen.
2. Every actionType in configs appears in code as a handler — extracted
   textually from canHandle bodies, registry register('X', ...) calls, and
   inline `['actionType'] == 'X'` comparisons (uppercase-literal patterns).
3. No screen is defined-but-referenced-nowhere (orphan), unless allowlisted
   as an app-code entry point.

## Allowlists (in the wrapper test, each entry needs a comment)

`externalScreens` (MDMS-only screens), `appEntryScreens` (entered from app
code), `extraActionTypes` (handlers invisible to the textual scan).
Findings are triaged into: fix the config / fix the code / allowlist with
provenance. Never allowlist to make the run green without knowing why.

## Limits (what this does NOT prove)

Wiring, not behavior: it proves every journey's edges resolve, not that
screens render correctly, gates fire, or data lands — those are unit tests
(logic), other lints (stamping/mapping), and Maestro (true E2E on device).
