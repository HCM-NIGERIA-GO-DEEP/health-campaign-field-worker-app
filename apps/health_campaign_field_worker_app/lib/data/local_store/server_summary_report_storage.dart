import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/summary_report_remote_repository.dart';

class ServerSummaryReportStorage {
  static const String storageKey = 'ServerSummaryReport';

  ServerSummaryReportStorage._();

  static final ServerSummaryReportStorage instance =
      ServerSummaryReportStorage._();

  Future<void> writeSummaryReports({
    required String userUuid,
    required String projectId,
    required int cycleIndex,
    required List<ServerSummaryReport> reports,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final root = _readRoot(prefs);
    final reportKey = _buildReportKey(
      userUuid: userUuid,
      projectId: projectId,
      cycleIndex: cycleIndex,
    );

    final existingEntry = root[reportKey];
    final existingData = existingEntry is Map
        ? Map<String, dynamic>.from(existingEntry['data'] as Map? ?? {})
        : <String, dynamic>{};

    for (final report in reports) {
      // Baselines are NOT recorded here. Writing one at sync time captured a
      // count that already included this device's just-pushed households, so
      // adding the local rows on top counted them twice (29 + 2 registered
      // read as 34). Only a caller that knows the device holds zero local
      // rows for a date can safely record its baseline - see
      // ServerSummaryReportService.baselineFor.
      // Carry any existing baseline forward untouched.
      final previous = existingData[report.date];
      final previousMap = previous is Map ? previous : const {};

      existingData[report.date] = {
        'householdsRegistered': report.householdsRegistered,
        'peopleInHouseholds': report.peopleInHouseholds,
        'childrenTreated': report.childrenTreated,
        'childrenRegistered': report.beneficiariesRegistered,
        'itnsDistributed': report.itnsDistributed,
        'stockConsumedMap': report.stockConsumedMap,
        for (final key in [
          'baselineHouseholdsRegistered',
          'baselinePeopleInHouseholds',
          'baselineChildrenUnder5',
          'baselineItnsDistributed',
        ])
          if (previousMap[key] != null) key: previousMap[key],
      };
    }

    root[reportKey] = {
      'timeStamp': DateTime.now().millisecondsSinceEpoch,
      'data': existingData,
    };

    await prefs.setString(storageKey, jsonEncode({storageKey: root}));
  }

  /// Persists the pre-contribution baseline for a single date.
  ///
  /// Supply a metric only when the device has no local contributions to
  /// that metric on [date]. Writes the minimum ever seen, so a later
  /// observation that has grown (because records landed) cannot raise it.
  Future<void> writeBaseline({
    required String userUuid,
    required String projectId,
    required int cycleIndex,
    required String date,
    int? households,
    int? people,
    int? childrenUnder5,
    int? itnsDistributed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final root = _readRoot(prefs);
    final reportKey = _buildReportKey(
      userUuid: userUuid,
      projectId: projectId,
      cycleIndex: cycleIndex,
    );

    final existingEntry = root[reportKey];
    final existingData = existingEntry is Map
        ? Map<String, dynamic>.from(existingEntry['data'] as Map? ?? {})
        : <String, dynamic>{};

    final dayEntry = existingData[date];
    final dayData = dayEntry is Map
        ? Map<String, dynamic>.from(dayEntry)
        : <String, dynamic>{};

    final observations = {
      'baselineHouseholdsRegistered': households,
      'baselinePeopleInHouseholds': people,
      'baselineChildrenUnder5': childrenUnder5,
      'baselineItnsDistributed': itnsDistributed,
    };
    var changed = false;
    for (final entry in observations.entries) {
      final observed = entry.value;
      if (observed == null) continue;
      final stored = dayData[entry.key];
      if (stored is num && stored <= observed) continue;
      dayData[entry.key] = observed;
      changed = true;
    }
    if (!changed) return;
    existingData[date] = dayData;

    root[reportKey] = {
      'timeStamp': existingEntry is Map
          ? existingEntry['timeStamp']
          : DateTime.now().millisecondsSinceEpoch,
      'data': existingData,
    };

    await prefs.setString(storageKey, jsonEncode({storageKey: root}));
  }

  Future<Map<String, dynamic>?> readSummaryReportData({
    required String userUuid,
    required String projectId,
    required int cycleIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final root = _readRoot(prefs);
    final reportKey = _buildReportKey(
      userUuid: userUuid,
      projectId: projectId,
      cycleIndex: cycleIndex,
    );

    final entry = root[reportKey];
    if (entry is! Map) return null;

    return Map<String, dynamic>.from(entry);
  }

  Future<Map<String, dynamic>> readAllSummaryReportData() async {
    final prefs = await SharedPreferences.getInstance();
    return {storageKey: _readRoot(prefs)};
  }

  Future<void> clearSummaryReportData() async {
    final prefs = await SharedPreferences.getInstance();
    final root = _readRoot(prefs)..clear();
    await prefs.setString(storageKey, jsonEncode({storageKey: root}));
  }

  Map<String, dynamic> _readRoot(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final root = decoded[storageKey];
      if (root is Map) {
        return Map<String, dynamic>.from(root);
      }
      return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
  }

  String _buildReportKey({
    required String userUuid,
    required String projectId,
    required int cycleIndex,
  }) {
    return '${userUuid}_${projectId}_$cycleIndex';
  }
}
