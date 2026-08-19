import 'package:isar/isar.dart';

part 'analytics_event.g.dart';

/// A single queued analytics event, persisted locally before it is pushed to
/// an analytics backend. Kept separate from the app's business-entity `OpLog`
/// so analytics traffic never affects the "records pending sync" counter or
/// its retry/backoff semantics.
@Collection()
class AnalyticsEvent {
  Id id = Isar.autoIncrement;

  /// Analytics event name (e.g. `login`, `screen_view`).
  late String name;

  /// JSON-encoded `Map<String, dynamic>` of event parameters.
  late String paramsJson;

  /// The true client-side time the event occurred, independent of when it is
  /// eventually flushed to the analytics backend.
  late DateTime occurredAt;

  String? userId;

  late bool syncedUp;

  DateTime? syncedUpOn;

  late int retryCount;

  late bool nonRecoverableError;

  late DateTime createdAt;
}
