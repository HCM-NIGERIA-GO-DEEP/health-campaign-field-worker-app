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
        TaskModel(clientReferenceId: 'closed-task', status: 'CLOSED_HOUSEHOLD'),
      ],
      formValues: const {
        'caregiverConsent': {
          'consentToParticipate': 'FALSE',
          'firstName': 'Updated first',
          'lastName': 'Updated last',
        },
        'householdDetails': {'dateOfRegistration': null},
        'navigation': {'HouseholdClientReferenceId': 'household'},
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
          {'key': 'firstName', 'value': 'Updated first'},
          {'key': 'caregiverConsent', 'value': 'FALSE'},
          {'key': 'familyName', 'value': 'Updated last'},
        ]));
    final task = updated.whereType<TaskModel>().single;
    expect(task.status, 'CLOSED_HOUSEHOLD');
    expect(task.toMap()['additionalFields']['fields'], [
      {'key': 'firstName', 'value': 'Updated first'},
      {'key': 'familyName', 'value': 'Updated last'},
      {'key': 'householdClientReferenceId', 'value': 'household'},
    ]);
  });

  test('reopening with consent saves names from Household Details', () {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    final registrationModels = jsonConfig['beneficiaryRegistration']!['models']
        as Map<String, dynamic>;
    final updated = FormEntityMapper(config: jsonConfig).updateEntitiesFromForm(
      existingModels: [
        HouseholdModel(
          clientReferenceId: 'household',
          additionalFields: HouseholdAdditionalFields(
            version: 1,
            fields: [const AdditionalField('familyName', 'Earlier last')],
          ),
        ),
        IndividualModel(
          clientReferenceId: 'head',
          name: NameModel(
            individualClientReferenceId: 'head',
            givenName: 'Earlier first',
            familyName: 'Earlier last',
          ),
        ),
      ],
      formValues: const {
        'caregiverConsent': {
          'consentToParticipate': 'TRUE',
          'firstName': 'Earlier first',
          'lastName': 'Earlier last',
        },
        'householdDetails': {
          'nameOfIndividual': 'Updated first',
          'familyname': 'Updated last',
        },
      },
      modelsConfig: {
        'HouseholdModel': registrationModels['HouseholdModel'],
        'IndividualModel': registrationModels['IndividualModel'],
      },
      context: const {
        'tenantId': 'liberia',
        'userUUID': 'worker',
        'selectedBoundaryCode': 'community',
        'identifierEntries': [
          {'identifierType': 'UNIQUE_BENEFICIARY_ID', 'identifierId': 'token'},
        ],
      },
    );

    final head = updated.whereType<IndividualModel>().single;
    expect(head.name?.givenName, 'Updated first');
    expect(head.name?.familyName, 'Updated last');
    final household = updated.whereType<HouseholdModel>().single;
    expect(household.toMap()['additionalFields']['fields'],
        contains(equals({'key': 'firstName', 'value': 'Updated first'})));
  });

  test('household head edit changes names and counts and retains consent', () {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    final address = AddressModel(latitude: 6.3, longitude: -10.8);
    final updated = FormEntityMapper(config: jsonConfig).updateEntitiesFromForm(
      existingModels: [
        HouseholdModel(
          clientReferenceId: 'household',
          memberCount: 2,
          address: address,
          additionalFields: HouseholdAdditionalFields(
            version: 1,
            fields: [const AdditionalField('caregiverConsent', 'TRUE')],
          ),
        ),
        IndividualModel(
          clientReferenceId: 'head',
          name: NameModel(
            individualClientReferenceId: 'head',
            givenName: 'Original first',
            familyName: 'Original last',
          ),
          address: [address],
        ),
      ],
      formValues: const {
        'householdDetails': {
          'nameOfIndividual': 'Updated first',
          'familyname': 'Updated last',
          'memberCount': 4,
          'childrenCount': 2,
        },
        'caregiverConsent': {'consentToParticipate': null},
        'beneficiaryLocation': {'latLng': null},
      },
      modelsConfig: jsonConfig['householdDetailsEdit']!['models']
          as Map<String, dynamic>,
      context: const {},
    );

    final head = updated.whereType<IndividualModel>().single;
    expect(head.name?.givenName, 'Updated first');
    expect(head.name?.familyName, 'Updated last');
    expect(head.address?.single.latitude, 6.3);
    final household = updated.whereType<HouseholdModel>().single;
    expect(household.memberCount, 4);
    expect(household.address?.longitude, -10.8);
    expect(household.toMap()['additionalFields']['fields'], containsAll([
      {'key': 'caregiverConsent', 'value': 'TRUE'},
      {'key': 'childrenCount', 'value': 2},
      {'key': 'firstName', 'value': 'Updated first'},
    ]));
  });

  for (final entry in {
    'closeHouseholdRegistration': {
      'closeHouseholdDetails': {
        'headName': 'Captured first',
        'familyname': 'Captured last',
      },
    },
    'householdConsentDeclinedRegistration': {
      'caregiverConsent': {
        'firstName': 'Captured first',
        'lastName': 'Captured last',
      },
    },
  }.entries) {
    test('${entry.key} sends both names and links its task to the household', () {
      initializeMappers();
      DataConverterSingleton()
          .setData(dynamicEntityModelListener: EntityModelJsonMapper());
      final entities = FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: entry.value,
        modelsConfig: jsonConfig[entry.key]!['models'] as Map<String, dynamic>,
        fallbackFormDataString: 'HouseholdModel',
        context: const {
          'tenantId': 'test',
          'userUUID': 'worker',
          'selectedBoundaryCode': 'community',
          'beneficiaryType': 'HOUSEHOLD',
        },
      );
      final household = entities.whereType<HouseholdModel>().single;
      final task = entities.whereType<TaskModel>().single;
      final head = entities.whereType<IndividualModel>().single;
      expect(head.name?.givenName, 'Captured first');
      expect(head.name?.familyName, 'Captured last');
      final familyName = {'key': 'familyName', 'value': 'Captured last'};
      expect(household.toMap()['additionalFields']['fields'], containsAll([
        {'key': 'firstName', 'value': 'Captured first'},
        familyName,
      ]));
      expect(task.toMap()['additionalFields']['fields'], containsAll([
        {'key': 'firstName', 'value': 'Captured first'},
        familyName,
        {'key': 'householdClientReferenceId', 'value': household.clientReferenceId},
      ]));
    });
  }

  for (final configName in ['delivery', 'indirectBulkDelivery']) {
    test('$configName serializes household details on the task', () {
      initializeMappers();
      DataConverterSingleton()
          .setData(dynamicEntityModelListener: EntityModelJsonMapper());
      const householdDetails = {
        'headName': 'Household Head',
        'headMobileNumber': '123456789',
        'memberCount': 4,
        'childrenCount': 0,
        'householdLatitude': 6.31,
        'householdLongitude': -10.8,
        'householdLocationAccuracy': 12.0,
      };
      final tasks = FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: const {},
        modelsConfig: jsonConfig[configName]!['models'] as Map<String, dynamic>,
        context: const {
          ...householdDetails,
          'HouseholdClientReferenceId': 'household',
          'ProjectBeneficiaryClientReferenceId': 'beneficiary',
          'tenantId': 'test',
          'userUUID': 'worker',
          'selectedBoundaryCode': 'community',
          'futureDoses': [{'id': 2, 'deliveryStrategy': 'INDIRECT'}],
        },
      ).whereType<TaskModel>();
      expect(tasks.single.toMap()['additionalFields']['fields'], containsAll(
        householdDetails.entries.map((entry) => {
          'key': entry.key,
          'value': entry.value,
        }),
      ));
    });
  }

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
