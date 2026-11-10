import 'dart:convert';
import 'dart:io';

import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// Household details asks the registrar to note down the e-token before
/// moving on to the checklist (showNextAlertPopUp).
void main() {
  const expectedPopup = {
    'title': 'REGISTRATION_ETOKEN_POPUP_TITLE',
    'description': 'REGISTRATION_ETOKEN_POPUP_DESCRIPTION',
    'primaryActionLabel': 'ACTION_SUBMIT',
    'secondaryActionLabel': 'ACTION_CANCEL',
    'conditions': [
      {'expression': 'DEFAULT', 'value': '{{navigation.beneficiaryId}}'}
    ],
  };

  for (final entry in <String, Map<String, dynamic>>{
    'Dart fallback': Map<String, dynamic>.from(sampleFlows as Map),
    'bundled JSON': jsonDecode(
            File('assets/configs/json/REGISTRATION.json').readAsStringSync())
        as Map<String, dynamic>,
  }.entries) {
    group(entry.key, () {
      final flows = (entry.value['flows'] as List).cast<Map<String, dynamic>>();
      final schema =
          transformJson(flows.singleWhere((f) => f['name'] == 'HOUSEHOLD'));
      final pages = (schema['pages'] as Map).cast<String, dynamic>();
      final details = Map<String, dynamic>.from(pages['householdDetails']);

      test('householdDetails carries the e-token popup with Submit/Cancel', () {
        expect(details['showNextAlertPopUp'], expectedPopup);
        final parsed = PropertySchema.fromJson(details).showNextAlertPopUp!;
        expect(parsed.primaryActionLabel, 'ACTION_SUBMIT');
        expect(parsed.secondaryActionLabel, 'ACTION_CANCEL');
        expect(parsed.conditions!.single.value, '{{navigation.beneficiaryId}}');
      });

      test('no other registration form page has it', () {
        for (final flow in flows.where((f) => f['screenType'] == 'FORM')) {
          for (final page in (flow['pages'] as List).cast<Map>()) {
            if (flow['name'] == 'HOUSEHOLD' &&
                page['page'] == 'householdDetails') continue;
            expect(page['showNextAlertPopUp'], isNull,
                reason: '${flow['name']}.${page['page']}');
          }
        }
      });

      test(
          'it fires only on the Next to the checklist (new and closed '
          'households); ordinary edits still submit directly', () {
        // forms_render shows the popup only when it pushes the next form
        // page, which for this page is this conditionalNavigateTo; the
        // interceptor reserves the e-token on exactly this transition.
        expect(details['conditionalNavigateTo'], [
          {
            'condition': 'isEdit != true || isClosedHousehold == true',
            'navigateTo': {
              'name': 'registrationHealthTalkChecklist',
              'type': 'form'
            },
          }
        ]);
        expect(details['submitCondition'], {
          'expression': [
            {'condition': 'isEdit == true && isClosedHousehold != true'}
          ]
        });
      });

      test('the checklist keeps its own final Submit/Cancel confirmation', () {
        final checklist = Map<String, dynamic>.from(
            pages['registrationHealthTalkChecklist']);
        expect(checklist['showAlertPopUp'], {
          'title': 'APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE',
          'description': 'HOUSEHOLD_CHECKLIST_SUBMIT_DESCRIPTION',
          'primaryActionLabel': 'ACTION_SUBMIT',
          'secondaryActionLabel': 'ACTION_CANCEL',
        });
        expect(checklist['showNextAlertPopUp'], isNull);
      });
    });
  }
}
