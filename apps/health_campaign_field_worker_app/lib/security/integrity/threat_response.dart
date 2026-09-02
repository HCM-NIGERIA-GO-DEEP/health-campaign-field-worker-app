import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/security_check_result.dart';

/// What to do when a device-integrity pass confirms a threat.
enum ThreatResponseMode {
  /// Terminate the process. The behaviour this code has always had, kept as
  /// the default so restructuring cannot silently weaken it.
  exitApp,

  /// Keep running but mark the session compromised via
  /// [ThreatResponseHandler.isCompromised], leaving the reaction to the UI.
  restrict,

  /// Only notify [ThreatResponse.onThreat]. Useful for measuring how often
  /// checks fire in the field before switching on enforcement.
  reportOnly,
}

/// Called with every confirmed threat, before the mode is applied.
///
/// This is the extension point for server-side reporting, which matters
/// because client-side checks can always be bypassed. It replaces an empty
/// `reportSecurityStatusToServer` stub that never had an implementation.
typedef ThreatReporter = void Function(SecurityCheckResult result);

/// Policy for reacting to a confirmed threat.
class ThreatResponse {
  final ThreatResponseMode mode;
  final ThreatReporter? onThreat;

  const ThreatResponse({
    this.mode = ThreatResponseMode.exitApp,
    this.onThreat,
  });
}

/// Applies a [ThreatResponse]. Separated from detection so the decision to
/// terminate a field worker's app is one explicit, testable place rather than
/// a line buried in a detection utility.
class ThreatResponseHandler {
  bool _isCompromised = false;

  /// True once any pass has confirmed a threat.
  bool get isCompromised => _isCompromised;

  @visibleForTesting
  void reset() => _isCompromised = false;

  void apply(SecurityCheckResult result, ThreatResponse policy) {
    // NOTE: tools/security/test_root_detection.sh greps logcat for this exact
    // string. Keep it in sync if it ever changes.
    debugPrint('Security threat detected: ${result.toJson()}');

    // Set before any termination so `restrict` and `reportOnly` are reachable
    // and observers see the flag even on the exiting path.
    _isCompromised = true;

    policy.onThreat?.call(result);

    switch (policy.mode) {
      case ThreatResponseMode.exitApp:
        if (!kDebugMode) exit(0);
        break;
      case ThreatResponseMode.restrict:
      case ThreatResponseMode.reportOnly:
        break;
    }
  }
}
