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

  /// Deletes a single queued event, e.g. from a local db inspector screen.
  Future<void> deleteEvent(Id id) async {
    await isar.writeTxn(() async {
      await isar.analyticsEvents.delete(id);
    });
  }

  /// Deletes every queued event, synced or not.
  Future<void> deleteAll() async {
    await isar.writeTxn(() async {
      await isar.analyticsEvents.clear();
    });
  }

  /// Deletes terminal events that no longer need to stay in the local
  /// queue: successfully synced events older than [syncedRetention], and
  /// permanently-failed events older than [failedRetention]. Pending events
  /// (not yet synced, not yet given up on) are never touched.
  ///
  /// Safe to call on every flush pass — it only ever removes rows that are
  /// already done with (synced or given up on), keeping the queue from
  /// growing unbounded over the life of an install without losing the
  /// ability to debug recent sync activity.
  Future<int> purgeOldEvents({
    Duration syncedRetention = const Duration(days: 1),
    Duration failedRetention = const Duration(days: 30),
  }) async {
    final syncedCutoff = DateTime.now().subtract(syncedRetention);
    final failedCutoff = DateTime.now().subtract(failedRetention);

    return isar.writeTxn(() async {
      return isar.analyticsEvents
          .filter()
          .group((q) => q
              .syncedUpEqualTo(true)
              .and()
              .syncedUpOnLessThan(syncedCutoff))
          .or()
          .group((q) => q
              .nonRecoverableErrorEqualTo(true)
              .and()
              .createdAtLessThan(failedCutoff))
          .deleteAll();
    });
  }
}
