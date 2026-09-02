/// App security: device integrity, certificate pinning and verification of the
/// mitigations that are decided at build time.
///
/// Layout:
/// * `app_security.dart` — orchestrator; selects features, owns policy.
/// * `models/` — features, levels, results, reports.
/// * `channel/` — the single native channel definition.
/// * `integrity/` — detection, native transport, threat response.
/// * `network/` — certificate pinning.
/// * `audit/` — verification of build-time mitigations.
library security;

export 'app_security.dart';
export 'audit/build_configuration_audit.dart';
export 'integrity/device_integrity_service.dart';
export 'integrity/native_integrity_checks.dart';
export 'integrity/threat_response.dart';
export 'models/app_security_feature.dart';
export 'models/app_security_level.dart';
export 'models/build_time_mitigation_report.dart';
export 'models/security_check_result.dart';
export 'models/security_threat_type.dart';
export 'network/ssl_pinning.dart';
