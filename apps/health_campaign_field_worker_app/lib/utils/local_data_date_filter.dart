import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../data/local_store/last_login_server_data_service.dart';
import 'extensions/extensions.dart';

/// Epoch-ms lower bound applied to the local "current data" KPI calculations
/// (beneficiary progress bar, stock balance card + stock validation, summary
/// report).
///
/// Resolution rule: the [LastLoginServerDataService] `timeStamp` stored for
/// the current `{userId}_{cycleIndex}` key wins; when no snapshot is stored
/// (`getTimestamp` returns 0) the cutoff falls back to the selected cycle
/// start date, and to 0 (count everything) when no cycle is selected.
/// Server aggregates are treated as covering everything before the cutoff,
/// so local records are counted only when `epochMs >= cutoff`.
class LocalDataDateFilter {
  /// Key format shared with the last-login snapshot payload:
  /// `{userId}_{cycleIndex}`.
  static String buildUserCycleKey(String userId, int? cycleIndex) =>
      '${userId}_${cycleIndex ?? 0}';

  static String userCycleKey(BuildContext context) => buildUserCycleKey(
        context.loggedInUserUuid,
        context.currentCycleIndex,
      );

  /// Pure resolution rule: a stored timestamp (> 0) wins, otherwise the cycle
  /// start date, otherwise 0 so that all records are counted.
  static int resolveCutoffMs({
    required int storedTimestampMs,
    int? cycleStartDateMs,
  }) =>
      storedTimestampMs > 0 ? storedTimestampMs : (cycleStartDateMs ?? 0);

  /// Cutoff for the logged-in user and currently selected cycle. Resolve this
  /// once per calculation and reuse it via [isCountedWith].
  ///
  /// Never throws: each context read is guarded so a missing bloc/provider or
  /// uninitialized SharedPreferences degrades to the next fallback (cycle
  /// start, then 0 = count everything) instead of breaking the caller.
  static int cutoffMs(BuildContext context) {
    int storedTimestampMs = 0;
    try {
      storedTimestampMs = LastLoginServerDataService().getTimestamp(
        userIdCycleIndex: userCycleKey(context),
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
    } catch (_) {
      // SharedPreferences not initialized (or no auth context yet) — fall
      // back to the cycle start below.
    }

    int? cycleStartDateMs;
    try {
      cycleStartDateMs = context.selectedCycle?.startDate;
    } catch (_) {
      // ProjectBloc not in scope — resolve to 0 (count everything) rather
      // than crash the calling widget.
    }

    return resolveCutoffMs(
      storedTimestampMs: storedTimestampMs,
      cycleStartDateMs: cycleStartDateMs,
    );
  }

  /// Whether a record created at [epochMs] falls within the filter window.
  static bool isCountedWith(int cutoffMs, int? epochMs) =>
      epochMs != null && epochMs >= cutoffMs;
}
