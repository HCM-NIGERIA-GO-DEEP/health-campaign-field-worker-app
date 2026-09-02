import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';

import '../app_security.dart';
import '../models/app_security_feature.dart';
import '../models/security_check_result.dart';
import '../models/security_threat_type.dart';
import 'known_indicators.dart';
import 'native_integrity_checks.dart';
import 'threat_response.dart';

/// Runs the device-integrity checks.
///
/// Detection only: it decides *what is true about the device*, never what to do
/// about it. Reacting is [ThreatResponseHandler]'s job, and whether to react at
/// all is `AppSecurity`'s.
class DeviceIntegrityService {
  static final DeviceIntegrityService instance = DeviceIntegrityService._();

  DeviceIntegrityService._();

  factory DeviceIntegrityService() => instance;

  final NativeIntegrityChecks _native = const NativeIntegrityChecks();
  final ThreatResponseHandler _responseHandler = ThreatResponseHandler();

  Timer? _periodicTimer;
  SecurityCheckResult? _lastResult;

  /// Most recent pass, or null if none has run.
  SecurityCheckResult? get lastResult => _lastResult;

  /// True once a pass has confirmed a threat. Consult this to degrade
  /// functionality under [ThreatResponseMode.restrict].
  bool get isSecurityCompromised => _responseHandler.isCompromised;

  bool get isMonitoring => _periodicTimer != null;

  /// Runs every selected check once and returns what was found.
  ///
  /// Each layer runs only if its feature is selected, so callers can pick
  /// exactly which checks apply. A check that cannot execute is recorded in
  /// [SecurityCheckResult.unavailableChecks] rather than counted as a threat.
  Future<SecurityCheckResult> runChecks() async {
    final security = AppSecurity.instance;
    final threats = <SecurityThreatType>[];
    final unavailable = <String>[];

    if (security.isEnabled(AppSecurityFeature.rootDetection)) {
      await _runRootChecks(threats, unavailable);
    }

    if (security.isEnabled(AppSecurityFeature.emulatorDetection)) {
      await _record(
        name: 'emulator',
        probe: _native.checkEmulator,
        threat: SecurityThreatType.emulator,
        threats: threats,
        unavailable: unavailable,
      );
    }

    if (security.isEnabled(AppSecurityFeature.hookDetection)) {
      await _runHookChecks(threats, unavailable);
    }

    // A debugger is expected in a debug build, so the check is meaningless
    // there rather than unavailable.
    if (security.isEnabled(AppSecurityFeature.debuggerDetection) &&
        !kDebugMode) {
      await _record(
        name: 'debugger',
        probe: _native.checkDebugger,
        threat: SecurityThreatType.debugger,
        threats: threats,
        unavailable: unavailable,
      );
    }

    if (security.isEnabled(AppSecurityFeature.repackagingDetection)) {
      await _runRepackagingCheck(threats, unavailable);
    }

    final result = SecurityCheckResult(
      threats: threats,
      unavailableChecks: unavailable,
      timestamp: DateTime.now(),
    );
    _lastResult = result;

    return result;
  }

  /// Runs one pass and applies the configured response if a threat is found.
  Future<SecurityCheckResult> runChecksAndRespond() async {
    final result = await runChecks();

    if (result.unavailableChecks.isNotEmpty) {
      // Visibility only. An unrunnable check is not evidence of tampering, and
      // escalating it would let a plugin failure terminate the app.
      debugPrint(
        'Security checks unavailable: ${result.unavailableChecks.join(', ')}',
      );
    }

    if (!result.isPassed && AppSecurity.instance.isEnforcementEnabled) {
      _responseHandler.apply(result, AppSecurity.instance.threatResponse);
    }

    return result;
  }

  /// Starts periodic re-checks to catch tampering that begins after launch.
  ///
  /// The first pass is deliberately not awaited: startup must not block on
  /// method channel round trips.
  void startMonitoring({Duration interval = const Duration(minutes: 5)}) {
    if (!AppSecurity.instance.isDeviceIntegrityEnabled) return;
    if (!AppSecurity.instance.isEnforcementEnabled) return;

    _periodicTimer?.cancel();
    runChecksAndRespond();
    _periodicTimer = Timer.periodic(interval, (_) => runChecksAndRespond());
  }

  /// Stops the timer started by [startMonitoring].
  void stopMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // ---- layers ----------------------------------------------------------

  Future<void> _runRootChecks(
    List<SecurityThreatType> threats,
    List<String> unavailable,
  ) async {
    var detected = false;
    var ranSomething = false;

    // Layer 1: library-based detection.
    try {
      final issues = await JailbreakRootDetection.instance.checkForIssues;
      ranSomething = true;
      if (issues.isNotEmpty) detected = true;
    } catch (e) {
      // Previously this added an `unknown` threat, which meant a plugin
      // failure on an unsupported device terminated the app in production.
      // It is an observability gap, so record it as such.
      debugPrint('Root detection library unavailable: $e');
    }

    // Layer 2: native probing.
    if (!detected && Platform.isAndroid) {
      final native = await _native.checkRootAccess();
      if (native != null) {
        ranSomething = true;
        if (native) detected = true;
      } else if (await _anyPathExists(KnownIndicators.rootPaths)) {
        // Dart fallback, for a stripped or unreachable native library.
        ranSomething = true;
        detected = true;
      }
    }

    if (detected) {
      threats.add(SecurityThreatType.root);
    } else if (!ranSomething) {
      unavailable.add('root');
    }
  }

  Future<void> _runHookChecks(
    List<SecurityThreatType> threats,
    List<String> unavailable,
  ) async {
    if (!Platform.isAndroid) return;

    final native = await _native.checkHookingFrameworks();
    if (native == true) {
      threats.add(SecurityThreatType.hook);
      return;
    }
    if (native == false) return;

    // Native unavailable: fall back to the Dart indicator list.
    if (await _anyPathExists(KnownIndicators.hookPaths)) {
      threats.add(SecurityThreatType.hook);
    } else {
      unavailable.add('hook');
    }
  }

  Future<void> _runRepackagingCheck(
    List<SecurityThreatType> threats,
    List<String> unavailable,
  ) async {
    final expected = AppSecurity.instance.expectedAppSignature;
    if (expected == null) {
      // Nothing to compare against, so this layer cannot conclude anything.
      unavailable.add('repackaging (no expected signature configured)');
      return;
    }

    final matches = await _native.checkAppSignature(expected);
    if (matches == null) {
      unavailable.add('repackaging');
    } else if (!matches) {
      threats.add(SecurityThreatType.repackaging);
    }
  }

  Future<void> _record({
    required String name,
    required Future<bool?> Function() probe,
    required SecurityThreatType threat,
    required List<SecurityThreatType> threats,
    required List<String> unavailable,
  }) async {
    if (!Platform.isAndroid) return;

    final outcome = await probe();
    if (outcome == null) {
      unavailable.add(name);
    } else if (outcome) {
      threats.add(threat);
    }
  }

  Future<bool> _anyPathExists(List<String> paths) async {
    for (final path in paths) {
      try {
        if (await File(path).exists()) return true;
      } catch (_) {
        // Unreadable path tells us nothing; keep going.
      }
    }
    return false;
  }
}
