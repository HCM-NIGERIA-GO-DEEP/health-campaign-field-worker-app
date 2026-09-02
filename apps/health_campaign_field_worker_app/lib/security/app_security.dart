import 'package:flutter/foundation.dart';

import '../utils/environment_config.dart';
import 'audit/build_configuration_audit.dart';
import 'integrity/device_integrity_service.dart';
import 'integrity/threat_response.dart';
import 'models/app_security_feature.dart';
import 'models/app_security_level.dart';
import 'models/build_time_mitigation_report.dart';

/// Entry point for app security: selects which mitigations this build runs and
/// starts the runtime-enforceable ones.
///
/// Orchestration only. Detection lives in [DeviceIntegrityService], reacting to
/// a threat in [ThreatResponseHandler], and build verification in
/// [BuildConfigurationAudit].
class AppSecurity {
  static final AppSecurity instance = AppSecurity._();

  AppSecurity._();

  factory AppSecurity() => instance;

  /// Feature sets behind each [AppSecurityLevel].
  ///
  /// These preserve the behaviour the levels had before features became
  /// selectable: `low` selects nothing and leaves pinning off, `medium`
  /// suppresses release logs and pins TLS, `high` enables everything.
  static const Map<AppSecurityLevel, Set<AppSecurityFeature>> levelPresets = {
    AppSecurityLevel.low: <AppSecurityFeature>{},
    AppSecurityLevel.medium: <AppSecurityFeature>{
      AppSecurityFeature.debugPrintSuppression,
      AppSecurityFeature.sslPinning,
    },
    AppSecurityLevel.high: <AppSecurityFeature>{
      AppSecurityFeature.debugPrintSuppression,
      AppSecurityFeature.sslPinning,
      AppSecurityFeature.rootDetection,
      AppSecurityFeature.emulatorDetection,
      AppSecurityFeature.hookDetection,
      AppSecurityFeature.debuggerDetection,
      AppSecurityFeature.repackagingDetection,
      AppSecurityFeature.codeObfuscation,
      AppSecurityFeature.broadcastReceiverHardening,
      AppSecurityFeature.platformUsageHardening,
    },
    AppSecurityLevel.custom: <AppSecurityFeature>{},
  };

  AppSecurityLevel securityLevel = AppSecurityLevel.low;

  final Set<AppSecurityFeature> _enabledFeatures = <AppSecurityFeature>{};

  /// How to react when a check confirms a threat. Defaults to terminating the
  /// process, which is the behaviour this app has always had.
  ThreatResponse threatResponse = const ThreatResponse();

  /// Release-keystore signing certificate, required before
  /// [AppSecurityFeature.repackagingDetection] can conclude anything.
  String? expectedAppSignature;

  Duration checkInterval = const Duration(minutes: 5);

  /// Result of the most recent [verifyBuildTimeMitigations] call.
  ///
  /// Kept as state on purpose: [AppSecurityFeature.debugPrintSuppression]
  /// silences `debugPrint`, and `AppLogger` writes through it, so in a hardened
  /// release build the audit log is invisible. Read this instead of the log.
  BuildTimeMitigationReport? lastBuildTimeReport;

  final BuildConfigurationAudit _buildAudit = const BuildConfigurationAudit();

  /// Overrides the production-only default for threat enforcement. Leave null
  /// to enforce in production builds only.
  bool? enforcementOverride;

  Set<AppSecurityFeature> get enabledFeatures =>
      Set<AppSecurityFeature>.unmodifiable(_enabledFeatures);

  bool isEnabled(AppSecurityFeature feature) =>
      _enabledFeatures.contains(feature);

  /// True when at least one device-integrity check is selected.
  bool get isDeviceIntegrityEnabled =>
      _enabledFeatures.any(deviceIntegrityFeatures.contains);

  /// Whether a confirmed threat should trigger [threatResponse].
  ///
  /// Production-only by default, matching the original behaviour. Reading
  /// `envConfig.variables` throws before `initialize()` has run, so this is
  /// guarded — an uninitialised environment is never production, making
  /// `false` the correct answer rather than a crash.
  bool get isEnforcementEnabled {
    if (enforcementOverride != null) return enforcementOverride!;
    try {
      return envConfig.variables.envType == EnvType.prod;
    } catch (_) {
      return false;
    }
  }

  /// Selects security features and applies the runtime-enforceable ones.
  ///
  /// ```dart
  /// // preset
  /// AppSecurity.instance.configure(level: AppSecurityLevel.high);
  ///
  /// // pick exactly what you want
  /// AppSecurity.instance.configure(features: {
  ///   AppSecurityFeature.sslPinning,
  ///   AppSecurityFeature.rootDetection,
  /// });
  ///
  /// // preset, minus one check
  /// AppSecurity.instance.configure(
  ///   level: AppSecurityLevel.high,
  ///   disable: {AppSecurityFeature.emulatorDetection},
  /// );
  /// ```
  ///
  /// Safe to call before `envConfig.initialize()`; enforcement is resolved
  /// lazily via [isEnforcementEnabled].
  void configure({
    AppSecurityLevel? level,
    Set<AppSecurityFeature>? features,
    Set<AppSecurityFeature> disable = const <AppSecurityFeature>{},
    ThreatResponse? threatResponse,
    String? expectedAppSignature,
    Duration? checkInterval,
    bool? enforcementOverride,
  }) {
    assert(
      level != null || features != null,
      'configure() needs either a level or an explicit feature set',
    );

    _enabledFeatures.clear();

    if (level != null) {
      securityLevel = level;
      _enabledFeatures.addAll(levelPresets[level] ?? const {});
    }

    if (features != null) {
      // An explicit set wins over the preset, and marks the config custom.
      _enabledFeatures
        ..clear()
        ..addAll(features);
      securityLevel = AppSecurityLevel.custom;
    }

    if (disable.isNotEmpty) {
      _enabledFeatures.removeAll(disable);
      securityLevel = AppSecurityLevel.custom;
    }

    if (threatResponse != null) this.threatResponse = threatResponse;
    if (expectedAppSignature != null) {
      this.expectedAppSignature = expectedAppSignature;
    }
    if (checkInterval != null) this.checkInterval = checkInterval;
    if (enforcementOverride != null) {
      this.enforcementOverride = enforcementOverride;
    }

    _applyRuntimeFeatures();
  }

  /// Turns one feature on. Only meaningful for runtime-enforced features, and
  /// only before the relevant subsystem has started.
  void enable(AppSecurityFeature feature) {
    if (_enabledFeatures.add(feature)) {
      securityLevel = AppSecurityLevel.custom;
      _applyRuntimeFeatures();
    }
  }

  /// Turns one feature off.
  ///
  /// This cannot undo an already-applied one-way action: `debugPrint` stays
  /// suppressed once suppressed, and an already-pinned Dio client stays pinned
  /// until `DioClient.disableSSLPinning()` is called.
  void disable(AppSecurityFeature feature) {
    if (_enabledFeatures.remove(feature)) {
      securityLevel = AppSecurityLevel.custom;
      if (!isDeviceIntegrityEnabled) {
        DeviceIntegrityService.instance.stopMonitoring();
      }
    }
  }

  void _applyRuntimeFeatures() {
    if (isEnabled(AppSecurityFeature.debugPrintSuppression)) {
      removeDebugPrints();
    }

    if (isDeviceIntegrityEnabled) {
      DeviceIntegrityService.instance.startMonitoring(interval: checkInterval);
    } else {
      DeviceIntegrityService.instance.stopMonitoring();
    }
  }

  /// Verifies the selected build-time features against this APK.
  ///
  /// Returns null when the native side is unavailable.
  Future<BuildTimeMitigationReport?> verifyBuildTimeMitigations() async {
    final report = await _buildAudit.run(enabledFeatures);
    if (report != null) lastBuildTimeReport = report;

    return report;
  }

  void removeDebugPrints() {
    if (!kDebugMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  }

  /// Kept for source compatibility with the previous coarse API.
  @Deprecated('Use configure(level: ...) or configure(features: {...})')
  set setSecurityLevel(AppSecurityLevel level) => configure(level: level);
}
