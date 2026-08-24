# Conventions for Claude in this test kit

This folder is a self-contained Maestro test kit for an Android APK (health campaign
field worker app).

## Policy: Claude never runs tests here

**All test execution belongs to Maestro** (`run-maestro.ps1`), run by a human. It is
free, fast, and deterministic. Claude is used only for **authoring and maintenance,
when explicitly asked** — writing or fixing flows, editing test cases, reviewing a
finished run's report. Claude must NOT:

- run `maestro test`, `maestro studio`, or any flow;
- install, launch, or drive the app on any device/emulator (`adb install`,
  `adb shell input/monkey/am start`, screenshots, UI dumps);
- build APKs or trigger builds;
- do any of the above "just to verify" — verification is the human running
  `.\run-maestro.ps1` and reading the report.

Diagnostics collection is also scripted, not Claude-run: `collect-failure-bundle.ps1`.

## What Claude does here (on request)

- Author or update Maestro flows from `test-cases.md` — use the
  `update-maestro-flows` skill; keep the Automation status table in sync.
- Edit `test-cases.md` when asked to add/correct/remove cases; show the edit.
- Review a completed run's `reports\maestro-<stamp>\` output when asked: classify
  selector-broke vs precondition-unmet vs real defect, fix selectors in YAML,
  and hand back the run command for the human to execute.

## Hard rules

- **Expected results in `test-cases.md` are human-owned.** Never edit an Expected
  section (or weaken a flow assertion) to make a run pass. If an expectation looks
  wrong, flag it for a human.
- Never use `clearState` in flows — it permanently deletes unsynced field data.
- Credentials live only in `maestro.env` (gitignored). Never write credential values
  into flows, reports, or chat.
- A failing flow is information: fail loudly, never route around it.
