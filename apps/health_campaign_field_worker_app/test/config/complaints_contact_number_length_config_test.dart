import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Complaints module's "Contact Number" field length. It was
/// fixed at exactly 10 digits, rejecting real 11-digit numbers with
/// "Mobile Length 10 Digit" - this matches the 11-digit length used
/// elsewhere in the app for mobile numbers (e.g. Household Details' own
/// phone field, MOBILE_LENGTH_11_DIGIT_ERROR).
void main() {
  late Map<String, dynamic> contactNumberField;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/COMPLAINTS.json',
    );
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();

    final allPages = flows
        .expand((f) => (f['pages'] as List? ?? []).cast<Map<String, dynamic>>())
        .toList();
    final page = allPages.firstWhere(
      (p) => (p['properties'] as List?)
              ?.any((w) => w is Map && w['fieldName'] == 'contactNumber') ==
          true,
    );
    final properties = (page['properties'] as List).cast<Map<String, dynamic>>();
    contactNumberField =
        properties.firstWhere((w) => w['fieldName'] == 'contactNumber');
  });

  test('Contact Number requires exactly 11 digits, not 10', () {
    final validations =
        (contactNumberField['validations'] as List).cast<Map<String, dynamic>>();
    final minLength = validations.firstWhere((v) => v['type'] == 'minLength');
    final maxLength = validations.firstWhere((v) => v['type'] == 'maxLength');

    expect(minLength['value'], 11);
    expect(maxLength['value'], 11);
  });
}
