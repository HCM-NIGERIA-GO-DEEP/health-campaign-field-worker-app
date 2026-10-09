import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> config;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  List<Map<String, dynamic>> flows() =>
      (config['flows'] as List).cast<Map<String, dynamic>>();

  test('beneficiary ID search is only visible to Distributors', () {
    final search =
        flows().firstWhere((flow) => flow['name'] == 'searchBeneficiary');
    final widget = (search['body'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['fieldName'] == 'beneficiaryIdSearch');

    expect(widget['visible'], "{{fn:hasRole('DISTRIBUTOR')}} == true");
  });

  test('household phone is optional but validates a supplied number', () {
    final householdFlow =
        flows().firstWhere((flow) => flow['name'] == 'HOUSEHOLD');
    final detailsPage = (householdFlow['pages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((page) => page['page'] == 'householdDetails');
    final phone = (detailsPage['properties'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((field) => field['fieldName'] == 'phone');
    final validations =
        (phone['validations'] as List).cast<Map<String, dynamic>>();

    expect(phone['required'], isFalse);
    expect(phone['mandatory'], isFalse);
    expect(validations.any((rule) => rule['type'] == 'required'), isFalse);
    expect(validations.any((rule) => rule['type'] == 'pattern'), isTrue);
  });
}
