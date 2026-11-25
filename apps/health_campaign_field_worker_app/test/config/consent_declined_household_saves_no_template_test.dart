import 'dart:convert';

import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// QA (Liberia, 2026-11-25): the saved household of a registration answered
/// "No" on the consent page held
/// `{"key":"nameOfIndividual","value":"{{navigation.firstName}}"}` and
/// `{"key":"familyname","value":"{{navigation.lastName}}"}`.
///
/// Consent "No" submits the form from the consent page, so Household Details
/// is never opened. The forms bloc still hands over every page on submit, and
/// for a page that was never opened the values are the raw config defaults -
/// for the two head-name fields that is the `{{navigation.…}}` template text,
/// which only a built form control resolves. The consent-declined mapping
/// has a fallback model, so the unmapped template text was saved on the
/// household.
///
/// This runs the shipped HOUSEHOLD flow through the real forms bloc and the
/// real transformer mapping.
void main() {
  late Map<String, dynamic> householdFlow;

  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    householdFlow = ((sampleFlows as Map)['flows'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['name'] == 'HOUSEHOLD' && f['screenType'] == 'FORM');
  });

  /// Submits the HOUSEHOLD form after only Location and Consent were filled.
  Future<Map<String, Map<String, dynamic>>> submitFromConsentPage() async {
    final bloc = FormsBloc();
    addTearDown(bloc.close);

    bloc.add(FormsEvent.load(schemas: [jsonEncode(transformJson(householdFlow))]));
    await bloc.stream.first;

    // What leaving the two visited pages writes back into the schema.
    const visited = {
      'beneficiaryLocation': {
        'administrativeArea': 'Community',
        'latLng': [6.3, -10.8, 5.0],
      },
      'caregiverConsent': {
        'consentToParticipate': 'FALSE',
        'firstName': 'Given',
        'lastName': 'Family',
      },
    };
    final schema = bloc.state.cachedSchemas['HOUSEHOLD']!;
    bloc.add(FormsEvent.update(
      schemaKey: 'HOUSEHOLD',
      schema: schema.copyWith(pages: {
        for (final page in schema.pages.entries)
          page.key: page.value.copyWith(properties: {
            for (final prop in page.value.properties!.entries)
              prop.key: visited[page.key]?.containsKey(prop.key) == true
                  ? prop.value.copyWith(value: visited[page.key]![prop.key])
                  : prop.value,
          }),
      }),
    ));
    await bloc.stream.first;

    bloc.add(const FormsEvent.submit(schemaKey: 'HOUSEHOLD'));
    final submitted = await bloc.stream
        .firstWhere((s) => s is FormsSubmittedState) as FormsSubmittedState;
    return submitted.formData;
  }

  test('the unopened Household Details page hands over no template text',
      () async {
    final formData = await submitFromConsentPage();

    final details = formData['householdDetails']!;
    expect(details['nameOfIndividual'], isNull);
    expect(details['familyname'], isNull);
    // The other defaults of that page are real values and stay.
    expect(details['memberCount'].toString(), '1');
    expect(formData['caregiverConsent']!['lastName'], 'Family');
  });

  test('the saved consent-declined household holds no template text',
      () async {
    final formData = await submitFromConsentPage();

    final entities = FormEntityMapper(config: jsonConfig).mapFormToEntities(
      formValues: formData,
      modelsConfig: jsonConfig['householdConsentDeclinedRegistration']!['models']
          as Map<String, dynamic>,
      context: const {
        'tenantId': 'lb',
        'userUUID': 'user',
        'loggedInUserUuid': 'user',
        'projectId': 'project',
        'beneficiaryProjectId': 'project',
        'beneficiaryType': 'HOUSEHOLD',
        'householdType': 'FAMILY',
        'selectedBoundaryCode': 'COMMUNITY',
        'identifierEntries': [
          {'identifierType': 'UNIQUE_BENEFICIARY_ID', 'identifierId': 'TOKEN'},
        ],
      },
      fallbackFormDataString: 'HouseholdModel',
    );

    final household = entities.whereType<HouseholdModel>().single;
    final fields = {
      for (final f in household.additionalFields?.fields ?? <AdditionalField>[])
        f.key: f.value,
    };
    expect(fields['caregiverConsent'], 'FALSE');
    expect(fields['familyName'], 'Family');
    expect(
      fields.entries.where((e) => e.value.toString().contains('{{')),
      isEmpty,
      reason: 'template text must never be saved as a value',
    );
    expect(fields.containsKey('nameOfIndividual'), isFalse);
    expect(fields.containsKey('familyname'), isFalse);

    final head = entities.whereType<IndividualModel>().single;
    expect(head.name?.givenName, 'Given');
    expect(head.name?.familyName, 'Family');
  });
}
