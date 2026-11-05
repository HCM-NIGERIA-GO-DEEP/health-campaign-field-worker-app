import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_data_model/models/entities/name.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
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

  test('editing declined consent preserves the existing registration and ID', () {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    final registration = ProjectBeneficiaryModel(
      clientReferenceId: 'registration',
      dateOfRegistration: 1234,
    );
    final identifier = IdentifierModel(
      clientReferenceId: 'identifier',
      individualClientReferenceId: 'head',
      identifierType: 'DEFAULT',
      identifierId: 'placeholder',
    );
    final updated = FormEntityMapper(config: jsonConfig).updateEntitiesFromForm(
      existingModels: [
        HouseholdModel(clientReferenceId: 'household'),
        IndividualModel(
          clientReferenceId: 'head',
          name: NameModel(individualClientReferenceId: 'head'),
          identifiers: [identifier],
        ),
        registration,
      ],
      formValues: const {
        'caregiverConsent': {
          'consentToParticipate': 'FALSE',
          'firstName': 'Updated first',
          'lastName': 'Updated last',
        },
        'householdDetails': {'dateOfRegistration': null},
      },
      modelsConfig: jsonConfig['householdConsentDeclinedUpdate']!['models']
          as Map<String, dynamic>,
      context: const {},
    );

    final head = updated.whereType<IndividualModel>().single;
    expect(head.name?.givenName, 'Updated first');
    expect(head.name?.familyName, 'Updated last');
    expect(head.name?.individualClientReferenceId, 'head');
    expect(head.identifiers?.single.identifierId, 'placeholder');
    expect(updated.whereType<ProjectBeneficiaryModel>().single, same(registration));
    final household = updated.whereType<HouseholdModel>().single;
    expect(household.toMap()['additionalFields']['fields'],
        equals([
          {'key': 'caregiverConsent', 'value': 'FALSE'},
        ]));
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

  test('sources the head name from the declined-consent form', () {
    final individualMappings = (models['IndividualModel']
        as Map<String, dynamic>)['mappings'] as Map<String, dynamic>;
    final nameMapping = individualMappings['name'] as Map<String, dynamic>;

    expect(nameMapping['givenName'], 'caregiverConsent.firstName');
    expect(nameMapping['familyName'], 'caregiverConsent.lastName');
  });
}
