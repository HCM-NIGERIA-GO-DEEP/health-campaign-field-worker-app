library digit_firebase_services;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

export './crash_button.dart';

Future initializeFirebaseCore({
  required FirebaseOptions options,
}) async {
  await Firebase.initializeApp(options: options);
}

Future initializeAnalytics({
  required bool enabled,
}) async {
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
}

/// Thin wrapper over `FirebaseAnalytics.instance.logEvent`, kept here so
/// callers don't need a direct dependency on `firebase_analytics`.
Future logFirebaseAnalyticsEvent({
  required String name,
  required Map<String, Object?> parameters,
}) async {
  await FirebaseAnalytics.instance.logEvent(
    name: name,
    parameters: parameters,
  );
}

Future initializeCrashlytics({
  ValueChanged<String>? onErrorMessage,
}) async {
  FlutterError.onError = (errorDetails) {
    onErrorMessage?.call(
      'Diagnostic node: '
      '${errorDetails.summary.name.toString()}',
    );
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    onErrorMessage?.call(error.toString());
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
