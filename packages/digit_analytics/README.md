# Digit Analytics

digit_analytics is a vendor-agnostic offline queue for analytics events. Events are persisted
locally as soon as they happen and are only pushed to an analytics backend once the device is
online, so events survive extended offline periods without relying on a vendor SDK's own local
buffering. It has no dependency on Firebase or any other analytics vendor — the actual push to a
backend is done by the app itself, keeping this package reusable regardless of which analytics
provider is used.

It is kept separate from the `OpLog`/`SyncService` pipeline used for business-entity sync, so
analytics traffic never affects the "records pending sync" counter or its retry/backoff state.

## Features

- Durable local queue (Isar) for analytics events that survives app restarts.
- Retry with a max-attempts cutoff for events that repeatedly fail to send.
- App-wide `AnalyticsService.instance.logEvent(...)` entry point usable from any package.
- No dependency on any analytics vendor SDK.

## Getting started

```yaml
dependencies:
  digit_analytics: ^0.0.1
```

At app startup, once Isar is open, configure the singleton:

```dart
import 'package:digit_analytics/digit_analytics.dart';

AnalyticsSingleton().setData(isar: isar, enabled: enableAnalytics);
```

## Usage

```dart
import 'package:digit_analytics/digit_analytics.dart';

// `params` is sent verbatim to the analytics backend once flushed — do not
// put user-identifying data in it. `userId` is stored locally only, for
// on-device queue bookkeeping, and is never forwarded to the backend.
await AnalyticsService.instance.logEvent(
  'screen_view',
  {'screen_name': 'HouseholdDetailsRoute'},
  userId: userId,
);
```

Draining the queue and sending events to a backend is the app's responsibility. A typical flush
loop looks like:

```dart
final queueManager = AnalyticsSingleton().queueManager;
final pendingEvents = await queueManager!.getPendingEvents();
for (final event in pendingEvents) {
  try {
    final params = queueManager.decodeParams(event);
    await sendToAnalyticsBackend(name: event.name, parameters: {
      ...params,
      'occurred_at': event.occurredAt.toIso8601String(),
    });
    await queueManager.markSynced(event.id);
  } catch (_) {
    await queueManager.markFailed(event.id, maxRetries: 5);
  }
}
```

## Setting up with Firebase

`digit_analytics` only queues events — it has no Firebase dependency. To actually deliver queued
events to Firebase Analytics, pair it with
[`digit_firebase_services`](../digit_firebase_services), which wraps `firebase_analytics`.

1. **Initialize Firebase Analytics** alongside the rest of Firebase, gated by whatever feature
   flag controls analytics collection (e.g. a remote `enableAnalytics` config):

   ```dart
   import 'package:digit_analytics/digit_analytics.dart';
   import 'package:digit_firebase_services/digit_firebase_services.dart'
       as firebase_services;

   await firebase_services.initializeFirebaseCore(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   await firebase_services.initializeAnalytics(enabled: enableAnalytics);
   AnalyticsSingleton().setData(isar: isar, enabled: enableAnalytics);
   ```

2. **Write a flush routine** that drains the queue and forwards each event to Firebase via
   `logFirebaseAnalyticsEvent`:

   ```dart
   Future<void> flushPendingEvents() async {
     final singleton = AnalyticsSingleton();
     final queueManager = singleton.queueManager;
     if (!singleton.enabled || queueManager == null) return;
     if (!await isOnline()) return;

     for (final event in await queueManager.getPendingEvents()) {
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
       } catch (_) {
         await queueManager.markFailed(event.id, maxRetries: maxRetries);
       }
     }
   }
   ```

3. **Call the flush routine from your existing sync triggers** — a connectivity-restored
   listener, a manual "sync now" action, and/or a periodic background service — rather than on a
   dedicated timer of its own. Since the queue is separate from any business-entity sync
   pipeline, this flush can run independently without affecting other sync state.

   If the flush runs inside a background isolate, remember `AnalyticsSingleton` is a
   per-isolate singleton — call `AnalyticsSingleton().setData(...)` once inside that isolate too,
   even if Isar itself is already open.

## Additional information

Part of the `health-campaign-field-worker-app` monorepo. File issues against that repository.
