import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against a regression of a trailing-space typo in
/// "complaintRegistration"'s supervisorContactNumber path
/// ("complaintDetails.supervisorContactNumber " - note the space before the
/// closing quote). The dotted-path resolver does an exact map-key lookup per
/// segment, so that stray space meant the field never matched the actual
/// form field, silently saving null even when the field was filled in.
void main() {
  test('supervisorContactNumber path has no leading/trailing whitespace and matches the form field exactly', () {
    final config = jsonConfig['complaintRegistration'] as Map<String, dynamic>;
    final pgrService = config['models']['PgrServiceModel'] as Map<String, dynamic>;
    final additionalDetail =
        pgrService['mappings']['additionalDetail'] as Map<String, dynamic>;
    final path = additionalDetail['supervisorContactNumber'] as String;

    expect(path, 'complaintDetails.supervisorContactNumber');
    expect(path, path.trim());
  });

  test('every additionalDetail path in complaintRegistration is whitespace-trimmed', () {
    final config = jsonConfig['complaintRegistration'] as Map<String, dynamic>;
    final pgrService = config['models']['PgrServiceModel'] as Map<String, dynamic>;
    final additionalDetail =
        pgrService['mappings']['additionalDetail'] as Map<String, dynamic>;

    for (final entry in additionalDetail.entries) {
      final value = entry.value;
      if (value is String) {
        expect(value, value.trim(),
            reason: '${entry.key} has leading/trailing whitespace: "$value"');
      }
    }
  });
}
