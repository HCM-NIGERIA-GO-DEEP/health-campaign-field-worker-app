/// Pure count computation for the home-screen BeneficiaryProgressBar.
/// Import-free so its unit tests compile independently of the app
/// (same pattern as summary_report_cutoff.dart / daily_delivery_limit.dart).
///
/// Fix for the QA "count grows by N on every app restart" bug (2026-08-07):
/// the DB query windows on clientModifiedTime, so any UPDATE to an old task
/// (edits bump clientAuditDetails.lastModifiedTime) or a downsynced copy made
/// it look like today's work whenever the report cutoff was absent — which
/// was exactly the first computation of every session, because the service
/// context initialization raced the first task-table watch emission. The
/// count therefore inflated at startup and corrected itself only on the next
/// task write.
///
/// The rule here closes that class entirely: a task counts as today's work
/// only if it was CREATED today (clientAuditDetails.createdTime inside the
/// day window), independent of any cutoff state. The report cutoff keeps its
/// original role: deduplicating against the server childrenTreated rollup.
library beneficiary_progress_count;

/// One local task row as the progress bar sees it after the repository
/// query (status ADMINISTRATION_SUCCESS, createdBy = logged-in user,
/// clientModifiedTime within today, current project).
class BeneficiaryProgressTask {
  /// task.projectBeneficiaryClientReferenceId — null is a real value here:
  /// all nulls collapse into ONE counted group (pre-existing quirk, kept).
  final String? beneficiaryRef;

  /// task.clientAuditDetails?.createdTime — the administration moment.
  /// Stable across edits and sync round-trips, unlike clientModifiedTime.
  final int? clientCreatedTime;

  /// task.auditDetails?.lastModifiedTime. Null exactly when auditDetails is
  /// null; for locally created tasks AuditDetails defaults lastModifiedTime
  /// to createdTime, so this is the administration time until a server copy
  /// overwrites the row.
  final int? auditLastModifiedTime;

  /// True when task.additionalFields?.fields is non-null and non-empty.
  final bool hasAdditionalFields;

  const BeneficiaryProgressTask({
    required this.beneficiaryRef,
    required this.clientCreatedTime,
    required this.auditLastModifiedTime,
    required this.hasAdditionalFields,
  });
}

/// Total shown by the bar (and published to DailyDeliveryLimit.count):
/// server-reported childrenTreated for today + distinct local beneficiaries
/// whose delivery task was CREATED inside [windowStart]..[windowEnd]
/// (inclusive, device-local day bounds in epoch ms).
///
/// [serverReportCutoff] is the effectiveReportCutoff for the stored server
/// summary report:
/// - null -> no stored report and no usable cycle start; every task created
///   today counts (nothing to deduplicate against, and
///   [serverReportChildrenTreated] is 0 in this state).
/// - otherwise only tasks with auditLastModifiedTime >= cutoff count on top
///   of [serverReportChildrenTreated]; older ones are assumed to already be
///   inside the server rollup. Tasks with null audit are dropped in this
///   mode (unchanged from the original behavior).
int computeBeneficiaryProgressCount({
  required List<BeneficiaryProgressTask> tasks,
  required int windowStart,
  required int windowEnd,
  required int? serverReportCutoff,
  required int serverReportChildrenTreated,
}) {
  Iterable<BeneficiaryProgressTask> filtered = tasks.where((t) =>
      t.clientCreatedTime != null &&
      t.clientCreatedTime! >= windowStart &&
      t.clientCreatedTime! <= windowEnd);

  if (serverReportCutoff != null) {
    filtered = filtered.where((t) =>
        t.auditLastModifiedTime != null &&
        t.auditLastModifiedTime! >= serverReportCutoff);
  }

  filtered = filtered.where((t) => t.hasAdditionalFields);

  final distinctBeneficiaries = <String?>{};
  for (final t in filtered) {
    distinctBeneficiaries.add(t.beneficiaryRef);
  }

  return serverReportChildrenTreated + distinctBeneficiaries.length;
}

/// Stored day-data values arrive from decoded JSON as num (or, defensively,
/// String); anything unusable is 0 so the bar never throws. Mirrors the
/// service's private _toInt.
int parseReportInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}
