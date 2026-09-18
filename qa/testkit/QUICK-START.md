# Quick Start — HCM QA Test Kit

**What this is:** one folder that smoke-tests our app APKs with **Maestro** — free,
scripted, ~5 minutes per run. Devs run it on every build **before** sharing an APK;
QA runs it on every APK they receive. Cases that aren't automated yet are tested
manually using the same plain-English file, [test-cases.md](test-cases.md).

No AI is used to run tests — running is one PowerShell command and costs nothing.

## One-time setup (10–20 minutes)

1. Get the app repo — this kit is at `qa/testkit/` (a plain copy of the folder
   also works if a dev sent you one).
2. Install Android platform-tools so `adb` works; connect an emulator or a phone
   with USB debugging. `adb devices` must show exactly one device.
3. In PowerShell inside this folder, run: `.\setup-maestro.ps1`
   (installs the free Maestro CLI, ~300 MB download once).
4. Copy `maestro.env.example` to `maestro.env` and fill in the test username,
   password, and boundary. **Never share this file.**

## Testing an APK

```powershell
.\run-maestro.ps1 -Apk path\to\the.apk
```

- **Green (PASS)** — the build passed the smoke checks; safe to share / test deeper.
- **Red (FAIL)** — open the newest `reports\maestro-...` folder: the failure
  screenshot and log show exactly which step broke.

After a fresh install you can include the full login flow too:

```powershell
.\run-maestro.ps1 -Apk path\to\the.apk -All
```

**Using Git Bash instead of PowerShell?** `run-maestro.ps1` is a PowerShell script -
call it through `powershell.exe` (still from inside `qa/testkit`):

```bash
powershell.exe -ExecutionPolicy Bypass -File ./run-maestro.ps1 -Apk path/to/the.apk
```

(`-ExecutionPolicy Bypass` only matters if your machine's default policy blocks
unsigned scripts - harmless to always include. If your APK path only exists in Git
Bash form, e.g. `/c/Users/you/Downloads/app.apk`, convert it first with
`"$(cygpath -m /c/Users/you/Downloads/app.apk)"` - PowerShell doesn't understand POSIX
paths.)

## Running just one flow

`-Flows` takes a **path**, not a flow name - point it at one file under
`.maestro\smoke\` (run from inside `qa\testkit`):

```powershell
.\run-maestro.ps1 -Flows .maestro\smoke\09-hf-referral-create.yaml
```

```bash
powershell.exe -ExecutionPolicy Bypass -File ./run-maestro.ps1 -Flows .maestro/smoke/09-hf-referral-create.yaml
```

Add `-Apk path\to\the.apk` too if you need to (re)install first. Leaving `-Flows` out
runs every flow in `.maestro\smoke\`. One catch: the fresh-login flow
(`01-login-to-home`, tag `needs-logged-out`) is excluded by default even when named
explicitly - add `-All` to run it:

```powershell
.\run-maestro.ps1 -Flows .maestro\smoke\01-login-to-home.yaml -All
```

```bash
powershell.exe -ExecutionPolicy Bypass -File ./run-maestro.ps1 -Flows .maestro/smoke/01-login-to-home.yaml -All
```

## Before trusting a FAIL

Check the preconditions — this app **blocks flows by design** outside campaign
working hours, outside cycle dates (device clock!), with a wrong login boundary, or
past the daily delivery cap. The runner prints the device clock at every start.
A gate-caused red is a setup problem, not an app bug.

## When something fails

```powershell
.\collect-failure-bundle.ps1 -Label TC-005
```

Zips the screenshot, logs, and app/device versions from the device. Send that zip to
the dev team with the case/flow name and what you expected to see.

## Manual cases and editing

[test-cases.md](test-cases.md) lists every test case with an **Automation status**
table — automated ones run via Maestro, the rest you execute manually following the
written steps. To add or fix a case, edit the file directly (plain English) and send
it back to the dev team so everyone stays on the same suite.

*Full guide (flow catalog, adding flows, troubleshooting): [README.md](README.md).*
