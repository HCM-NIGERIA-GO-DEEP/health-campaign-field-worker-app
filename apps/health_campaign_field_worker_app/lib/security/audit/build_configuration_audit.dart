import '../integrity/native_integrity_checks.dart';
import '../models/app_security_feature.dart';
import '../models/build_time_mitigation_report.dart';

/// Checks declared build-time mitigations against what the APK shipped with.
///
/// Dart cannot enable obfuscation or change the manifest, so declaring those
/// features only states intent. This turns a silently unhardened build into a
/// detectable one.
class BuildConfigurationAudit {
  final NativeIntegrityChecks _native;

  const BuildConfigurationAudit({
    NativeIntegrityChecks native = const NativeIntegrityChecks(),
  }) : _native = native;

  /// Returns null when the native side is unavailable, so callers can tell
  /// "not verifiable here" apart from "verified and wrong".
  Future<BuildTimeMitigationReport?> run(
    Set<AppSecurityFeature> declaredFeatures,
  ) async {
    final declared = declaredFeatures.intersection(buildTimeFeatures);
    if (declared.isEmpty) return BuildTimeMitigationReport.nothingDeclared;

    final audit = await _native.auditBuildConfiguration();
    if (audit == null) return null;

    final satisfied = <AppSecurityFeature>{};
    final violations = <AppSecurityFeature, String>{};

    void check(AppSecurityFeature feature, bool ok, String reason) {
      if (!declared.contains(feature)) return;
      if (ok) {
        satisfied.add(feature);
      } else {
        violations[feature] = reason;
      }
    }

    final isMinified = audit['isMinified'] as bool? ?? false;
    final isDebuggable = audit['isDebuggable'] as bool? ?? false;
    final allowsBackup = audit['allowsBackup'] as bool? ?? false;
    final cleartextPermitted =
        audit['cleartextTrafficPermitted'] as bool? ?? false;
    final exportedComponents =
        (audit['exportedComponents'] as List?)?.cast<String>() ??
            const <String>[];

    check(
      AppSecurityFeature.codeObfuscation,
      isMinified && !isDebuggable,
      isMinified
          ? 'build is debuggable'
          : 'minifyEnabled is false for this build type',
    );

    check(
      AppSecurityFeature.platformUsageHardening,
      !allowsBackup && !cleartextPermitted,
      allowsBackup
          ? 'android:allowBackup is true'
          : 'cleartext HTTP is permitted by the network security config',
    );

    check(
      AppSecurityFeature.broadcastReceiverHardening,
      exportedComponents.isEmpty,
      'unexpectedly exported components: ${exportedComponents.join(', ')}',
    );

    return BuildTimeMitigationReport(
      satisfied: satisfied,
      violations: violations,
    );
  }
}
