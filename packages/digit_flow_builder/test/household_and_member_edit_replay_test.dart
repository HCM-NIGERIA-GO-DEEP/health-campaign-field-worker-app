import 'package:digit_data_converter/src/reverse_transformer_service.dart';
import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA (Liberia, 2026-11-25): "when we are updating the details of head or
/// child it is not getting stored in db or elastic".
///
/// Replays both edits the way the app runs them: the stored records are
/// turned into form values (REVERSE_TRANSFORM), the user changes some of
/// them, and the transformer's edit path (`updateEntitiesFromForm`) builds
/// the records UPDATE_EVENT saves. An edit must keep every record id, change
/// what the user changed and leave the rest as stored.
void main() {
  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  Map<String, dynamic> models(String configName, Iterable<String> types) => {
        for (final type in types)
          type: (jsonConfig[configName]!['models'] as Map<String, dynamic>)[type],
      };

  Map<String, dynamic> fieldMap(EntityModel model) => {
        for (final f
            in ((model.toMap()['additionalFields'] as Map?)?['fields'] as List?) ??
                const [])
          (f as Map)['key'] as String: f['value'],
      };

  IndividualModel person({
    required String ref,
    required String given,
    required String family,
    String? mobile,
  }) =>
      IndividualModel(
        clientReferenceId: ref,
        id: 'server-$ref',
        tenantId: 'lb',
        rowVersion: 1,
        gender: Gender.male,
        mobileNumber: mobile,
        dateOfBirth: '01/01/2024',
        name: NameModel(
          individualClientReferenceId: ref,
          givenName: given,
          familyName: family,
        ),
        identifiers: [
          IdentifierModel(
            id: 'server-identifier-$ref',
            clientReferenceId: 'identifier-$ref',
            individualClientReferenceId: ref,
            identifierType: 'UNIQUE_BENEFICIARY_ID',
            identifierId: 'TOKEN-$ref',
          ),
        ],
      );

  group('head edit from Household Details (householdDetailsEdit)', () {
    late HouseholdModel household;
    late IndividualModel head;

    setUp(() {
      household = HouseholdModel(
        clientReferenceId: 'household',
        id: 'server-household',
        tenantId: 'lb',
        rowVersion: 1,
        memberCount: 3,
        additionalFields: HouseholdAdditionalFields(
          version: 1,
          fields: [
            const AdditionalField('caregiverConsent', 'TRUE'),
            const AdditionalField('familyName', 'Old family'),
            const AdditionalField('memberCount', '3'),
            const AdditionalField('childrenCount', '2'),
          ],
        ),
      );
      head = person(
        ref: 'head',
        given: 'Old given',
        family: 'Old family',
        mobile: '0111111111',
      );
    });

    List<EntityModel> edit(Map<String, dynamic> householdDetails) {
      return FormEntityMapper(config: jsonConfig).updateEntitiesFromForm(
        existingModels: [household, head],
        formValues: {
          'householdDetails': householdDetails,
          // The edit opens on Household Details; the other pages are never
          // shown and reach the transformer with their stored/default values.
          'caregiverConsent': const {
            'consentToParticipate': 'TRUE',
            'firstName': null,
            'lastName': null,
          },
          'beneficiaryLocation': const {'administrativeArea': 'Boundary'},
          'navigation': const {
            'HouseholdClientReferenceId': 'household',
            'isEdit': 'true',
            'startPage': 'householdDetails',
          },
        },
        modelsConfig:
            models('householdDetailsEdit', ['HouseholdModel', 'IndividualModel']),
        context: const {'tenantId': 'lb'},
      );
    }

    test('saves the changed head name, phone, gender and the two counts', () {
      final updated = edit(const {
        'nameOfIndividual': 'New given',
        'familyname': 'New family',
        'phone': '0222222222',
        'gender': 'FEMALE',
        'memberCount': 4,
        'childrenCount': 3,
        'isHeadOfFamily': true,
        'identifiers': 'UNIQUE_BENEFICIARY_ID, TOKEN-head',
      });

      final savedHead = updated.whereType<IndividualModel>().single;
      expect(savedHead.clientReferenceId, 'head');
      expect(savedHead.id, 'server-head');
      expect(savedHead.name?.givenName, 'New given');
      expect(savedHead.name?.familyName, 'New family');
      expect(savedHead.mobileNumber, '0222222222');
      expect(savedHead.gender, Gender.female);
      expect(savedHead.dateOfBirth, '01/01/2024');
      expect(savedHead.identifiers, head.identifiers,
          reason: 'an edit of the details must leave the beneficiary id alone');

      final savedHousehold = updated.whereType<HouseholdModel>().single;
      expect(savedHousehold.clientReferenceId, 'household');
      expect(savedHousehold.id, 'server-household');
      expect(savedHousehold.memberCount, 4);
      final fields = fieldMap(savedHousehold);
      expect(fields['childrenCount'].toString(), '3');
      expect(fields['memberCount'].toString(), '4');
      expect(fields['familyName'], 'New family');
      expect(fields['caregiverConsent'], 'TRUE');
      expect(fields.values.where((v) => v == null), isEmpty);
    });

    test('an unchanged form changes nothing', () {
      final updated = edit(const {
        'nameOfIndividual': 'Old given',
        'familyname': 'Old family',
        'phone': '0111111111',
        'gender': 'MALE',
        'memberCount': 3,
        'childrenCount': '2',
      });

      final savedHead = updated.whereType<IndividualModel>().single;
      expect(savedHead.name?.givenName, 'Old given');
      expect(savedHead.name?.familyName, 'Old family');
      expect(savedHead.mobileNumber, '0111111111');
      expect(savedHead.gender, Gender.male);
      expect(updated.whereType<HouseholdModel>().single.memberCount, 3);
    });
  });

  group('child edit from Add Member (individualRegistration)', () {
    late IndividualModel child;
    late ProjectBeneficiaryModel beneficiary;

    setUp(() {
      child = person(ref: 'child', given: 'Old child', family: 'Old family');
      beneficiary = ProjectBeneficiaryModel(
        clientReferenceId: 'beneficiary',
        id: 'server-beneficiary',
        tenantId: 'lb',
        rowVersion: 1,
        projectId: 'project',
        beneficiaryClientReferenceId: 'household',
        dateOfRegistration: 1700000000000,
      );
    });

    test('saves the changed name and keeps every id of the stored record', () {
      // REVERSE_TRANSFORM: what the edit form is prefilled with.
      final prefill = ReverseFormMapper(
        formConfig: jsonConfig['individualRegistration']!,
        modelInstances: [child, beneficiary],
      ).buildFormData();
      expect(prefill['nameOfIndividual'], 'Old child');

      final formValues = <String, dynamic>{
        'beneficiaryDetails': {
          ...prefill,
          'nameOfIndividual': 'New child',
          'familyname': 'New family',
          // The hidden idPopulator field keeps the id the child already has.
          'identifiers': 'UNIQUE_BENEFICIARY_ID, TOKEN-child',
        },
        'navigation': const {
          'HouseholdClientReferenceId': 'household',
          'isEdit': 'true',
          'isHead': 'false',
        },
      };
      final mapper = FormEntityMapper(config: jsonConfig);

      final updated = mapper.updateEntitiesFromForm(
        existingModels: [child, beneficiary],
        formValues: formValues,
        modelsConfig: models('individualRegistration',
            ['IndividualModel', 'ProjectBeneficiaryModel']),
        context: {
          'tenantId': 'lb',
          'userUUID': 'user',
          'loggedInUserUuid': 'user',
          'projectId': 'project',
          'beneficiaryProjectId': 'project',
          'beneficiaryType': 'HOUSEHOLD',
          'HouseholdClientReferenceId': 'household',
          'selectedBoundaryCode': 'BOUNDARY',
          'identifierEntries':
              TransformerExecutor.buildIdentifierEntries(formValues, mapper),
        },
        fallbackFormDataString: 'IndividualModel',
      );

      final saved = updated.whereType<IndividualModel>().single;
      expect(saved.clientReferenceId, 'child');
      expect(saved.id, 'server-child');
      expect(saved.name?.givenName, 'New child');
      expect(saved.name?.familyName, 'New family');
      expect(saved.gender, Gender.male);

      final identifier = saved.identifiers!.single;
      expect(identifier.identifierType, 'UNIQUE_BENEFICIARY_ID');
      expect(identifier.identifierId, 'TOKEN-child');
      // The identifier is rebuilt with a new clientReferenceId on every edit
      // (IndividualLocalRepository.update is written for that); only its
      // type, value and owner are checked here.
      expect(identifier.individualClientReferenceId, 'child');

      final savedBeneficiary =
          updated.whereType<ProjectBeneficiaryModel>().single;
      expect(savedBeneficiary.clientReferenceId, 'beneficiary');
      expect(savedBeneficiary.id, 'server-beneficiary');
      expect(savedBeneficiary.beneficiaryClientReferenceId, 'household');
      expect(savedBeneficiary.projectId, 'project');
      expect(savedBeneficiary.dateOfRegistration, 1700000000000,
          reason: 'editing a name must not change the registration date');
    });
  });
}
