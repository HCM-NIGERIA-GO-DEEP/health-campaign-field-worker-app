# DateConversions never throws and round-trips cleanly

**Area:** `lib/utils/date_conversions.dart` (used app-wide for display dates)
**Test:** `test/dates/date_conversions_test.dart`

## Scenarios (plain English)

1. A local ISO datetime formats as dd/MM/yyyy by default; custom patterns
   are honoured.
2. Empty/whitespace input → empty string; unparseable input → null — never
   an exception (a throw here inside a flow-builder fn blanks the screen).
3. Both accepted date-string formats parse: `31-01-2025` and `31/01/2025`;
   garbage parses to null.
4. `dateToTimeStamp` and `getDateFromTimestamp` are inverses; garbage → 0.
5. `timeStampToDate(null)` → empty string.
6. Month/day abbreviations for fixed dates ("Mar", "Sun").

## Deliberately untested

`getYearsAndMonthsFromDateTime` depends on `DateTime.now()` (kit rule: no
wall-clock). To cover it, refactor to take a reference date parameter first.

All assertions are timezone-robust (round trips and local-to-local only) so
the kit passes on any dev machine.
