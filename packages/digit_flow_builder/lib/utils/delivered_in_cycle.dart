/// Cycle-scoped delivered-status check backing the `isDelivered`
/// flow-builder function (drives the "Administration Successful" /
/// "Not Visited" tags on the beneficiary card).
///
/// Deliberately import-free and free of framework types so it stays unit
/// testable in isolation. Callers adapt tasks to plain maps (same shape as
/// `TaskModel.toMap()`) and cycles to [CycleWindow]s.
library delivered_in_cycle;

/// Plain-data projection of a campaign cycle's date window.
class CycleWindow {
  final int id;
  final int? startDate;
  final int? endDate;

  const CycleWindow({
    required this.id,
    this.startDate,
    this.endDate,
  });
}

/// Returns true when the beneficiary's latest task belonging to
/// [currentRunningCycle] has a delivered status
/// (`ADMINISTRATION_SUCCESS` / `DELIVERED`).
///
/// Semantics: "last current-cycle task wins" — the same latest-action rule
/// the tag always had, only scoped to the current cycle, so a later
/// BENEFICIARY_ABSENT/REFUSED in the same cycle overrides an earlier
/// success while past-cycle tasks are ignored entirely.
///
/// A task's cycle is resolved from its `additionalFields` `cycleIndex`,
/// falling back to `clientAuditDetails`/`auditDetails` `lastModifiedTime`
/// matched against [cycles] windows (downsync-restored tasks may be
/// unstamped). Tasks whose cycle cannot be resolved are treated as not
/// belonging to the current cycle.
///
/// When [currentRunningCycle] is null, no cycle filtering is applied and
/// the last task overall is evaluated (legacy behavior).
bool isDeliveredInCycle(
  List<Map<String, dynamic>> tasks,
  int? currentRunningCycle,
  List<CycleWindow> cycles,
) {
  Map<String, dynamic>? lastMatchingTask;

  for (final task in tasks) {
    if (currentRunningCycle != null &&
        _resolveTaskCycle(task, cycles) != currentRunningCycle) {
      continue;
    }
    lastMatchingTask = task;
  }

  if (lastMatchingTask == null) return false;

  final status =
      lastMatchingTask['status']?.toString().trim().toUpperCase() ?? '';
  return status == 'ADMINISTRATION_SUCCESS' || status == 'DELIVERED';
}

/// Resolves the cycle a task belongs to, or null when it cannot be
/// determined.
int? _resolveTaskCycle(Map<String, dynamic> task, List<CycleWindow> cycles) {
  // Prefer the explicit cycleIndex stamped in additionalFields.
  final additionalFields = task['additionalFields'];
  if (additionalFields is Map) {
    final fields = additionalFields['fields'];
    if (fields is List) {
      for (final field in fields) {
        if (field is Map && field['key'] == 'cycleIndex') {
          final parsed = int.tryParse(field['value']?.toString() ?? '');
          if (parsed != null) return parsed;
          break;
        }
      }
    }
  }

  // Fall back to deriving the cycle from the task's last modified time
  // (unstamped tasks, e.g. restored by downsync after a storage clear).
  final clientAuditDetails = task['clientAuditDetails'];
  final auditDetails = task['auditDetails'];
  final lastModifiedTime = (clientAuditDetails is Map
          ? clientAuditDetails['lastModifiedTime']
          : null) ??
      (auditDetails is Map ? auditDetails['lastModifiedTime'] : null);
  final lastModifiedTimeMs = int.tryParse(lastModifiedTime?.toString() ?? '');
  if (lastModifiedTimeMs == null) return null;

  for (final cycle in cycles) {
    final start = cycle.startDate;
    final end = cycle.endDate;
    if (start != null &&
        end != null &&
        lastModifiedTimeMs >= start &&
        lastModifiedTimeMs <= end) {
      return cycle.id;
    }
  }
  return null;
}
