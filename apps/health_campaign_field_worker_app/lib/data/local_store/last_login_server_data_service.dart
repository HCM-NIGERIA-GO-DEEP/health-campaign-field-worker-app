import 'dart:convert';

import 'package:health_campaign_field_worker_app/data/local_store/app_shared_preferences.dart';

class LastLoginServerDataService {
  static const String _storageKey = 'lastLoginServerData';

  static final LastLoginServerDataService _instance =
      LastLoginServerDataService._internal();

  factory LastLoginServerDataService() {
    return _instance;
  }

  LastLoginServerDataService._internal();

  Map<String, dynamic> _readRoot() {
    final raw = AppSharedPreferences().sharedPreferences.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return {'lastLoginServerData': <String, dynamic>{}};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall back to an empty map when corrupted payload is found.
    }

    return {'lastLoginServerData': <String, dynamic>{}};
  }

  Future<void> _writeRoot(Map<String, dynamic> root) async {
    await AppSharedPreferences()
        .sharedPreferences
        .setString(_storageKey, jsonEncode(root));
  }

  Future<void> storeUserCycleData({
    required String userIdCycleIndex,
    required int timeStamp,
    required Map<String, dynamic> data,
  }) async {
    final root = _readRoot();
    final payload =
        (root['lastLoginServerData'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

    payload[userIdCycleIndex] = {
      'timeStamp': timeStamp,
      'data': data,
    };

    root['lastLoginServerData'] = payload;
    await _writeRoot(root);
  }

  Future<void> storeDateMetrics({
    required String userIdCycleIndex,
    required String date,
    required int householdsRegistered,
    required int childrenTreated,
    required int childrenRegistered,
    required Map<String, int> stockConsumedMap,
  }) async {
    final root = _readRoot();
    final payload =
        (root['lastLoginServerData'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

    final userCycleMap =
        (payload[userIdCycleIndex] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

    final dataMap = (userCycleMap['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    dataMap[date] = {
      'householdsRegistered': householdsRegistered,
      'childrenTreated': childrenTreated,
      'childrenRegistered': childrenRegistered,
      'stockConsumedMap': stockConsumedMap,
    };

    userCycleMap['timeStamp'] = DateTime.now().millisecondsSinceEpoch;
    userCycleMap['data'] = dataMap;

    payload[userIdCycleIndex] = userCycleMap;
    root['lastLoginServerData'] = payload;

    await _writeRoot(root);
  }

  Map<String, dynamic> get lastLoginServerData {
    final root = _readRoot();
    return (root['lastLoginServerData'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }

  int getHouseholdsRegistered({
    required String userIdCycleIndex,
    required String date,
  }) {
    final dateData =
        _getDateData(userIdCycleIndex: userIdCycleIndex, date: date);
    return (dateData['householdsRegistered'] as num?)?.toInt() ?? 0;
  }

  int getChildrenTreated({
    required String userIdCycleIndex,
    required String date,
  }) {
    final dateData =
        _getDateData(userIdCycleIndex: userIdCycleIndex, date: date);
    return (dateData['childrenTreated'] as num?)?.toInt() ?? 0;
  }

  int getChildrenRegistered({
    required String userIdCycleIndex,
    required String date,
  }) {
    final dateData =
        _getDateData(userIdCycleIndex: userIdCycleIndex, date: date);
    return (dateData['childrenRegistered'] as num?)?.toInt() ?? 0;
  }

  Map<String, int> getStockConsumedMap({
    required String userIdCycleIndex,
    required String date,
  }) {
    final dateData =
        _getDateData(userIdCycleIndex: userIdCycleIndex, date: date);
    return (dateData['stockConsumedMap'] as Map?)?.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num?)?.toInt() ?? 0,
          ),
        ) ??
        <String, int>{};
  }

  Map<String, dynamic> _getDateData({
    required String userIdCycleIndex,
    required String date,
  }) {
    final userCycleData = (lastLoginServerData[userIdCycleIndex] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final dateMap = (userCycleData['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    return (dateMap[date] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }
}
