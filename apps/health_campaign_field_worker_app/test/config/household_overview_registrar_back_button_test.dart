import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// householdOverview (the page shown right after registering a household)
/// hides its "Register Beneficiary" / deliver button from Registrars
/// (`hasRole('REGISTRAR') == false`), since only a Distributor delivers
/// ITNs. That left Registrars with no visible footer button at all - the
/// page already had a "back to search" link in the header, but nothing in
/// the footer to match. This adds a footer button, visible only to
/// Registrars, that does the same navigation as the existing header link.
void main() {
  late Map<String, dynamic> householdOverviewFlow;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();
    householdOverviewFlow =
        flows.firstWhere((f) => f['name'] == 'householdOverview');
  });

  test('registerBeneficiary button stays Distributor-only, unchanged', () {
    final footer =
        (householdOverviewFlow['footer'] as List).cast<Map<String, dynamic>>();
    final deliverButton =
        footer.firstWhere((b) => b['fieldName'] == 'registerBeneficiary');

    expect(deliverButton['visible'], "{{fn:hasRole('REGISTRAR')}} == false");
  });

  test('a Registrar-visible back-to-search button exists in the footer', () {
    final footer =
        (householdOverviewFlow['footer'] as List).cast<Map<String, dynamic>>();
    final backButton =
        footer.firstWhere((b) => b['fieldName'] == 'backToSearchRegistrar');

    expect(backButton['visible'], "{{fn:hasRole('REGISTRAR')}} == true");

    final navProps = (backButton['onAction'] as List)
        .cast<Map<String, dynamic>>()
        .first['properties'] as Map<String, dynamic>;
    expect(navProps['name'], 'searchBeneficiary');
  });
}
