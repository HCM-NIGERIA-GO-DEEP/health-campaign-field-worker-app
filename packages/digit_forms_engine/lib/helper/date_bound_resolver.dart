/// Keyword a config author writes as a `startDate` / `endDate` validation
/// value to mean "the current device day". Lets a form say "no future
/// dates" without hard-coding an epoch that goes stale.
const String kTodayDateBound = 'today';

/// Resolves a `startDate` / `endDate` validation value to epoch millis.
///
/// - `int` values are the legacy epoch form and pass through unchanged.
/// - The keyword [kTodayDateBound] (case-insensitive, whitespace ignored)
///   resolves to the local day of [now]: its first millisecond for a start
///   bound, its last millisecond when [endOfDay] is true, so that a picker
///   opened right now still has `initialDate <= lastDate`.
/// - Anything else means "no bound" and yields null. Never throws.
///
/// Kept free of Flutter/package imports so it is unit-testable on its own.
int? resolveDateBoundMillis(
  dynamic value, {
  required bool endOfDay,
  DateTime Function() now = DateTime.now,
}) {
  if (value is int) return value;
  if (value is String && value.trim().toLowerCase() == kTodayDateBound) {
    final current = now();
    final dayStart = DateTime(current.year, current.month, current.day);
    if (!endOfDay) return dayStart.millisecondsSinceEpoch;
    return dayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1))
        .millisecondsSinceEpoch;
  }
  return null;
}
