# HCM Field Worker App — QA Test Kit (Maestro)

> **New here? Start with [QUICK-START.md](QUICK-START.md)** — a one-page, step-wise guide.

**Goal: catch issues in minutes, before an APK ever reaches QA — at zero cost per
run.** Devs run this kit against every build they make; QA runs the same kit on the
APKs they receive. **The kit lives in the app repo at `qa/testkit/` (untracked)** —
everyone uses it from their repo checkout. (It has no dependency on the app source,
so a plain copy of this folder also works if someone hands you one.)

**All testing is done by Maestro** (free, open-source, deterministic — a failed check
fails the same way every time). AI/Claude Code is deliberately **not** part of running
tests or building APKs; it is only an optional authoring aid for maintaining the flow
files (see the last section).

## What's in this folder

```
test-cases.md               Plain-English test cases (source of truth, human-owned)
.maestro/smoke/             Maestro flows implementing the automated cases
run-maestro.ps1             THE command: install APK + run flows + report
setup-maestro.ps1           One-time Maestro installation (Windows)
collect-failure-bundle.ps1  After a failure: gather screenshot/logs/versions to send to devs
maestro.env.example         Template for test credentials (stays local)
CLAUDE.md, .claude/         Optional: rules + skill for AI-assisted flow AUTHORING only
reports/                    Created per run: JUnit report, screenshots, device logs
```

## New machine setup (dev or QA) — 4 steps, once

1. Get the app repo — the kit is at `qa/testkit/` (or use a copy of this folder if
   a dev sent you one).
2. Make `adb` work: install Android platform-tools; `adb devices` must list your
   emulator or USB-connected phone (USB debugging on).
3. In PowerShell inside this folder: `.\setup-maestro.ps1`
   (finds/installs Java, downloads the free Maestro CLI ~300 MB once, sets PATH).
4. Copy `maestro.env.example` → `maestro.env`; fill in the test user, password, and
   boundary. This file stays on your machine — never share, zip, or commit it.

## Dev workflow — before you share any APK

```powershell
.\run-maestro.ps1 -Apk path\to\app-release.apk
```

Installs the APK on the connected device and runs the smoke flows.
**Green → share the APK. Red → open `reports\maestro-<timestamp>\`** — the failure
screenshot and device log show exactly what broke. Minutes per run, zero cost.

```powershell
.\run-maestro.ps1                       # test whatever build is already installed
.\run-maestro.ps1 -Apk x.apk -All       # ALSO run fresh-login (needs a logged-OUT app)
.\run-maestro.ps1 -Serial <id>          # choose among several connected devices
```

Make this a habit: **no APK leaves your machine without a green run.**

**From Git Bash instead of PowerShell:** `run-maestro.ps1` is a PowerShell script, so
call it through `powershell.exe` (still from inside `qa/testkit`):

```bash
powershell.exe -ExecutionPolicy Bypass -File ./run-maestro.ps1 -Apk path/to/app-release.apk
```

(`-ExecutionPolicy Bypass` is only needed if your machine's default policy blocks
unsigned scripts - harmless to always include.)

### Running just one flow

`-Flows` takes a **path** (not a bare flow name) - point it at one file:

```powershell
.\run-maestro.ps1 -Flows .maestro\smoke\09-hf-referral-create.yaml
```

```bash
powershell.exe -ExecutionPolicy Bypass -File ./run-maestro.ps1 -Flows .maestro/smoke/09-hf-referral-create.yaml
```

Combine with `-Apk`/`-Serial` as usual. Leaving `-Flows` out runs everything under
`.maestro\smoke\`. Gotcha: `--exclude-tags needs-logged-out` still applies even to an
explicitly-named flow, so running `01-login-to-home` (or any other
`needs-logged-out`-tagged flow) by itself also needs `-All`:

```powershell
.\run-maestro.ps1 -Flows .maestro\smoke\01-login-to-home.yaml -All
```

```bash
powershell.exe -ExecutionPolicy Bypass -File ./run-maestro.ps1 -Flows .maestro/smoke/01-login-to-home.yaml -All
```

If `-Apk` needs to point at a path that only exists in Git Bash form (e.g.
`/c/Users/you/Downloads/app.apk`), convert it first - PowerShell doesn't understand
POSIX paths:

```bash
powershell.exe -ExecutionPolicy Bypass -File ./run-maestro.ps1 -Apk "$(cygpath -m /c/Users/you/Downloads/app.apk)"
```

## QA workflow — testing an APK you received

QA needs no AI tooling and never touches the app source — same 4-step setup
(repo checkout or a dev-provided copy of this folder), then:

1. `.\run-maestro.ps1 -Apk path\to\received.apk` → automated verdict in minutes.
2. For cases not yet automated (see the Automation status table in
   [test-cases.md](test-cases.md)): test them manually — each case is written as a
   step-by-step script with preconditions and expected results.
3. When something fails: `.\collect-failure-bundle.ps1 -Label TC-005` zips
   screenshot + logs + app/device versions from the device — send it to the dev team
   with the case ID and what you expected.
4. QA owns the test cases too: edit [test-cases.md](test-cases.md) directly (plain
   English) and send the updated file back so dev and QA stay on the same suite.

## The Maestro flows

| Flow | Tag(s) | Needs | What it checks |
|---|---|---|---|
| `00-app-launches` | smoke, safe | nothing | app starts and shows a known first screen |
| `01-login-to-home` | smoke, needs-logged-out | logged-out app + maestro.env | full login → boundary selection → home |
| `02-home-tiles` | smoke, needs-logged-in | a logged-in app | home shows Registration & Delivery, Sync Data, Manage Stock |
| `03-register-household` | smoke, needs-logged-in | CDD user 1 | register a new household (TC-003) |
| `04-add-child-member` | smoke, needs-logged-in | 03 (same run) | add an SMC-eligible child (TC-004) |
| `05-deliver-smc` | smoke, needs-logged-in | 04 (same run) | deliver SMC to that child (TC-005) |
| `06-search-household` | smoke, needs-logged-in | 03 (same run) | search finds the registered household (TC-006) |
| `07-ineligible-routes-to-referral` | negative, needs-logged-in | 03 (same run) | a disqualifying checklist answer routes to Refer Beneficiary, not delivery (TC-007) |
| `08-ineligible-child` | negative, needs-logged-in | 03 (same run) | the other disqualifying answer marks a child ineligible with no referral form (TC-007) |
| `09-hf-referral-create` | smoke, needs-logged-in | CDD user 1 - standalone | create + view an HF Referral (TC-009) |
| `10-stock-reports-cdd` | smoke, needs-logged-in | CDD user 1 - standalone | View Reports menu + role-gated facility filter, CDD side (TC-010) |
| `11-stock-reports-warehouse-manager` | smoke, needs-logged-in | Warehouse Manager user - standalone | same, Warehouse Manager side (TC-010) |
| `12-stock-reconciliation-cdd` | smoke, needs-logged-in | CDD user 1 - standalone | create a Stock Reconciliation record, CDD side (TC-011) |
| `13-stock-reconciliation-warehouse-manager` | smoke, needs-logged-in | Warehouse Manager user - standalone | same, Warehouse Manager side (TC-011) |

Flows 03-08 share one `RUN_STAMP`-named household within a single `run-maestro.ps1`
invocation (03 registers it, 04-08 reuse it) - run them together, not individually,
unless the household already exists from an earlier run in the same session. Every
flow from 09 onward is standalone (own login/setup, no dependency on any other flow) -
see the "Running just one flow" section above.

- The default run **excludes** `needs-logged-out` (it would fail on an already
  logged-in device). Use `-All` after a fresh install.
- Results: `reports\maestro-<timestamp>\report.xml` (JUnit) + screenshots + device
  logs per failure.
- Flows select elements by on-screen text (the app exposes no stable IDs yet), so a
  campaign that renames labels breaks selectors — that is normal maintenance: update
  the quoted text in the flow. `maestro studio` opens an interactive inspector to
  find the right selector.

### Adding a flow (by hand)

Copy an existing YAML in `.maestro/smoke/`, keep the header (appId + tags), select by
exact on-screen text, and never use `clearState` (it permanently deletes unsynced
field data). Tag `safe` only if it taps nothing. Credentials via `${USERNAME}` from
`maestro.env`, never hardcoded. Update the Automation status table in
[test-cases.md](test-cases.md).

## Important: campaign gates (read before trusting a FAIL)

This app blocks flows **by design** in situations that look like bugs:

- **Working hours** — registration/delivery blocked outside configured campaign
  hours, judged by the *device* clock.
- **Cycle window** — the device date must be inside an active campaign cycle.
- **Login boundary** — search only finds households registered in the boundary
  selected at login; a mismatch makes every search empty.
- **Daily delivery cap** — deliveries beyond the per-day limit are blocked.

`run-maestro.ps1` prints the device clock at the start of every run for this reason.
A red run caused by a gate is a precondition problem, not an app bug.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `maestro` not recognized | Open a NEW terminal (PATH updates need one), or re-run `setup-maestro.ps1` |
| `adb devices` shows nothing | Start the emulator / check USB cable + debugging authorization |
| Flows fail with black screenshots | Device screen was locked — the runner tries to wake it, but a PIN lock must be unlocked by hand |
| First run installs something on the device | Maestro installs a small driver app once — normal |
| APK install fails (signature mismatch) | Uninstall the existing app first — warning: that deletes its local data |
| Element not found but visibly on screen | Label text changed (campaign/localization) — check with `maestro studio`, update the flow |
| Text shows as CODE_LIKE_THIS on screen | Missing localization record in the environment — report it, that's a real finding |
| Every search returns nothing | Login boundary doesn't match where the test data was registered |

## Optional: maintaining flows with Claude Code (authoring only)

If you use Claude Code, opening this folder gives it one skill:
`update-maestro-flows` — it can translate a test case from `test-cases.md` into a
Maestro flow, or repair selectors after a campaign renamed labels. **By policy it
never executes tests, installs APKs, or drives a device** (see [CLAUDE.md](CLAUDE.md))
— running tests is always `run-maestro.ps1`, so day-to-day testing costs nothing.
Editing flows and test cases by hand works exactly as well; the AI path is purely
optional.
