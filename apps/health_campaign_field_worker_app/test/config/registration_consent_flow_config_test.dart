import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural lint for the Household Head Consent flow in REGISTRATION.json.
///
/// Per the latest product decision, a "No" consent answer must NOT invoke
/// the real, existing CLOSEDHOUSEHOLD feature (CLOSEHOUSEHOLD.json). Instead
/// it reuses the pre-existing (unmodified) "householdConsentRegistration"
/// transformer config to create a minimal, self-contained "household noted,
/// consent declined" HouseholdModel record, then shows a dedicated
/// acknowledgement screen. A "Yes" answer must fall through to the existing,
/// unmodified Household Registration flow.
void main() {
  late Map<String, dynamic> config;
  late Map<String, dynamic> householdFlow;
  late Map<String, dynamic> caregiverConsentPage;
  late Map<String, dynamic> beneficiaryLocationPage;
  late Map<String, dynamic> householdDetailsPage;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();
    householdFlow = flows.firstWhere((f) => f['name'] == 'HOUSEHOLD');

    final pages =
        (householdFlow['pages'] as List).cast<Map<String, dynamic>>();
    caregiverConsentPage =
        pages.firstWhere((p) => p['page'] == 'caregiverConsent');
    beneficiaryLocationPage =
        pages.firstWhere((p) => p['page'] == 'beneficiaryLocation');
    householdDetailsPage =
        pages.firstWhere((p) => p['page'] == 'householdDetails');
  });

  test('caregiverConsent is a mandatory Yes/No question', () {
    final properties =
        (caregiverConsentPage['properties'] as List).cast<Map<String, dynamic>>();
    final consentField =
        properties.firstWhere((p) => p['fieldName'] == 'consentToParticipate');

    expect(consentField['format'], 'radio');
    expect(consentField['mandatory'], true);
    expect(consentField['hidden'], false);
    expect(
      consentField['enums'],
      [
        {'code': 'TRUE', 'name': 'APPONE_CAREGIVER_CONSENT_YES'},
        {'code': 'FALSE', 'name': 'APPONE_CAREGIVER_CONSENT_NO'},
      ],
    );
  });

  test('caregiverConsent sits between beneficiaryLocation and householdDetails in page order', () {
    final consentOrder = (caregiverConsentPage['order'] as num).toDouble();
    final locationOrder = (beneficiaryLocationPage['order'] as num).toDouble();
    final detailsOrder = (householdDetailsPage['order'] as num).toDouble();

    expect(locationOrder, lessThan(consentOrder));
    expect(consentOrder, lessThan(detailsOrder));
  });

  test('Yes branches back into the existing, unmodified Household Registration flow', () {
    final navigateList =
        (caregiverConsentPage['conditionalNavigateTo'] as List).cast<Map<String, dynamic>>();
    final yesBranch = navigateList.firstWhere(
        (n) => n['condition'] == 'caregiverConsent.consentToParticipate==TRUE');

    expect(yesBranch['navigateTo'], {'name': 'householdDetails', 'type': 'form'});
  });

  test('No branches to a direct form submission (skipping the remaining registration pages)', () {
    final navigateList =
        (caregiverConsentPage['conditionalNavigateTo'] as List).cast<Map<String, dynamic>>();
    final noBranch = navigateList.firstWhere(
        (n) => n['condition'] == 'caregiverConsent.consentToParticipate==FALSE');

    expect(noBranch['navigateTo']['type'], 'submit');
  });

  test('HOUSEHOLD flow-level onAction handles consent-declined before the DEFAULT (full registration) branch', () {
    final onAction =
        (householdFlow['onAction'] as List).cast<Map<String, dynamic>>();
    final expressions =
        onAction.map((c) => c['condition']['expression'] as String).toList();

    final consentIndex =
        expressions.indexOf('caregiverConsent.consentToParticipate==FALSE');
    final defaultIndex = expressions.indexOf('DEFAULT');

    expect(consentIndex, greaterThanOrEqualTo(0));
    expect(defaultIndex, greaterThanOrEqualTo(0));
    expect(consentIndex, lessThan(defaultIndex));
  });

  test('consent-declined branch reuses the existing householdConsentRegistration transformer config, unmodified', () {
    final onAction =
        (householdFlow['onAction'] as List).cast<Map<String, dynamic>>();
    final consentBranch = onAction.firstWhere((c) =>
        c['condition']['expression'] ==
        'caregiverConsent.consentToParticipate==FALSE');

    final actions = (consentBranch['actions'] as List).cast<Map<String, dynamic>>();
    final actionTypes = actions.map((a) => a['actionType']).toList();

    expect(actionTypes, ['FETCH_TRANSFORMER_CONFIG', 'CREATE_EVENT', 'NAVIGATION']);
    expect(
      actions[0]['properties']['configName'],
      'householdConsentRegistration',
    );
    expect(actions[2]['properties']['name'], 'caregiverAcknowledgement');
  });

  test('consent-declined branch does not reference the real Closed Household feature', () {
    final serialized = jsonEncode(householdFlow);

    expect(serialized.contains('CLOSEDHOUSEHOLD'), isFalse);
    expect(serialized.contains('CLOSEHOUSEHOLD'), isFalse);
  });

  test('caregiverAcknowledgement screen exists with safe navigation actions back to search', () {
    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();
    final ackFlow =
        flows.firstWhere((f) => f['name'] == 'caregiverAcknowledgement');

    expect(ackFlow['screenType'], 'TEMPLATE');

    final panelCard =
        (ackFlow['body'] as List).cast<Map<String, dynamic>>().first;
    final primaryAction = panelCard['primaryAction'] as Map<String, dynamic>;
    final secondaryAction = panelCard['secondaryAction'] as Map<String, dynamic>;

    final primaryNavProps = (primaryAction['onAction'] as List)
        .cast<Map<String, dynamic>>()
        .first['properties'] as Map<String, dynamic>;
    final secondaryNavProps = (secondaryAction['onAction'] as List)
        .cast<Map<String, dynamic>>()
        .first['properties'] as Map<String, dynamic>;

    expect(primaryNavProps['name'], 'householdOverview');
    expect(secondaryNavProps['name'], 'searchBeneficiary');
    expect(primaryNavProps['popUntilPageName'], 'searchBeneficiary');
    expect(secondaryNavProps['popUntilPageName'], 'searchBeneficiary');
  });
}
