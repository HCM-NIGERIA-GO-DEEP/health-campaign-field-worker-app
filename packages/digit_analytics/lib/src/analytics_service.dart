import 'package:isar/isar.dart';

import 'analytics_queue_manager.dart';

/// Holds the app-wide analytics configuration, mirroring the existing
/// `DigitDataModelSingleton`/`AttendanceSingleton` pattern used to configure
/// other cross-cutting packages from the app's startup sequence.
class AnalyticsSingleton {
  static final AnalyticsSingleton _instance = AnalyticsSingleton._();

  factory AnalyticsSingleton() => _instance;

  AnalyticsSingleton._();

  AnalyticsQueueManager? _queueManager;
  bool _enabled = false;

  void setData({required Isar isar, required bool enabled}) {
    _queueManager = AnalyticsQueueManager(isar);
    _enabled = enabled;
  }

  AnalyticsQueueManager? get queueManager => _queueManager;

  bool get enabled => _enabled;
}

/// Public entry point for instrumenting analytics events anywhere in the app
/// (or in any package) without depending on Firebase or any other vendor SDK.
///
/// Events are only ever persisted here; a separate app-layer flush process
/// reads the queue and sends events to the actual analytics backend once the
/// device is online.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();

  AnalyticsService._();

  /// [params] is sent verbatim to the analytics backend once flushed — do
  /// not put user-identifying data (uuid, name, phone, email, etc.) in it.
  /// [userId] is stored only in the local queue for on-device bookkeeping
  /// and is never forwarded to the backend.
  Future<void> logEvent(
    String name,
    Map<String, dynamic> params, {
    String? userId,
  }) async {
    final singleton = AnalyticsSingleton();
    if (!singleton.enabled) return;

    final queueManager = singleton.queueManager;
    if (queueManager == null) return;

    await queueManager.queueEvent(
      name,
      params,
      userId: userId,
      occurredAt: DateTime.now(),
    );
  }
}
