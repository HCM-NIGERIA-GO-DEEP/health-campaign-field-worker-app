/// Pure day-key logic for the stored server summary report.
/// Import-free so its unit tests compile independently of the app.
/// Nothing here throws: it runs inside the report write, and an exception
/// there would drop the whole downloaded report.
library summary_report_date_filter;

/// Largest |epochMs| DateTime accepts; beyond it the constructor throws.
const int _maxEpochMs = 8640000000000000;

final RegExp _dayKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Formats [epochMs] as a report day key (`yyyy-MM-dd`) in device-local
/// time — the same calendar day the summary page derives for local records.
/// Returns null when [epochMs] is outside the range DateTime accepts.
String? reportDayKey(int epochMs) {
  if (epochMs < -_maxEpochMs || epochMs > _maxEpochMs) {
    return null;
  }

  final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Whether [key] is a real calendar day written as `yyyy-MM-dd` — the only
/// shape whose string order is date order.
bool _isReportDayKey(String key) {
  final match = _dayKeyPattern.firstMatch(key);
  if (match == null) {
    return false;
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  // DateTime normalises overflow (2026-02-30 -> 2026-03-02), so a changed
  // field means the key is not a real day.
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

/// Drops report days dated before the day [cycleStartDate] falls on, so a
/// cycle's stored report holds only that cycle's days — the server can
/// return an earlier day for a fetch that starts at the cycle start (QA:
/// a 30/09 column, and its consumption in the balances, on cycle 4
/// starting 1 Oct).
///
/// Only days it can verify are dropped: returns [dayData] unchanged when
/// [cycleStartDate] is null or doesn't map to a `yyyy-MM-dd` day (out of
/// range, or a year past 9999), and keeps any key that is not
/// a real `yyyy-MM-dd` day as-is, since its date order can't be trusted.
Map<String, dynamic> dropDaysBeforeCycleStart(
  Map<String, dynamic> dayData, {
  required int? cycleStartDate,
}) {
  final startDay =
      cycleStartDate == null ? null : reportDayKey(cycleStartDate);
  if (startDay == null || !_isReportDayKey(startDay)) {
    return dayData;
  }

  return {
    for (final entry in dayData.entries)
      if (!_isReportDayKey(entry.key) || entry.key.compareTo(startDay) >= 0)
        entry.key: entry.value,
  };
}
