import 'package:flutter/foundation.dart';

import '../channel/security_channel.dart';

/// Thin transport over the native security channel.
///
/// Every method returns `null` to mean **the check could not run** — the
/// channel was unreachable, the plugin was not registered, or the platform is
/// not supported. That is deliberately distinct from `false` ("ran, found
/// nothing"), so callers can report a gap instead of inferring a threat from
/// an infrastructure failure.
class NativeIntegrityChecks {
  const NativeIntegrityChecks();

  Future<bool?> checkRootAccess() => _invoke('checkRootAccess');

  Future<bool?> checkEmulator() => _invoke('checkEmulator');

  Future<bool?> checkHookingFrameworks() => _invoke('checkHookingFrameworks');

  Future<bool?> checkDebugger() => _invoke('checkDebugger');

  /// Returns whether the signing certificate matches [expectedSignature].
  ///
  /// The native side reports `true` when [expectedSignature] is null, since it
  /// has nothing to compare against.
  Future<bool?> checkAppSignature(String? expectedSignature) => _invoke(
        'checkAppSignature',
        {'expectedSignature': expectedSignature},
      );

  Future<Map<String, dynamic>?> auditBuildConfiguration() async {
    try {
      return await securityChannel
          .invokeMapMethod<String, dynamic>('auditBuildConfiguration');
    } catch (e) {
      debugPrint('Native check auditBuildConfiguration unavailable: $e');
      return null;
    }
  }

  Future<bool?> _invoke(String method,
      [Map<String, dynamic>? arguments]) async {
    try {
      return await securityChannel.invokeMethod<bool>(method, arguments);
    } catch (e) {
      debugPrint('Native check $method unavailable: $e');
      return null;
    }
  }
}
