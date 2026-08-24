---
name: update-maestro-flows
description: Use when asked to author or update Maestro flows for this kit — add a flow for a test case from test-cases.md, repair selectors after a campaign renamed labels, or review a failed run's report. AUTHORING ONLY - this skill never executes tests, never installs APKs, never drives a device. Trigger phrases - "add a maestro flow for TC-005", "labels changed, fix the flows", "update the flows".
---

# Author / update Maestro flows (authoring only — never execute)

This kit's policy: **Maestro handles all test execution; Claude is used only to write
and maintain the flows, on request.** Test runs cost tokens when Claude does them and
nothing when Maestro does — so:

- NEVER run `maestro test`, `maestro studio`, `adb install`, or any command that
  launches or drives the app. Not even "just to check".
- Your output is edited YAML/markdown plus, at the end, the exact command the human
  runs themselves: `.\run-maestro.ps1 [-Apk <apk>] [-All]`
- If you need to see the current screen to pick a selector, ask the human for a
  `maestro studio` screenshot/hierarchy or a failure screenshot from `reports\` —
  do not capture it yourself.

## Authoring rules (learned from the real app — keep them)

1. Source of truth is `test-cases.md`. A flow implements a test case's steps and
   Expected; **Expected results are human-owned — never weaken them to make a flow
   pass.** Update the Automation status table in `test-cases.md` when a flow is
   added or retired.
2. Selectors: this app exposes NO stable IDs — match visible text (it lives in the
   accessibility tree's `accessibilityText`). Text match is a full-string regex.
   Known patterns:
   - Input fields are bare EditTexts BELOW their label nodes ("User ID *") — use
     `tapOn: { below: { text: "User ID.*" } }`.
   - The login consent row is one merged node — `tapOn: { text: "(?s)By clicking.*" }`
     — and is REQUIRED before the Login button enables.
   - Duplicate texts (title vs button "Login") — disambiguate with `index:`.
   - Quote the exact campaign label texts; when a campaign renames labels, updating
     these quoted strings is the expected maintenance.
3. NEVER use `clearState` — it permanently deletes unsynced field data. Fresh state
   means the human reinstalls the APK.
4. Header pattern: `appId: com.digit.hcm` + tags. Tags gate execution:
   `safe` (taps nothing), `needs-logged-out` (excluded from default runs),
   `needs-logged-in`. Keep credentials out of YAML — `${USERNAME}` etc. come from
   `maestro.env` via the runner.
5. Waits: `extendedWaitUntil` after navigation (30s) and sync (up to 180s), never
   fixed sleeps.
6. Campaign gates are preconditions, not bugs: device date inside cycle, inside
   working hours, boundary matching seeded data, delivery cap headroom. State them
   in the flow's header comment.

## When asked to review a failed run

Read `reports\maestro-<stamp>\` (report.xml, screenshots, device logs) and the flow
YAML. Distinguish: selector broke (label changed) vs precondition unmet (gate,
logged-in state, device clock) vs real app defect. Recommend the fix; if it is a
selector fix, apply it in the YAML. Do not re-run anything — hand back the
run-maestro.ps1 command.
