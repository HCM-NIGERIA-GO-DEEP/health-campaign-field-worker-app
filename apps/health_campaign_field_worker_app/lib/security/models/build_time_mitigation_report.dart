import 'app_security_feature.dart';

/// Result of comparing declared build-time mitigations against the APK.
class BuildTimeMitigationReport {
  /// Declared features that are genuinely present in this build.
  final Set<AppSecurityFeature> satisfied;

  /// Declared features that are **not** applied in this build, with why.
  final Map<AppSecurityFeature, String> violations;

  const BuildTimeMitigationReport({
    required this.satisfied,
    required this.violations,
  });

  static const BuildTimeMitigationReport nothingDeclared =
      BuildTimeMitigationReport(satisfied: {}, violations: {});

  bool get isSatisfied => violations.isEmpty;

  @override
  String toString() => isSatisfied
      ? 'BuildTimeMitigationReport(all ${satisfied.length} satisfied)'
      : 'BuildTimeMitigationReport(violations: '
          '${violations.entries.map((e) => '${e.key.label}: ${e.value}').join('; ')})';
}
