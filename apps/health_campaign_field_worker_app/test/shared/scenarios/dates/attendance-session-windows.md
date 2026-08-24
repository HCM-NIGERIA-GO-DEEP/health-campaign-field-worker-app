# Attendance session windows stamp the right epoch

**Area:** `lib/utils/date_util_attendance.dart`
**Test:** `test/dates/date_util_attendance_test.dart`

## Scenarios (plain English)

1. Morning session (code 0): entry stamps 09:00 local, exit stamps 11:58.
2. Afternoon session (non-0): entry stamps 12:05, exit stamps 18:00.
3. Any string other than exactly "entryTime" falls to the exit branch
   (documents the current stringly-typed contract).
4. `getDateString` ↔ `getFormattedDateToDateTime` round-trip; garbage → null.
5. `getFilteredDate`: empty → '', garbage → null, never throws.

## Deliberately untested

`isToday` depends on `DateTime.now()` (kit rule: no wall-clock).
