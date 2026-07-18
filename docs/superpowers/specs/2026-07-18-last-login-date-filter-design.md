# Step 1 — Date filter for local KPI calculations (Last-Login Server Data plan)

Date: 2026-07-18
Owner: Step 1 (this task). Steps 2–3 owned by another teammate (Step 2 already merged as
`LastLoginServerDataService`), Step 4 lands in `ProjectBloc` later.

## Context

After a fresh login the local DB no longer holds full campaign history, so KPIs computed
purely from local data under-count. The team plan:

- **Step 2 (done):** `lib/data/local_store/last_login_server_data_service.dart` stores the
  server snapshot in SharedPreferences under key `lastLoginServerData`, shaped:

  ```json
  {
    "lastLoginServerData": {
      "{userId}_{cycleIndex}": {
        "timeStamp": 17843665770000,
        "data": {
          "<yyyy-MM-dd>": {
            "householdsRegistered": 0,
            "childrenTreated": 0,
            "childrenRegistered": 0,
            "stockConsumedMap": { "<productVariantId>": 0 }
          }
        }
      }
    }
  }
  ```

- **Step 1 (this spec):** every local query feeding the three KPI surfaces gains a
  timestamp lower bound. Placeholder cutoff for now: **start of the current day**.
- **Step 3 (teammate):** swaps the placeholder for the stored `timeStamp` of the current
  `{userId}_{cycleIndex}` and adds the stored aggregates onto the filtered local numbers.
- **Step 4 (teammate):** fetches the snapshot API after login in `ProjectBloc`, persists it
  via the service; error dialog on failure.

Base flow: `Current Data > filter by timestamp > filteredCurrentData + LastLoginServerData`.

## Semantics (confirmed with team)

- The cutoff is the per-`{userId}_{cycleIndex}` `timeStamp` (epoch ms) — an instant, not a
  calendar date. Local records are counted only when created **at/after** the cutoff
  (`epochMs >= cutoff`; server aggregates are treated as covering everything before it —
  the 1 ms inclusive edge is acceptable).
- The filter applies to all five entities: `stock`, `household`, `household_member`,
  `project_beneficiary`, `task`.
- Each surface keeps the timestamp field it already uses (no behavior drift):
  task SQL → `clientModifiedTime`; stock card → `dateOfEntryTime ?? createdTime`;
  summary report → `clientAuditDetails.createdTime ?? auditDetails.createdTime`.
- Existing cycle-window upper bounds stay as they are; Step 1 only adds/centralises the
  lower bound.

## Design

### New seam: `lib/utils/local_data_date_filter.dart`

```dart
/// Epoch-ms lower bound for "current data" KPI calculations.
/// Step 1 placeholder: start of the current day.
/// Step 3 replaces the body of [cutoffMs] with the LastLoginServerDataService
/// timeStamp for [userCycleKey] (fallback: this placeholder).
class LocalDataDateFilter {
  static String userCycleKey(BuildContext context) =>
      '${context.loggedInUserUuid}_${context.currentCycleIndex ?? 0}';

  static int cutoffMs({String? userCycleKey}) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  static bool isCounted(int? epochMs, {String? userCycleKey}) =>
      epochMs != null && epochMs >= cutoffMs(userCycleKey: userCycleKey);
}
```

`userCycleKey` is threaded through now (even though the placeholder ignores it) so the
Step 3 swap is a one-function change. Key construction lives here so Step 3/4 can reuse it
— **open point for teammate:** confirm `{userId}` is the user *uuid* (not numeric id).

### Wire-up per surface

1. **Progress bar card** — `lib/widgets/progress_bar/beneficiary_progress.dart`
   Both inline `gte` computations (initial `listenToChanges` query and the query inside
   the listener) use `LocalDataDateFilter.cutoffMs(...)` as `plannedStartDate`. The `lte`
   (end of day) stays. With the placeholder this is behavior-neutral (it already filters
   to today).

2. **Stock card + stock validation** — `lib/widgets/stock_balance/stock_balance_card.dart`
   In `_refreshBalances`:
   - stock filter additionally requires `stockEntryDate >= cutoffMs` (kept alongside the
     existing cycle-window check);
   - `StockCalculationUtils.loadDeliveryTasks` gains an optional `int? startTimestamp`
     (defaults to `selectedCycle?.startDate`); the card passes the cutoff.
   Stock validation (`hasStockForDelivery` / `hasStockForRedose` in
   `lib/utils/function_registries.dart`) reads `StockBalanceCache`, which this method
   populates — no change needed there.

3. **Summary report** — `lib/pages/reports/summary/summary_report.dart`
   Add `LocalDataDateFilter.isCounted(epochMs, ...)` beside the existing
   `isWithinCurrentCycle(epochMs)` checks in all loops: households, tasks (children
   treated + stock consumed), non-head household members, stock dates, and the
   per-day `cumulativeStocks` filter.

4. **project_beneficiary** — no direct query exists in these surfaces today (progress bar
   derives beneficiaries from tasks; the report's denominator is non-head members). The
   helper covers it whenever such a count is added; nothing to change now.

### Explicitly untouched

- Trigger-only `listenToChanges` queries (they only signal recompute; the recompute
  filters).
- `_createStockBalanceUserActions` / UserAction STOCK_BALANCE seeding in
  `lib/blocs/project/project.dart` (server-seeded path).
- `HFReferralProgressBar`, stock reconciliation card (not in plan scope).
- `digit_data_model` search models/repositories (in-memory filtering is the existing
  pattern; no SQL/model changes needed — task SQL already supports the range).

## Interim behavior (accepted by team)

Until Step 3 merges the stored aggregates, all three surfaces show only activity since the
placeholder cutoff (today). In particular the stock balance ignores earlier receipts —
temporary and expected.

## Risks / notes for Step 3–4 owners

- The server payload holds only `stockConsumedMap` — no `stockReceived`/`stockReturned`
  aggregates. With stock records date-filtered, the stock-card balance after Step 3 is
  reconstructable only if received/returned stock comes back another way (stock downsync
  or an extended payload). Flagged to the team; Step 1 still applies the filter to stock
  per the agreed plan.
- When the cutoff becomes a days-old login timestamp, the progress-bar window widens from
  "today" to "since last login"; Step 3's merge (adding the stored current-date
  `childrenTreated`) defines the final meaning.
- `LastLoginServerDataService` currently exposes no getter for `timeStamp` — Step 3 will
  need one (or read via `lastLoginServerData`).

## Testing

- Unit tests for `LocalDataDateFilter` (`test/utils/local_data_date_filter_test.dart`):
  cutoff = start of today, `isCounted` boundary values (null, cutoff−1, cutoff, now),
  `userCycleKey` format.
- Manual verification: home screen progress bar and stock card, delivery flow stock
  validation, summary report — with records created today vs. seeded yesterday.
