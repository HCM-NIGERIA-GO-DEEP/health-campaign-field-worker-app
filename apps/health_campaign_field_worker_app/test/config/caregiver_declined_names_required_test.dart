import 'dart:convert';
import 'dart:io';

import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:digit_forms_engine/helper/visibility_manager.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// SL QA 2026-11-18: when caregiver consent is "No", First name and Last name
/// must be mandatory. They are shown only on "No", so "Yes" must not be
/// blocked by them.
void main() {
  const names = {
    'nameOfIndividual':
        'APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message',
    'familyname':
        'APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_mandatory_message',
  };

  Map<String, Map<String, dynamic>> caregiverNameFields(dynamic config) {
    final flows = (config['flows'] as List).cast<Map>();
    final household = flows.firstWhere((f) => f['name'] == 'HOUSEHOLD');
    final page = (household['pages'] as List)
        .cast<Map>()
        .firstWhere((p) => p['page'] == 'caregiverConsent');
    return {
      for (final p in (page['properties'] as List).cast<Map>())
        if (names.containsKey(p['fieldName']))
          p['fieldName'] as String: Map<String, dynamic>.from(p),
    };
  }

  final configs = <String, dynamic>{
    'REGISTRATION.json': jsonDecode(
        File('${Directory.current.path}/assets/configs/json/REGISTRATION.json')
            .readAsStringSync()),
    'registration_flows.dart': sampleFlows,
  };

  for (final entry in configs.entries) {
    test('${entry.key}: both caregiver name fields are required, only on No',
        () {
      final fields = caregiverNameFields(entry.value);
      expect(fields.keys, unorderedEquals(names.keys));
      for (final field in fields.values) {
        final required = (field['validations'] as List)
            .cast<Map>()
            .where((v) => v['type'] == 'required')
            .toList();
        expect(required, hasLength(1), reason: field['fieldName']);
        expect(required.single['value'], true);
        expect(required.single['message'], names[field['fieldName']]);
        expect(jsonEncode(field['visibilityCondition']),
            contains('caregiverConsent.consentToParticipate==FALSE'));
      }
    });
  }

  for (final key in names.keys) {
    group('$key: the real field schema in the forms engine', () {
      final json = caregiverNameFields(configs['REGISTRATION.json'])[key]!;
      final schema = PropertySchema.fromJson(json);

      FormGroup form({String? searched}) => FormGroup({
            key: buildFormControl(key, schema, schema,
                defaultValues: searched == null ? null : {key: searched}),
          });
      void show(FormGroup f, bool visible) => VisibilityManager(
            schemaMap: {key: schema},
            form: f,
            formData: f.rawValue,
          ).toggleControlVisibility(key, visible, schema);

      test('Yes (hidden): empty name does not block', () {
        final f = form();
        show(f, false);
        expect(f.control(key).valid, isTrue);
      });

      test('No (shown): empty name is a required error', () {
        final f = form();
        show(f, true);
        expect(f.control(key).hasError(ValidationMessage.required), isTrue);
        f.control(key).value = '   ';
        expect(f.control(key).hasError(ValidationMessage.required), isTrue);
      });

      test('No (shown): the searched name restored on show satisfies it', () {
        final f = form(searched: 'Amara');
        show(f, false);
        show(f, true);
        expect(f.control(key).value, 'Amara');
        expect(f.control(key).valid, isTrue);
      });
    });
  }
}
