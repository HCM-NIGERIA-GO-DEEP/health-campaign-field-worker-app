import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:digit_analytics/digit_analytics.dart';
import 'package:digit_firebase_services/digit_firebase_services.dart'
    as firebase_services;
import 'package:digit_ui_components/utils/app_logger.dart';

import 'environment_config.dart';

/// Flushes queued analytics events (see `digit_analytics`) to Firebase
/// Analytics once the device is online. Kept independent of `SyncService`/
/// `SyncBloc` so analytics traffic never affects the oplog "records pending
/// sync" counter or its retry/backoff state machine.
class AnalyticsSyncService {
  static final AnalyticsSyncService _instance = AnalyticsSyncService._();

  factory AnalyticsSyncService() => _instance;

  AnalyticsSyncService._();

  bool _isFlushing = false;

  Future<void> flushPendingEvents() async {
    if (_isFlushing) return;

    final singleton = AnalyticsSingleton();
    final queueManager = singleton.queueManager;
    if (!singleton.enabled || queueManager == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);
    if (!isOnline) return;

    _isFlushing = true;
    try {
      final pendingEvents = await queueManager.getPendingEvents();
      for (final event in pendingEvents) {
        try {
          final params = queueManager.decodeParams(event);
          await firebase_services.logFirebaseAnalyticsEvent(
            name: event.name,
            parameters: {
              ...params,
              'occurred_at': event.occurredAt.toIso8601String(),
            },
          );
          await queueManager.markSynced(event.id);
        } catch (e) {
          AppLogger.instance.error(
            title: 'ANALYTICS_SYNC',
            message: 'Failed to sync analytics event ${event.name}: $e',
          );
          await queueManager.markFailed(
            event.id,
            maxRetries: envConfig.variables.syncDownRetryCount,
          );
        }
      }

      await queueManager.purgeOldEvents();
    } finally {
      _isFlushing = false;
    }
  }
}
