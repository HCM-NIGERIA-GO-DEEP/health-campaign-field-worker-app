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
}
