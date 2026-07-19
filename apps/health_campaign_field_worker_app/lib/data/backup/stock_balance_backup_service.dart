import 'shared_storage_backup.dart';

/// Persists the computed home-screen stock balances to public shared storage
/// (via [SharedStorageBackup]) so they survive the user clearing the app's
/// storage.
///
/// The snapshot carries the timestamp it was taken at. Consumers must filter
/// local records to those created *after* that timestamp and add their
/// contribution to the backed-up balances — records created before it
/// (including ones re-downloaded from the server after a storage clear) are
/// already baked into the snapshot, so this avoids both double counting and
/// the inflated balance that appears when received stock is restored by the
/// server but user-created consumption records are not.
class StockBalanceBackupService {
  StockBalanceBackupService._internal();

  static final StockBalanceBackupService _instance =
      StockBalanceBackupService._internal();

  static StockBalanceBackupService get instance => _instance;

  static const String _fileName = 'stock_balance_backup.json';
  static const String _rootKey = 'stockBalanceBackup';

  String backupKey({
    required String projectId,
    required String userUuid,
    required String facilityId,
    required String cycleIndex,
  }) =>
      '$projectId|$userUuid|$facilityId|$cycleIndex';

  Future<Map<String, dynamic>> _readRoot() async {
    final content = await SharedStorageBackup.instance.readJson(_fileName);
    final payload = content[_rootKey];
    if (payload is Map) return payload.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Writes the balances (computed from all records as of [timeStamp]) for
  /// the given key combination, preserving other combinations in the file.
  Future<void> writeBackup({
    required String projectId,
    required String userUuid,
    required String facilityId,
    required String cycleIndex,
    required int timeStamp,
    required Map<String, double> balances,
  }) async {
    final root = await _readRoot();
    root[backupKey(
      projectId: projectId,
      userUuid: userUuid,
      facilityId: facilityId,
      cycleIndex: cycleIndex,
    )] = {
      'timeStamp': timeStamp,
      'balances': balances,
    };

    await SharedStorageBackup.instance.writeJson(_fileName, {_rootKey: root});
  }

  /// Returns the backed-up balances and their snapshot timestamp for the
  /// given key combination, or null when no usable backup exists.
  Future<StockBalanceBackupEntry?> readBackup({
    required String projectId,
    required String userUuid,
    required String facilityId,
    required String cycleIndex,
  }) async {
    final entry = (await _readRoot())[backupKey(
      projectId: projectId,
      userUuid: userUuid,
      facilityId: facilityId,
      cycleIndex: cycleIndex,
    )];
    if (entry is! Map) return null;

    final balances = entry['balances'];
    if (balances is! Map) return null;

    return StockBalanceBackupEntry(
      timeStamp: (entry['timeStamp'] as num?)?.toInt() ?? 0,
      balances: balances.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as num?)?.toDouble() ?? 0.0,
        ),
      ),
    );
  }
}

class StockBalanceBackupEntry {
  final int timeStamp;
  final Map<String, double> balances;

  const StockBalanceBackupEntry({
    required this.timeStamp,
    required this.balances,
  });
}
