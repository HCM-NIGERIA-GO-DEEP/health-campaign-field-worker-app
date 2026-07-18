import 'shared_storage_backup.dart';

/// Persists the summary report's per-date rows to public shared storage
/// (via [SharedStorageBackup]) so the report survives the user clearing the
/// app's storage. Rows are stored per user/project/facility/cycle, keyed by
/// their `yyyy-MM-dd` date string.
///
/// The snapshot carries the timestamp it was taken at. The report must
/// filter local records to those created *after* that timestamp and add
/// their contribution to the backed-up rows — records created before it
/// (including ones re-downloaded from the server after a storage clear) are
/// already baked into the snapshot.
class SummaryReportBackupService {
  SummaryReportBackupService._internal();

  static final SummaryReportBackupService _instance =
      SummaryReportBackupService._internal();

  static SummaryReportBackupService get instance => _instance;

  static const String _fileName = 'summary_report_backup.json';
  static const String _rootKey = 'summaryReportBackup';

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

  /// Writes the merged report rows (a map of `yyyy-MM-dd` date string to row
  /// JSON, computed from all records as of [timeStamp]) for the given key
  /// combination, preserving other combinations in the file.
  Future<void> writeRows({
    required String projectId,
    required String userUuid,
    required String facilityId,
    required String cycleIndex,
    required int timeStamp,
    required Map<String, dynamic> rows,
  }) async {
    final root = await _readRoot();
    root[backupKey(
      projectId: projectId,
      userUuid: userUuid,
      facilityId: facilityId,
      cycleIndex: cycleIndex,
    )] = {
      'timeStamp': timeStamp,
      'rows': rows,
    };

    await SharedStorageBackup.instance.writeJson(_fileName, {_rootKey: root});
  }

  /// Returns the backed-up rows (date string -> row JSON) and their snapshot
  /// timestamp for the given key combination. Empty with timestamp 0 when no
  /// usable backup exists.
  Future<SummaryReportBackupEntry> readEntry({
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
    if (entry is Map) {
      final rows = entry['rows'];
      if (rows is Map) {
        return SummaryReportBackupEntry(
          timeStamp: (entry['timeStamp'] as num?)?.toInt() ?? 0,
          rows: rows.cast<String, dynamic>(),
        );
      }
    }

    return const SummaryReportBackupEntry(
      timeStamp: 0,
      rows: <String, dynamic>{},
    );
  }
}

class SummaryReportBackupEntry {
  final int timeStamp;
  final Map<String, dynamic> rows;

  const SummaryReportBackupEntry({
    required this.timeStamp,
    required this.rows,
  });
}
