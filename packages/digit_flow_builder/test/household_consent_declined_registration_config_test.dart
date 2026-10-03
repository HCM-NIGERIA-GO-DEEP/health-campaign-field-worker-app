import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the entity-complete shape of "householdConsentDeclinedRegistration",
/// the transformer config that fires when the Household Head Consent screen
/// is answered "No". It must produce the same complete entity set as the
/// real Closed Household feature's "closeHouseholdRegistration" config
/// (Household/Individual placeholder/Identifier placeholder/Address/
/// HouseholdMember/ProjectBeneficiary/Task), sourced from our own
/// "beneficiaryLocation"/"caregiverConsent" pages. Without every one of these
/// entities, a household reopened later would have nothing for the existing
/// isEdit reopen path to find and update, silently dropping whatever the
/// field worker types in on completion.
void main() {
  late Map<String, dynamic> models;

  setUpAll(() {
    final config =
        jsonConfig['householdConsentDeclinedRegistration'] as Map<String, dynamic>;
    models = config['models'] as Map<String, dynamic>;
  });

  test('produces the full entity set the real Closed Household feature produces', () {
    expect(
      models.keys,
      containsAll([
        'HouseholdModel',
        'IndividualModel',
        'ProjectBeneficiaryModel',
        'HouseholdMemberModel',
        'TaskModel',
      ]),
    );

    final identifierAndAddress =
        (models['IndividualModel'] as Map<String, dynamic>)['listMappings']
            as Map<String, dynamic>;
    expect(identifierAndAddress.keys, containsAll(['IdentifierModel', 'AddressModel']));
  });

  test('TaskModel is tagged CLOSED_HOUSEHOLD, matching the real Closed Household feature', () {
    final taskMappings =
        (models['TaskModel'] as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;

    expect(taskMappings['status'], '__value:CLOSED_HOUSEHOLD');
  });

  test('HouseholdMemberModel marks this individual as head of household', () {
    final memberMappings = (models['HouseholdMemberModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;

    expect(memberMappings['isHeadOfHousehold'], '__value: true');
  });

  test('IdentifierModel is a DEFAULT placeholder, not sourced from any not-yet-captured ID field', () {
    final identifierMappings = ((models['IndividualModel']
                as Map<String, dynamic>)['listMappings']
            as Map<String, dynamic>)['IdentifierModel']
        as Map<String, dynamic>;
    final mappings = identifierMappings['mappings'] as Map<String, dynamic>;

    expect(mappings['identifierType'], '__value:DEFAULT');
    expect(mappings['identifierId'], '__generate:uuid');
  });

  test('sources location from beneficiaryLocation, not CLOSEHOUSEHOLD.json\'s closeHouseholdDetails page', () {
    final householdMappings = (models['HouseholdModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;

    expect(householdMappings['latitude'], 'beneficiaryLocation.latLng[0]');
    expect(householdMappings['longitude'], 'beneficiaryLocation.latLng[1]');
  });

  test('records the declined-consent marker on HouseholdModel.additionalFields for reporting', () {
    final householdMappings = (models['HouseholdModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;
    final additionalFields =
        householdMappings['additionalFields'] as Map<String, dynamic>;

    expect(additionalFields['caregiverConsent'], 'caregiverConsent.consentToParticipate');
  });

  test('does not source a head name from any field - no name is captured before consent', () {
    final individualMappings = (models['IndividualModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;
    final nameMapping = individualMappings['name'] as Map<String, dynamic>;

    expect(nameMapping.containsKey('givenName'), isFalse);
    expect(nameMapping.containsKey('familyName'), isFalse);
  });
}
