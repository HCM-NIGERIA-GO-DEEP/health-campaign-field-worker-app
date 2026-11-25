import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA (Liberia, 2026-11-25): sync failed with 400 "caregiverConsent ... must
/// not be null". The server rejects any additionalFields entry whose value is
/// null. A household edit that starts on Household Details never shows the
/// consent page, so `caregiverConsent.consentToParticipate` is in the form
/// with a null value; the update path then replaced the stored answer with
/// null. An update must never write a null/blank additional field and must
/// keep the value already stored.
void main() {
  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  List<dynamic> fieldsOf(EntityModel model) =>
      ((model.toMap()['additionalFields'] as Map?)?['fields'] as List?) ??
      const [];

  HouseholdModel household() => HouseholdModel(
        clientReferenceId: 'household',
        memberCount: 2,
        additionalFields: HouseholdAdditionalFields(
          version: 1,
          fields: [
            const AdditionalField('caregiverConsent', 'TRUE'),
            const AdditionalField('memberCount', 2),
          ],
        ),
      );

  const editForm = {
    'householdDetails': {'memberCount': 4, 'childrenCount': null},
    'caregiverConsent': {
      'consentToParticipate': null,
      'firstName': null,
      'lastName': null,
    },
    'beneficiaryLocation': {'latLng': null},
  };

  for (final configName in ['beneficiaryRegistration', 'householdDetailsEdit']) {
    test('$configName edit without the consent page keeps the stored consent',
        () {
      final updated = FormEntityMapper(config: jsonConfig).updateEntitiesFromForm(
        existingModels: [household()],
        formValues: editForm,
        modelsConfig: {
          'HouseholdModel': (jsonConfig[configName]!['models']
              as Map<String, dynamic>)['HouseholdModel'],
        },
        context: const {},
        fallbackFormDataString: 'HouseholdModel',
      );

      final fields = fieldsOf(updated.whereType<HouseholdModel>().single);
      expect(fields.where((f) => f['value'] == null), isEmpty,
          reason: 'the server rejects a null additional field value');
      expect(fields, contains(equals({'key': 'caregiverConsent', 'value': 'TRUE'})));
      expect(fields, contains(equals({'key': 'memberCount', 'value': 4})));
    });
  }

  test('re-declining with a blank name writes no null field on the task', () {
    final updated = FormEntityMapper(config: jsonConfig).updateEntitiesFromForm(
      existingModels: [
        household(),
        TaskModel(
          clientReferenceId: 'closed-task',
          status: 'CLOSED_HOUSEHOLD',
          additionalFields: TaskAdditionalFields(
            version: 1,
            fields: [const AdditionalField('firstName', 'Earlier first')],
          ),
        ),
      ],
      formValues: const {
        'caregiverConsent': {
          'consentToParticipate': 'FALSE',
          'firstName': null,
          'lastName': 'Updated last',
        },
        'navigation': {'HouseholdClientReferenceId': 'household'},
      },
      modelsConfig: {
        for (final name in ['HouseholdModel', 'TaskModel'])
          name: (jsonConfig['householdConsentDeclinedUpdate']!['models']
              as Map<String, dynamic>)[name],
      },
      context: const {},
    );

    final taskFields = fieldsOf(updated.whereType<TaskModel>().single);
    expect(taskFields.where((f) => f['value'] == null), isEmpty);
    expect(taskFields, contains(equals({'key': 'firstName', 'value': 'Earlier first'})));
    expect(taskFields, contains(equals({'key': 'familyName', 'value': 'Updated last'})));
    expect(fieldsOf(updated.whereType<HouseholdModel>().single),
        contains(equals({'key': 'caregiverConsent', 'value': 'FALSE'})));
  });
}
