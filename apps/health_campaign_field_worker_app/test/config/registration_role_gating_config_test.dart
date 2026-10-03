import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural lint for the Registrar vs Distributor role separation in
/// REGISTRATION.json. Uses the existing, already-shipped `fn:hasRole(...)`
/// function (already proven in INVENTORY.json/STOCKREPORTS.json) to hide:
/// - the two "start a new registration" entry points from Distributor
/// - the one "proceed to deliver ITN" entry point from Registrar
///
/// Both gate on the ABSENCE of the other role, not the presence of one's
/// own, so a user with neither role (e.g. a Superuser) still sees both
/// buttons by default.
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

  test('registerNewBeneficiary (searchBeneficiary footer) is hidden from Distributor', () {
    final search = flows().firstWhere((f) => f['name'] == 'searchBeneficiary');
    final btn = (search['footer'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'registerNewBeneficiary');

    expect(btn['visible'], "{{fn:hasRole('DISTRIBUTOR')}} == false");
  });

  test('skip (insufficient-beneficiary-ID popup) is hidden from Distributor', () {
    final search = flows().firstWhere((f) => f['name'] == 'searchBeneficiary');
    final minCheck = (search['footer'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'beneficiaryIdMinCheck');
    final footerActions = (minCheck['properties']['popupConfig']['footerActions']
            as List)
        .cast<Map<String, dynamic>>();
    final skipBtn = footerActions.firstWhere((a) => a['fieldName'] == 'skip');

    expect(skipBtn['visible'], "{{fn:hasRole('DISTRIBUTOR')}} == false");
  });

  test('registerNewBeneficiary and skip share the same destination, so they must share the same gate', () {
    final search = flows().firstWhere((f) => f['name'] == 'searchBeneficiary');
    final btn = (search['footer'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'registerNewBeneficiary');
    final minCheck = (search['footer'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'beneficiaryIdMinCheck');
    final footerActions = (minCheck['properties']['popupConfig']['footerActions']
            as List)
        .cast<Map<String, dynamic>>();
    final skipBtn = footerActions.firstWhere((a) => a['fieldName'] == 'skip');

    expect(btn['visible'], skipBtn['visible']);
  });

  test('registerBeneficiary (householdOverview footer, the Deliver ITN entry point) is hidden from Registrar', () {
    final householdOverview =
        flows().firstWhere((f) => f['name'] == 'householdOverview');
    final deliverBtn =
        (householdOverview['footer'] as List).cast<Map<String, dynamic>>().first;

    expect(deliverBtn['fieldName'], 'registerBeneficiary');
    expect(deliverBtn['visible'], "{{fn:hasRole('REGISTRAR')}} == false");
  });
}
