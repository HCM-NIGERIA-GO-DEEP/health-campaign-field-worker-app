import 'package:digit_data_converter/src/reverse_transformer_service.dart';
import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_init;
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// SL request 2026-11-18: also send the household (head) name in the
/// household's additional details. Nothing else is dropped.
void main() {
  setUpAll(() {
    data_model_init.initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  final config = jsonConfig['beneficiaryRegistration'] as Map<String, dynamic>;
  final householdModelConfig = (config['models']
      as Map<String, dynamic>)['HouseholdModel'] as Map<String, dynamic>;

  Map<String, dynamic> fieldsOf(HouseholdModel h) => {
        for (final f in h.additionalFields?.fields ?? <AdditionalField>[])
          f.key: f.value,
      };

  test('a new household saves the head name next to the existing keys', () {
    final household = FormEntityMapper(config: jsonConfig)
        .mapFormToEntities(
          formValues: {
            'householdDetails': {
              'nameOfIndividual': 'Amara',
              'familyname': 'Kamara',
              'memberCount': 4,
              'childrenCount': 1,
            },
          },
          modelsConfig: {'HouseholdModel': householdModelConfig},
          context: {
            'tenantId': 'si',
            'householdType': 'FAMILY',
            'selectedBoundaryCode': 'B1',
            'userUUID': 'user-1',
          },
        )
        .whereType<HouseholdModel>()
        .single;

    final fields = fieldsOf(household);
    expect(fields['householdName'], 'Amara Kamara');
    expect(fields['memberCount'], isNotNull, reason: 'nothing is dropped');
    expect(fields['childrenCount'], isNotNull, reason: 'nothing is dropped');
  });

  test('editing the head name updates the saved household name', () {
    final updated = FormEntityMapper(config: jsonConfig).updateModelFromForm(
      existingModel: HouseholdModel(
        clientReferenceId: 'hh-1',
        memberCount: 4,
        additionalFields: HouseholdAdditionalFields(version: 1, fields: const [
          AdditionalField('householdName', 'Amara'),
        ]),
      ),
      formValues: {
        'householdDetails': {'nameOfIndividual': 'Amara K', 'memberCount': 4},
      },
      modelConfig: householdModelConfig,
      context: const {},
    ) as HouseholdModel;

    expect(fieldsOf(updated)['householdName'], 'Amara K');
  });

  test(
      'the edit form takes the name from the individual, not from a stale '
      'household copy', () {
    final formData = ReverseFormMapper(
      formConfig: config,
      modelInstances: [
        HouseholdModel(
          clientReferenceId: 'hh-1',
          memberCount: 4,
          additionalFields:
              HouseholdAdditionalFields(version: 1, fields: const [
            AdditionalField('householdName', 'Old Name'),
          ]),
        ),
        IndividualModel(
          clientReferenceId: 'ind-1',
          name: NameModel(
            individualClientReferenceId: 'ind-1',
            givenName: 'New Name',
          ),
        ),
      ],
    ).buildFormData();

    final page = formData['householdDetails'];
    final name = page is Map
        ? page['nameOfIndividual']
        : formData['householdDetails.nameOfIndividual'] ??
            formData['nameOfIndividual'];
    expect(name, 'New Name', reason: 'formData was: $formData');
  });

  test(
      'a full edit (reverse output + changed name, with the fallback merge) '
      'saves the NEW name, not the stale copy', () {
    final existing = HouseholdModel(
      clientReferenceId: 'hh-1',
      memberCount: 4,
      additionalFields: HouseholdAdditionalFields(version: 1, fields: const [
        AdditionalField('householdName', 'Old Name'),
        AdditionalField('childrenCount', '1'),
      ]),
    );
    // What REVERSE_TRANSFORM hands the edit form: every additionalFields key
    // also arrives as a flat top-level key.
    final formValues = Map<String, dynamic>.from(ReverseFormMapper(
      formConfig: config,
      modelInstances: [existing],
    ).buildFormData());
    expect(formValues.toString(), contains('Old Name'),
        reason: 'the stale copy must be part of this replay');
    final page = Map<String, dynamic>.from(
        (formValues['householdDetails'] as Map?) ?? const {});
    page['nameOfIndividual'] = 'New';
    page['familyname'] = 'Family';
    formValues['householdDetails'] = page;

    final updated = FormEntityMapper(config: jsonConfig)
        .updateEntitiesFromForm(
          existingModels: [existing],
          formValues: formValues,
          modelsConfig: {'HouseholdModel': householdModelConfig},
          context: const {'tenantId': 'si', 'userUUID': 'user-1'},
          fallbackFormDataString: 'HouseholdModel',
        )
        .whereType<HouseholdModel>()
        .single;

    final names = (updated.additionalFields?.fields ?? [])
        .where((f) => f.key == 'householdName')
        .map((f) => f.value)
        .toList();
    expect(names, ['New Family'], reason: 'formValues were: $formValues');
    expect(fieldsOf(updated)['childrenCount'], isNotNull);
  });
  test('closed and consent-no households save both name parts', () {
    for (final entry in {
      'closeHouseholdRegistration': {
        'closeHouseholdDetails': {'headName': 'Amara', 'familyname': 'Kamara'}
      },
      'householdConsentDeclinedRegistration': {
        'caregiverConsent': {'nameOfIndividual': 'Amara', 'familyname': 'Kamara'}
      },
    }.entries) {
      final models = jsonConfig[entry.key]!['models'] as Map<String, dynamic>;
      final household = FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: entry.value,
        modelsConfig: {'HouseholdModel': models['HouseholdModel']},
        context: const {
          'tenantId': 'si',
          'householdType': 'FAMILY',
          'selectedBoundaryCode': 'B1',
          'userUUID': 'user-1',
        },
      ).whereType<HouseholdModel>().single;
      expect(fieldsOf(household)['householdName'], 'Amara Kamara',
          reason: entry.key);
    }
  });

}
