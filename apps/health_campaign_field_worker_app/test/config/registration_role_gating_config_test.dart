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

  test(
      'registerNewBeneficiary (searchBeneficiary footer) is hidden from Distributor',
      () {
    final search = flows().firstWhere((f) => f['name'] == 'searchBeneficiary');
    final btn = (search['footer'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'registerNewBeneficiary');

    expect(btn['visible'], "{{fn:hasRole('REGISTRAR')}} == true");
  });

  test(
      'Register New Beneficiary on the post-delivery preview is hidden from Distributor',
      () {
    final preview = flows().firstWhere((f) => f['name'] == 'previewScreen');
    final btn = (preview['footer'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'registerBeneficiary');

    expect(btn['visible'], "{{fn:hasRole('REGISTRAR')}} == true");
  });

  test(
      'registerBeneficiary (householdOverview footer, the Deliver ITN entry point) is hidden from Registrar',
      () {
    final householdOverview =
        flows().firstWhere((f) => f['name'] == 'householdOverview');
    final deliverBtn = (householdOverview['footer'] as List)
        .cast<Map<String, dynamic>>()
        .first;

    expect(deliverBtn['fieldName'], 'registerBeneficiary');
    expect(deliverBtn['visible'], "{{fn:hasRole('REGISTRAR')}} == false");
  });
}
