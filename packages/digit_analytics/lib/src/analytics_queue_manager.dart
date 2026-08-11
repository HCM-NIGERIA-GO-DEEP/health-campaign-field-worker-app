import 'dart:convert';

import 'package:isar/isar.dart';

import 'analytics_event.dart';

/// Durable local queue for analytics events. Mirrors the shape of
/// `OpLogManager` (persist-then-flush, retry with backoff, give up after a
/// max retry count) without any of the entity/REST-sync specific concerns.
class AnalyticsQueueManager {
  final Isar isar;

  const AnalyticsQueueManager(this.isar);

  Future<void> queueEvent(
    String name,
    Map<String, dynamic> params, {
    String? userId,
    required DateTime occurredAt,
  }) async {
    final event = AnalyticsEvent()
      ..name = name
      ..paramsJson = jsonEncode(params)
      ..occurredAt = occurredAt
      ..userId = userId
      ..syncedUp = false
      ..retryCount = 0
      ..nonRecoverableError = false
      ..createdAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.analyticsEvents.put(event);
    });
  }

  Future<List<AnalyticsEvent>> getPendingEvents({int limit = 50}) {
    return isar.analyticsEvents
        .filter()
        .syncedUpEqualTo(false)
        .nonRecoverableErrorEqualTo(false)
        .sortByCreatedAt()
        .limit(limit)
        .findAll();
  }

  /// Params decoded from `AnalyticsEvent.paramsJson`.
  Map<String, dynamic> decodeParams(AnalyticsEvent event) {
    return Map<String, dynamic>.from(jsonDecode(event.paramsJson) as Map);
  }

  Future<void> markSynced(Id id) async {
    final event = await isar.analyticsEvents.get(id);
    if (event == null) return;

    event
      ..syncedUp = true
      ..syncedUpOn = DateTime.now();

    await isar.writeTxn(() async {
      await isar.analyticsEvents.put(event);
    });
  }

  /// Increments the retry count for a failed flush attempt, marking the
  /// event non-recoverable (so it's dropped from future flushes) once
  /// [maxRetries] is exceeded.
  Future<void> markFailed(Id id, {required int maxRetries}) async {
    final event = await isar.analyticsEvents.get(id);
    if (event == null) return;

    event.retryCount += 1;
    if (event.retryCount >= maxRetries) {
      event.nonRecoverableError = true;
    }

    await isar.writeTxn(() async {
      await isar.analyticsEvents.put(event);
    });
  }
}
