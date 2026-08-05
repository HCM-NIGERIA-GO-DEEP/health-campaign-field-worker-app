/// Pure cutoff logic for the server-summary-report local-record filter.
/// Import-free so its unit tests compile independently of the app.
library summary_report_cutoff;

/// Resolves the cutoff used to decide which local records count on top of a
/// stored server summary report (consumers keep records with
/// lastModifiedTime >= cutoff, or all records when the cutoff is null).
///
/// A stored report stamp is returned as-is: the report's stockConsumedMap
/// covers consumption up to that stamp, so filter and map stay paired.
///
/// With no stored report the cycle start is only a valid fallback when it is
/// not in the future — a future cycle start (e.g. a not-yet-started cycle
/// selected on the device) would exclude every local record even though no
/// server report covers them, freezing the stock card and progress bar.
/// Returning null instead is safe because no stored report also means an
/// empty stockConsumedMap, so counting all local records cannot double-count.
int? effectiveReportCutoff({
  required int? storedTimeStamp,
  required int? cycleStartDate,
  required int now,
}) {
  if (storedTimeStamp != null) {
    return storedTimeStamp;
  }
  if (cycleStartDate != null && cycleStartDate <= now) {
    return cycleStartDate;
  }
  return null;
}
