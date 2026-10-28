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
      // ServerSummaryReportService.recordBaselineIfDeviceHasNoLocalRows.
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
        if (previousMap['baselineHouseholdsRegistered'] != null)
          'baselineHouseholdsRegistered':
              previousMap['baselineHouseholdsRegistered'],
        if (previousMap['baselinePeopleInHouseholds'] != null)
          'baselinePeopleInHouseholds':
              previousMap['baselinePeopleInHouseholds'],
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
  /// Callers must only invoke this when the device holds NO local rows for
  /// [date], so the observed server counts cannot already include anything
  /// this device registered. Writes the minimum ever seen, so a later
  /// observation that has grown (because records landed) cannot raise it.
  Future<void> writeBaseline({
    required String userUuid,
    required String projectId,
    required int cycleIndex,
    required String date,
    required int households,
    required int people,
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

    int lowest(String key, int observed) {
      final stored = dayData[key];
      final storedInt = stored is num ? stored.toInt() : null;
      return storedInt == null || observed < storedInt ? observed : storedInt;
    }

    final nextHouseholds = lowest('baselineHouseholdsRegistered', households);
    final nextPeople = lowest('baselinePeopleInHouseholds', people);

    if (dayData['baselineHouseholdsRegistered'] == nextHouseholds &&
        dayData['baselinePeopleInHouseholds'] == nextPeople) {
      return;
    }

    dayData['baselineHouseholdsRegistered'] = nextHouseholds;
    dayData['baselinePeopleInHouseholds'] = nextPeople;
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
