/// Pure display-formatting helpers for the summary report.
///
/// Deliberately import-free so the unit tests compile even when unrelated
/// lib files are broken (same convention as team_qr_codec.dart).
library;

/// Converts an ISO date string ('yyyy-MM-dd') to display form ('dd/MM/yyyy').
///
/// Returns the input unchanged when it does not have exactly three
/// dash-separated parts, so a malformed server date never throws here.
String formatSummaryDisplayDate(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Formats a percentage value as 'x.x%'.
String formatSummaryPercent(double value) {
  return '${value.toStringAsFixed(1)}%';
}

/// Formats a stock quantity as a whole number; null (no data for the
/// product on that date) renders as '0'.
String formatSummaryStock(double? value) {
  return (value ?? 0).toStringAsFixed(0);
}
