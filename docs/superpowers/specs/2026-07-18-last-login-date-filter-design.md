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
  timestamp lower bound. The service already exposes `getTimestamp(...)`, so Step 1 wires
  the real cutoff resolution directly (no placeholder): stored `timeStamp`, falling back
  to the cycle start date when nothing is stored.
- **Step 3 (teammate):** adds the stored aggregates onto the filtered local numbers
  (merge only — the cutoff itself is already resolved by Step 1's seam).
- **Step 4 (teammate):** fetches the snapshot API after login in `ProjectBloc`, persists it
  via the service; error dialog on failure.

Base flow: `Current Data > filter by timestamp > filteredCurrentData + LastLoginServerData`.

## Semantics (confirmed with team)

- The cutoff is the per-`{userId}_{cycleIndex}` `timeStamp` (epoch ms) — an instant, not a
  calendar date. Local records are counted only when created **at/after** the cutoff
  (`epochMs >= cutoff`; server aggregates are treated as covering everything before it —
  the 1 ms inclusive edge is acceptable).
- **Fallback (confirmed):** when no timestamp is stored for the key —
  `getTimestamp(...)` returns `0` / object is empty — the cutoff is the **cycle start
  date** (`selectedCycle?.startDate ?? 0`). Correct because the server then holds no
  aggregates for this user+cycle, so all local cycle data should count.
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
/// Resolution: LastLoginServerDataService timeStamp for the current
/// {userUuid}_{cycleIndex} key; falls back to the cycle start date when no
/// snapshot is stored (getTimestamp returns 0).
class LocalDataDateFilter {
  static String userCycleKey(BuildContext context) =>
      '${context.loggedInUserUuid}_${context.currentCycleIndex ?? 0}';

  static int cutoffMs(BuildContext context) {
    final ts = LastLoginServerDataService().getTimestamp(
      userIdCycleIndex: userCycleKey(context),
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    if (ts > 0) return ts;
    return context.selectedCycle?.startDate ?? 0;
  }

  static bool isCounted(BuildContext context, int? epochMs) =>
      epochMs != null && epochMs >= cutoffMs(context);
}
```

Call sites resolve the cutoff once per computation (not per record) and reuse it. Key
construction lives here so Step 3/4 can reuse it — **open point for teammate:** confirm
`{userId}` is the user *uuid* (not numeric id).

### Wire-up per surface

1. **Progress bar card** — `lib/widgets/progress_bar/beneficiary_progress.dart`
   Both queries (initial `listenToChanges` query and the query inside the listener) use
   `LocalDataDateFilter.cutoffMs(context)` as `plannedStartDate`. The `lte` (end of day)
   stays. When the cutoff is 0 (no snapshot **and** no cycle) the legacy start-of-day
   lower bound is kept so the daily bar cannot regress to counting all-time tasks.

2. **Stock card + stock validation** — `lib/widgets/stock_balance/stock_balance_card.dart`
   In `_refreshBalances`:
   - stock filter additionally requires `stockEntryDate >= cutoffMs` (kept alongside the
     existing cycle-window check); applied only when `cutoffMs > 0` so the legacy
     no-cycle/no-snapshot behavior (include all) is preserved;
   - `StockCalculationUtils.loadDeliveryTasks` gains an optional `int? startTimestampMs`
     (defaults to `selectedCycle?.startDate`); the card passes the cutoff.
   Stock validation (`hasStockForDelivery` / `hasStockForRedose` in
   `lib/utils/function_registries.dart`) reads `StockBalanceCache`, which this method
   populates — no change needed there.
   `lib/widgets/inventory/custom_product_selection_card.dart` (delivery quantity max
   validations via FormsBloc) uses the identical stock-in-hand computation and gets the
   same wiring, so both validation paths stay consistent.

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

Until Step 4 stores a snapshot, `getTimestamp` returns 0, so every surface filters from
**cycle start**. Stock card and summary report already work on the cycle window, so they
are behavior-neutral. The progress bar widens from "today" to "since cycle start" until a
snapshot exists — expected under the agreed fallback rule.

## Risks / notes for Step 3–4 owners

- The server payload holds only `stockConsumedMap` — no `stockReceived`/`stockReturned`
  aggregates. With stock records date-filtered, the stock-card balance after Step 3 is
  reconstructable only if received/returned stock comes back another way (stock downsync
  or an extended payload). Flagged to the team; Step 1 still applies the filter to stock
  per the agreed plan.
- Once a snapshot exists, the progress bar counts local tasks since the login timestamp
  (can span multiple days) inside a "today" progress bar; Step 3's merge (adding the
  stored current-date `childrenTreated`) defines the final meaning.
- `getTimestamp` requires a `date` argument but never reads it — suggest the Step 2 owner
  makes it optional; Step 1 passes the current date string in the meantime.

## Testing

- Unit tests for `LocalDataDateFilter` (`test/utils/local_data_date_filter_test.dart`):
  stored timestamp wins; 0/empty snapshot falls back to cycle start; no cycle → 0;
  `isCounted` boundary values (null, cutoff−1, cutoff, now); `userCycleKey` format.
- Manual verification: home screen progress bar and stock card, delivery flow stock
  validation, summary report — with and without a stored snapshot, records created
  before vs. after the stored timestamp.
