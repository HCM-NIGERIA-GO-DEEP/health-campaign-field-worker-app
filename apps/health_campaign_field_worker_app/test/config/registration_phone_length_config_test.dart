import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// Guards the Household Details phone field length. It carried the Gombe
/// 11-digit rule, which rejects Sierra Leone numbers - those are 9 digits.
/// Both copies of the config are checked: the JSON asset that is uploaded to
/// MDMS, and `sampleFlows`, which home.dart passes as the
/// fallback the app renders when MDMS has not been fetched.
void main() {
  Map<String, dynamic> findPhoneField(dynamic node) {
    if (node is Map) {
      if (node['fieldName'] == 'phone' && node['validations'] != null) {
        return node.cast<String, dynamic>();
      }
      for (final value in node.values) {
        final found = findPhoneField(value);
        if (found.isNotEmpty) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = findPhoneField(value);
        if (found.isNotEmpty) return found;
      }
    }
    return const {};
  }

  void expectNineDigits(Map<String, dynamic> phoneField, String source) {
    final validations =
        (phoneField['validations'] as List).cast<Map<String, dynamic>>();
    final minLength = validations.firstWhere((v) => v['type'] == 'minLength');
    final maxLength = validations.firstWhere((v) => v['type'] == 'maxLength');
    final lengthRange = phoneField['lengthRange'] as Map<String, dynamic>;

    expect(minLength['value'], 9, reason: '$source minLength');
    expect(maxLength['value'], 9, reason: '$source maxLength');
    expect(lengthRange['minLength'], 9, reason: '$source lengthRange');
    expect(lengthRange['maxLength'], 9, reason: '$source lengthRange');

    // The message must name the length it enforces, otherwise a 9-digit
    // rejection still reads "must be 11 digits".
    expect(lengthRange['errorMessage'], 'MOBILE_LENGTH_9_DIGIT_ERROR');
    expect(minLength['message'], 'MOBILE_LENGTH_9_DIGIT_ERROR');
    expect(maxLength['message'], 'MOBILE_LENGTH_9_DIGIT_ERROR');
  }

  test('REGISTRATION.json phone requires exactly 9 digits', () {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    final config = jsonDecode(file.readAsStringSync());

    expectNineDigits(findPhoneField(config), 'REGISTRATION.json');
  });

  test('sampleFlows phone requires exactly 9 digits', () {
    expectNineDigits(
      findPhoneField(sampleFlows),
      'sampleFlows',
    );
  });
}
