import 'dart:convert';

import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:digit_forms_engine/helper/validation_message_helper.dart';
import 'package:digit_forms_engine/helper/validator_helper.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/models/schema_object/schema_object.dart';
import 'package:digit_forms_engine/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// QA (Liberia, 2026-11-25): a household had 3 members and 2 children, both
/// children were registered, then the household was edited to 1 member and 0
/// children. householdOverview disables Back/Close while the registered
/// children differ from the children count (fn:isUnder5CountMismatch), and a
/// child cannot be removed, so the registrar was stuck.
///
/// Amit's decision: block it at edit time. On a household edit the children
/// count may not go below the number of children already registered.
///   * a household edit passes that number as `registeredChildCount`;
///   * `childrenCount` has a `min` rule reading `navigation.registeredChildCount`.
///
/// 2026-11-27 (QA sheet of 2026-11-26, row 6; Amit): the head's Edit opens the
/// individual form again (head_edit_individual_form_test), so no route edits
/// the counts of a registered household today and none passes
/// `registeredChildCount`. The rule stays for the day such a route returns;
/// these tests keep it working.
class _Texts {
  String translate(String key) => 'text of $key';
}

void main() {
  late List<Map<String, dynamic>> flows;

  setUpAll(() {
    flows = ((sampleFlows as Map)['flows'] as List).cast<Map<String, dynamic>>();
  });

  group('children count on Household Details', () {
    late PropertySchema page;
    late PropertySchema childrenCount;

    setUpAll(() {
      final household = flows.firstWhere(
          (f) => f['name'] == 'HOUSEHOLD' && f['screenType'] == 'FORM');
      final schema = SchemaObject.fromJson(
          jsonDecode(jsonEncode(transformJson(household))) as Map<String, dynamic>);
      page = schema.pages['householdDetails']!;
      childrenCount = page.properties!['childrenCount']!;
    });

    tearDown(() => unregisterNavigationParams('HOUSEHOLD'));

    Map<String, dynamic>? errorsFor(int value) {
      final control = buildFormControl(
        'childrenCount',
        childrenCount,
        page,
        schemaKey: 'HOUSEHOLD',
      );
      control.value = value;
      control.markAsTouched();
      return control.hasErrors ? control.errors : null;
    }

    test('an edit cannot go below the children already registered', () {
      registerNavigationParams('HOUSEHOLD', {'registeredChildCount': 2});

      expect(errorsFor(0)?.keys, contains('min'));
      expect(errorsFor(1)?.keys, contains('min'));
      expect(errorsFor(2), isNull);
      expect(errorsFor(3), isNull);
    });

    test('the number arrives as text from navigation and still applies', () {
      registerNavigationParams('HOUSEHOLD', {'registeredChildCount': '2'});

      expect(errorsFor(1)?.keys, contains('min'));
      expect(errorsFor(2), isNull);
    });

    test('a new registration has no floor', () {
      registerNavigationParams('HOUSEHOLD', {'startPage': 'beneficiaryLocation'});

      expect(errorsFor(0), isNull);
    });

    test('an APK without the fn passes an empty value and the rule is skipped',
        () {
      registerNavigationParams('HOUSEHOLD', {'registeredChildCount': ''});

      expect(errorsFor(0), isNull);
    });

    test('the stepper minimum stays 0 and a floor error shows its own text',
        () {
      final rules = childrenCount.validations!;
      // The stepper takes its lower bound from the first min rule.
      expect(minFromValidations(rules), 0);

      // One message per error key: the LAST min rule's text is the one shown
      // for a `min` error, so the floor rule must come after "min": "0".
      final messages = buildValidationMessages(rules, _Texts());
      expect(
        messages['min']!(const {}),
        'text of APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_registered_min_message',
      );
    });
  });
}
