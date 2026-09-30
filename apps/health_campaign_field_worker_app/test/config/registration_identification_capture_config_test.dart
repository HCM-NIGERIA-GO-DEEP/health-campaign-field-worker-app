import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural lint for the Household Details screen's new Identification
/// Type / Identification Number capture fields in REGISTRATION.json,
/// alongside the existing (unchanged) hidden Beneficiary ID field.
///
/// The exact identifier type codes are expected to come from MDMS in real
/// deployments (see schemaCode below); this only guards the wiring the app
/// itself depends on, not specific backend-supplied values.
void main() {
  late List<dynamic> body;
  late Map<String, dynamic> identificationType;
  late Map<String, dynamic> identificationNumber;
  late Map<String, dynamic> hiddenBeneficiaryIdField;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    // The Household Details form fields (unlike the searchBeneficiary
    // screen's flow-builder "body" widgets) are defined as a forms-engine
    // JSON schema under a page's "properties", where pages are nested one
    // level under each top-level flow's "pages" array.
    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();
    final allPages = flows
        .expand((f) => (f['pages'] as List? ?? []).cast<Map<String, dynamic>>())
        .toList();
    final detailsScreen = allPages.firstWhere(
      (p) => (p['properties'] as List?)?.any(
            (w) => w is Map && w['fieldName'] == 'identificationType',
          ) ==
          true,
      orElse: () => throw StateError(
        'Could not find the Household Details page with "identificationType" in REGISTRATION.json',
      ),
    );
    body = detailsScreen['properties'] as List<dynamic>;

    identificationType = body.cast<Map<String, dynamic>>().firstWhere(
        (w) => w['fieldName'] == 'identificationType');
    identificationNumber = body.cast<Map<String, dynamic>>().firstWhere(
        (w) => w['fieldName'] == 'identificationNumber');
    hiddenBeneficiaryIdField = body.cast<Map<String, dynamic>>().firstWhere(
        (w) => w['fieldName'] == 'identifiers');
  });

  test('identificationType is a mandatory, MDMS-backed dropdown', () {
    expect(identificationType['format'], 'dropdown');
    expect(identificationType['mandatory'], true);
    expect(identificationType['hidden'], false);
    expect(identificationType['isMdms'], true);
    expect(identificationType['schemaCode'], isNotNull);
    expect(identificationType['enums'], isNotEmpty);
  });

  test('identificationNumber is mandatory, only visible once a type is chosen', () {
    expect(identificationNumber['mandatory'], true);
    expect(identificationNumber['hidden'], false);
    expect(identificationNumber['visible'], contains('identificationType'));
  });

  test('the existing hidden Beneficiary ID field is completely untouched', () {
    expect(hiddenBeneficiaryIdField['format'], 'idPopulator');
    expect(hiddenBeneficiaryIdField['hidden'], true);
    expect(
      hiddenBeneficiaryIdField['enums'],
      [
        {'code': 'DEFAULT', 'name': 'DEFAULT'},
        {'code': 'UNIQUE_BENEFICIARY_ID', 'name': 'UNIQUE_BENEFICIARY_ID'},
      ],
    );
  });

  test('identificationType and identificationNumber sit before identifiers (order 10) without renumbering it', () {
    final orders = {
      for (final w in body.cast<Map<String, dynamic>>())
        if (w['fieldName'] != null) w['fieldName'] as String: w['order']
    };

    expect(orders['identifiers'], 10);
    expect(orders['identificationType'], lessThan(orders['identifiers']));
    expect(orders['identificationNumber'], lessThan(orders['identifiers']));
  });
}
