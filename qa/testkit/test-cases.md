# HCM Field Worker App — Test Cases

This file is the **source of truth** for APK testing. It is written in plain English so
anyone — QA, developers, leads — can read and edit it. Cases are executed two ways:

- **Automated** — a Maestro flow in `.maestro/` implements the case; it runs on every
  build via `run-maestro.ps1` (fast, free, deterministic).
- **Manual** — no flow yet; a tester follows the written steps by hand.

## Automation status

| Case | How it runs today | Maestro flow |
|---|---|---|
| TC-001 login + home | automated | `01-login-to-home` (plus `00-app-launches`) |
| TC-002 initial sync | partially automated | first-sync wait is inside `01-login-to-home`; dedicated re-sync flow pending |
| TC-003 register household | automated (first live run pending) | `03-register-household` |
| TC-004 add child member | automated (first live run pending) | `04-add-child-member` |
| TC-005 SMC delivery | automated (first live run pending) | `05-deliver-smc` |
| TC-006 search household | automated (first live run pending) | `06-search-household` |
| TC-007 ineligible blocked | automated (first live run pending) | `07-ineligible-routes-to-referral` |
| TC-008 outside working hours | manual (time-gated: needs control of the device clock; emulator only) | — |

`02-home-tiles` is an extra build-smoke flow with no MD case. When a flow is added or
retired, update this table (that's part of adding the flow).

Flows 03–07 run as ONE suite invocation: `run-maestro.ps1` injects a shared
`RUN_STAMP`, so the test household is named `QATEST <RUN_STAMP> HEAD` and later
flows find what earlier ones registered. The eligibility answers in 05/07 come
from the campaign config's own routing rules (all-No = deliver; first question
Yes = refer), not from guesses.

**App launch-state nuance (affects every case, manual or automated):** the app
never opens on the home screen. Every cold start of a logged-in app lands on
the **boundary selection screen with EMPTY dropdowns** (the app re-asks the
working boundary per launch by design — `permissions_handler` routes there
unconditionally; the selection is not persisted across restarts). Every Maestro
flow therefore starts with the shared preamble
`.maestro/common/ensure-home.yaml`, which logs in if needed, re-does boundary
selection with the `BOUNDARY_Lx_VALUE`s from `maestro.env`, and waits for home.
Manual testers: expect to reselect the boundary after every app kill; that is
app behavior, not a bug. Community is a multi-select — close its option panel
by tapping outside it before Submit.

> Screen and button names below are the English texts of the **current campaign**
> (Taraba SMC). If a campaign renames labels, update the quoted texts here — that is
> normal maintenance, cases themselves rarely change.

## How to read and edit this file

Every test case has:

- **ID** — `TC-###`, never reuse an ID; new cases take the next free number.
- **Tags** — `smoke` (must pass on every build), `regression`, `negative`
  (verifies something is correctly blocked), `time-gated` (needs control of the
  device clock; usually emulator-only).
- **Preconditions** — what must be true before the case starts. If a precondition
  cannot be met, the case is reported **BLOCKED**, not failed.
- **Steps** — numbered actions, exactly as a tester would do them.
- **Expected** — the pass/fail contract. **Human-owned: never edited to make a run pass.**
- **Cleanup** — what to do after, if anything.

Setup flows (`SETUP-*`) are reusable step sequences referenced by the cases.

## Suite-wide preconditions (apply to every case)

- The APK under test is installed on exactly one connected device/emulator.
- Users and environment come from `maestro.env` (never from this file).
- **Device date/time is inside an active campaign cycle** — outside it, delivery is
  blocked by design.
- **Device time is inside campaign working hours** — outside them, registration and
  delivery entry points are blocked by design (checked against the device clock).
- The login **boundary must match the seeded/registered test data** — search only
  returns households registered in the logged-in boundary; a mismatch makes every
  search come back empty.
- The daily delivery cap has headroom (the user has not already hit the per-day
  delivery limit on this device today).

---

## Setup flows

### SETUP-RESET — clean app state

1. Clear the app's storage (or uninstall and reinstall the APK).
2. Note: clearing storage deletes **locally created, unsynced records permanently** —
   sync restores server-side data only. Only reset when the case asks for it.

### SETUP-LOGIN — log in and select boundary

1. Launch the app; on the language/landing screen tap **"Continue"**.
2. On the login screen enter the username and password of the user named in the case
   (from `maestro.env`) and tap the login button.
3. On the boundary selection screen, select the boundary listed for that user in
   `maestro.env` (top level first, then each level down).
4. Submit. If a popup offers to download data, choose **Download** (first login).
5. Wait until the home screen is visible.

### SETUP-SYNC — synchronize data

1. From the home screen tap **"Sync Data"**.
2. Wait for the sync to complete (progress indicator disappears / success message).
3. If sync fails, retry once; if it fails again the current case is **BLOCKED**
   (environment problem), and this is called out in the report.

---

## Test cases

### TC-001 — Fresh install, login, and home screen · `smoke`

- **Preconditions:** SETUP-RESET done; network available; CDD user 1 credentials present.
- **Steps:**
  1. Run SETUP-LOGIN as *CDD user 1*.
- **Expected:**
  - Login succeeds with no error toast.
  - Boundary selection lists the levels named in `maestro.env` for this user.
  - The home screen shows at least: **"Registration & Delivery"**, **"Manage Stock"**,
    **"Sync Data"**.
  - No blank tiles and no raw codes like `HOME_..._LABEL` anywhere on the home screen.
- **Cleanup:** none (stay logged in for the next case).

### TC-002 — Initial data sync · `smoke`

- **Preconditions:** TC-001 passed in this session; network available.
- **Steps:**
  1. Run SETUP-SYNC.
- **Expected:**
  - Sync completes without error.
  - After sync, the home screen shows no pending-sync warning/badge.
- **Cleanup:** none.

### TC-003 — Register a new household · `smoke`

- **Preconditions:** Logged in as *CDD user 1*, initial sync done; inside working hours
  and cycle window.
- **Steps:**
  1. From home open **"Registration & Delivery"**.
  2. On the search screen tap **"Register New Household"**.
  3. **"Household Location"** screen: accept/capture the location values, fill any
     mandatory fields (marked *), tap Next.
  4. **"Care giver's consent"** screen: give consent, tap Next.
  5. **"Household Details"** screen: fill all mandatory fields, tap Next.
  6. **"Beneficiary Details"** screen: enter the household head's details. Use the name
     `QATEST <today's date> HEAD` so test data is recognizable. Fill all mandatory
     fields and submit.
- **Expected:**
  - Each screen advances without validation errors after mandatory fields are filled.
  - Registration ends on a success/acknowledgement or household overview screen —
    no crash, no blank screen.
  - The new household (head `QATEST <today's date> HEAD`) is visible afterwards:
    on the household overview, and findable via TC-006's search.
- **Cleanup:** record the household name used in the run report (test data stays in
  the environment on purpose).

### TC-004 — Add a child member to the household · `smoke`

- **Preconditions:** TC-003 passed in this session (its household is open or findable).
- **Steps:**
  1. Open the household registered in TC-003 (search by head name if needed).
  2. From the household overview choose the action to add a member.
  3. **"Member Details"** screen: enter a child whose age makes them **eligible for
     SMC** (between 3 and 59 months). Name them `QATEST <today's date> CHILD`.
     Fill all mandatory fields and submit.
- **Expected:**
  - The member is saved without error and appears in the household overview's member
    list with the entered name and age.
- **Cleanup:** none.

### TC-005 — Deliver SMC to an eligible child · `smoke`

- **Preconditions:** TC-004 passed in this session; inside working hours and cycle
  window; daily delivery cap not reached; stock for the delivery resource available
  to this user.
- **Steps:**
  1. On the household overview, for the child added in TC-004 tap **"Record Data"**.
  2. **"Eligibility Assessment"** screen: answer every question such that the child
     **passes** (no fever, not currently sick, no disqualifying medication), tap Next.
  3. **"Delivery Details"** screen: fill the administered dose/resource fields, tap
     **"Next"**.
  4. **"Please check you have done the following"** screen: confirm every checklist
     item, tap **"Next"**.
- **Expected:**
  - The flow ends on a delivery success/acknowledgement screen.
  - Back on the household overview, the child's status reflects a successful delivery
    for the current cycle (delivered/administered state, not "not delivered").
- **Cleanup:** none.

### TC-006 — Search finds the registered household · `smoke`

- **Preconditions:** TC-003 passed (household exists); logged in with the **same
  boundary** used at registration.
- **Steps:**
  1. From home open **"Registration & Delivery"**.
  2. In **"Search by Household Head"** type the first part of the head's name
     (`QATEST <today's date>`).
- **Expected:**
  - The household registered in TC-003 appears in the results.
  - Opening it shows the household overview with the head and the child member.
- **Cleanup:** none.

### TC-007 — Ineligible child cannot get a delivery · `negative`

- **Preconditions:** Logged in as *CDD user 1*; a household is open; inside working
  hours and cycle window.
- **Steps:**
  1. Add (or pick) a child and start **"Record Data"** for them.
  2. On **"Eligibility Assessment"**, answer at least one question so the child
     **fails** eligibility (e.g. currently on a disqualifying medication or referred
     symptom, per the on-screen questions).
  3. Try to proceed.
- **Expected:**
  - The app does **not** continue to a successful delivery. It routes to the
    designed alternative — **"Refer Beneficiary"** / **"Unable to Deliver"** flow or
    an ineligible outcome — and the child is **not** marked delivered on the
    household overview.
- **Cleanup:** note in the report which child/answers were used.

### TC-008 — Outside working hours, entry is blocked · `negative` `time-gated`

- **Preconditions:** Emulator (device clock must be changeable); logged in as
  *CDD user 1*.
- **Steps:**
  1. Set the device clock to a time clearly **outside** the campaign's configured
     working hours (e.g. 02:00), same date (keep it inside the cycle window).
  2. From home open **"Registration & Delivery"** and attempt to register a new
     household and to record a delivery for an existing beneficiary.
- **Expected:**
  - Both entry points are blocked with the designed message/behaviour — the user
    cannot reach the registration or delivery forms.
- **Cleanup:** **restore the device clock to real time** before any further cases.

---

## Adding new cases — checklist

- Next free ID, correct tags.
- Preconditions state: user + role, boundary, network, cycle/working-hours/cap
  assumptions, and any data the case depends on.
- Steps use the quoted on-screen texts of the current campaign.
- Expected describes what a tester must *see*, not what the code does internally.
- Test data uses the `QATEST <date> ...` naming so it is identifiable later.
