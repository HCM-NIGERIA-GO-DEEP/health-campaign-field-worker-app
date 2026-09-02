import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'security_threat_type.dart';

/// Outcome of one device-integrity pass.
class SecurityCheckResult {
  /// True when no [threats] were confirmed.
  ///
  /// Deliberately unaffected by [unavailableChecks]: a check that could not
  /// run is an observability gap, not evidence of tampering, and must not be
  /// escalated into one.
  final bool isPassed;

  /// Confirmed threats.
  final List<SecurityThreatType> threats;

  /// Names of checks that could not be executed, e.g. the native channel was
  /// unreachable. Reported so the gap is visible, never treated as a threat.
  final List<String> unavailableChecks;

  /// Deterministic digest of the confirmed threat set.
  ///
  /// Stable for the same set of threats, so a server can deduplicate repeat
  /// reports from one device. This is *not* an integrity proof — a value
  /// computed on a compromised client proves nothing.
  final String fingerprint;

  final DateTime timestamp;

  SecurityCheckResult({
    required this.threats,
    required this.timestamp,
    this.unavailableChecks = const <String>[],
  })  : isPassed = threats.isEmpty,
        fingerprint = _fingerprintOf(threats);

  static String _fingerprintOf(List<SecurityThreatType> threats) {
    // Sorted so ordering differences do not change the digest.
    final names = threats.map((t) => t.name).toList()..sort();
    return sha256.convert(utf8.encode(names.join('|'))).toString();
  }

  Map<String, dynamic> toJson() => {
        'isPassed': isPassed,
        'threats': threats.map((t) => t.name).toList(),
        'unavailableChecks': unavailableChecks,
        'fingerprint': fingerprint,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() => 'SecurityCheckResult(${toJson()})';
}
