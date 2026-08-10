import 'package:digit_data_model/data_model.dart';

/// Helpers for the per-user stock downsync cursor stored in SharedPreferences.
///
/// The cursor (last successful downsync time) must be scoped per user and per
/// cycle: the Downsync table row keyed `stock_{projectId}` is device-global,
/// so on a shared device a second CDD would inherit the first user's recent
/// lastSyncedTime and never download their own stock.
class StockDownsyncCursor {
  StockDownsyncCursor._();

  /// SharedPreferences key for a user's stock downsync cursor.
  /// Cycle index in the key resets the window at each cycle boundary,
  /// matching the cycle-to-cycle download semantics.
  static String key(String projectId, String userUuid, int cycleIndex) =>
      'stockDownsyncTime_${projectId}_${userUuid}_$cycleIndex';

  /// Cutoff for the `lastChangedSince` stock search filter: the stored
  /// cursor when present, otherwise the current cycle's start date
  /// (same as a fresh install). Null only when both are absent
  /// (no campaign cycles configured).
  static int? resolveCutoff({int? storedTime, int? cycleStartDate}) =>
      storedTime ?? cycleStartDate;

  /// Next cursor value derived from the downloaded records: the latest
  /// server `auditDetails.lastModifiedTime` — the same clock domain the
  /// server's `lastChangedSince` filter compares against. Client audit
  /// times are the sender's device clock and must not be used.
  ///
  /// Returns null when no record carries a server audit time (e.g. the
  /// server returned an empty page while reporting a non-zero count) —
  /// the caller must then keep the stored cursor so the window is retried
  /// on the next sync instead of skipping records forever. Never moves
  /// backward past [stored].
  static int? nextCursor({
    required int? stored,
    required Iterable<StockModel> stocks,
  }) {
    int? latest;
    for (final stock in stocks) {
      final time = stock.auditDetails?.lastModifiedTime;
      if (time == null) continue;
      if (latest == null || time > latest) {
        latest = time;
      }
    }
    if (latest == null) return null;
    if (stored != null && stored > latest) return stored;
    return latest;
  }
}
