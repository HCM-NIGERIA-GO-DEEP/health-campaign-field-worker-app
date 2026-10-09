import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// householdOverview (the page shown right after registering a household)
/// hides its "Register Beneficiary" / deliver button from Registrars
/// (`hasRole('REGISTRAR') == false`), since only a Distributor delivers
/// ITNs. That left Registrars with no visible footer button at all - the
/// page already had a "back to search" link in the header, but Registrars
/// also need a footer action that clears this page and replaces the existing
/// search route with a fresh instance.
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

  test('registerBeneficiary button is visible only to Distributors', () {
    final footer =
        (householdOverviewFlow['footer'] as List).cast<Map<String, dynamic>>();
    final deliverButton =
        footer.firstWhere((b) => b['fieldName'] == 'registerBeneficiary');

    expect(deliverButton['visible'], "{{fn:hasRole('DISTRIBUTOR')}} == true");
  });

  test('member edit button is visible only to Registrars', () {
    final serialized = jsonEncode(householdOverviewFlow);
    final decoded = jsonDecode(serialized);

    Map<String, dynamic>? findByFieldName(dynamic node, String fieldName) {
      if (node is Map<String, dynamic>) {
        if (node['fieldName'] == fieldName) return node;
        for (final value in node.values) {
          final found = findByFieldName(value, fieldName);
          if (found != null) return found;
        }
      } else if (node is List) {
        for (final value in node) {
          final found = findByFieldName(value, fieldName);
          if (found != null) return found;
        }
      }
      return null;
    }

    final editButton = findByFieldName(decoded, 'editIndividualButton');

    expect(editButton, isNotNull);
    expect(editButton!['visible'], "{{fn:hasRole('REGISTRAR')}} == true");
  });

  test('a Registrar-visible back-to-search button exists in the footer', () {
    final footer =
        (householdOverviewFlow['footer'] as List).cast<Map<String, dynamic>>();
    final backButton =
        footer.firstWhere((b) => b['fieldName'] == 'backToSearchRegistrar');

    expect(backButton['visible'], "{{fn:hasRole('REGISTRAR')}} == true");
    expect(backButton['label'], 'ACKNOWLEDGEMENT_SUCCESS_LABEL_TEXT');
    expect(footer.last['fieldName'], 'backToSearchRegistrar');

    final actions =
        (backButton['onAction'] as List).cast<Map<String, dynamic>>();
    expect(actions.map((action) => action['actionType']), [
      'CLEAR_STATE',
      'NAVIGATION',
    ]);
    expect(actions.first['properties']['clearAll'], isTrue);

    final navProps = actions.last['properties'] as Map<String, dynamic>;
    expect(navProps['name'], 'searchBeneficiary');
    expect(navProps['navigationMode'], 'popUntilAndReplace');
    expect(navProps['popUntilPageName'], 'searchBeneficiary');
  });
}
