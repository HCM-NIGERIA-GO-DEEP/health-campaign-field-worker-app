import 'dart:convert';
import 'dart:io';

import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:digit_forms_engine/helper/visibility_manager.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/models/schema_object/schema_object.dart';
import 'package:digit_forms_engine/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// QA (Liberia, sheet of 2026-11-26, row 6): "the household edit need to
/// revert and hide the DOB".
///
/// Amit's decisions (2026-11-27):
///   * the head's Edit on householdOverview opens the individual form
///     (ADD_MEMBER) again, for every head; it no longer opens Household
///     Details, so the member and children counts cannot be edited after
///     registration;
///   * a field that the create screen does not have is not on the edit screen
///     either: the head is created on Household Details, which has no date of
///     birth, so the individual form hides it for the head;
///   * a child is created on the individual form with a required date of
///     birth, so the child's add and edit keep it.
void main() {
  final copies = <String, List<Map<String, dynamic>> Function()>{
    'Dart copy': () =>
        ((sampleFlows as Map)['flows'] as List).cast<Map<String, dynamic>>(),
    'REGISTRATION.json': () => ((jsonDecode(
      File('assets/configs/json/REGISTRATION.json').readAsStringSync(),
    ) as Map)['flows'] as List)
        .cast<Map<String, dynamic>>(),
  };

  Map<String, dynamic>? findByFieldName(dynamic node, String fieldName) {
    if (node is Map) {
      if (node['fieldName'] == fieldName) return node.cast<String, dynamic>();
      for (final v in node.values) {
        final hit = findByFieldName(v, fieldName);
        if (hit != null) return hit;
      }
    } else if (node is List) {
      for (final v in node) {
        final hit = findByFieldName(v, fieldName);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  /// Every NAVIGATION under [node] as (target name, data).
  List<({String name, Map<String, dynamic> data})> navigations(dynamic node) {
    final found = <({String name, Map<String, dynamic> data})>[];
    void walk(dynamic n) {
      if (n is Map) {
        if (n['actionType'] == 'NAVIGATION' && n['properties'] is Map) {
          final props = n['properties'] as Map;
          found.add((
            name: props['name'].toString(),
            data: {
              for (final d in (props['data'] as List? ?? const []))
                (d as Map)['key'] as String: d['value'],
            },
          ));
        }
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(node);
    return found;
  }

  for (final copy in copies.entries) {
    group(copy.key, () {
      late List<Map<String, dynamic>> flows;
      late PropertySchema page;
      late PropertySchema dob;

      setUpAll(() {
        flows = copy.value();
        final addMember = flows.firstWhere(
            (f) => f['name'] == 'ADD_MEMBER' && f['screenType'] == 'FORM');
        final schema = SchemaObject.fromJson(
            jsonDecode(jsonEncode(transformJson(addMember)))
                as Map<String, dynamic>);
        page = schema.pages['beneficiaryDetails']!;
        dob = page.properties!['dobPicker']!;
      });

      test('the Edit button on the overview opens the individual form only',
          () {
        final overview =
            flows.firstWhere((f) => f['name'] == 'householdOverview');
        final edit = findByFieldName(overview, 'editIndividualButton')!;
        final targets = navigations(edit['onAction']);

        expect(targets, isNotEmpty);
        for (final target in targets) {
          expect(target.name, 'ADD_MEMBER',
              reason: 'the head must not be sent to Household Details');
          expect(target.data['isEdit'], 'true');
          // The individual form tells head from child by this value.
          expect(target.data['isHead'], '{{fn:isHead(item.member)}}');
        }

        // Head and child take the same branches (with / without an ID).
        final conditions = [
          for (final branch in edit['onAction'] as List)
            ((branch as Map)['condition'] as Map)['expression'].toString(),
        ];
        expect(conditions.where((c) => c.contains('isHead')), isEmpty);
      });

      bool dobShown(Map<String, dynamic> values) {
        final condition = dob.visibilityCondition;
        if (condition == null || condition.expression.isEmpty) return true;
        return evaluateVisibilityExpression(condition.expression, values);
      }

      test('the head does not see the date of birth', () {
        expect(dob.hidden, isNot(true));
        expect(dobShown({'navigation.isHead': true}), isFalse);
        expect(dobShown({'navigation.isHead': 'true'}), isFalse);
      });

      test('a child sees the date of birth on add and on edit', () {
        expect(dobShown({'navigation.isHead': false}), isTrue);
        expect(dobShown({'navigation.isHead': 'false'}), isTrue);
      });

      test('a route that passes no isHead would hide the date of birth, so '
          'every route into the individual form passes it', () {
        // The condition language cannot say "missing": an unknown name makes
        // the whole condition false, and false hides the field.
        expect(dobShown({'navigation.isEdit': 'true'}), isFalse);

        final targets =
            navigations(flows).where((t) => t.name == 'ADD_MEMBER').toList();
        expect(targets, hasLength(4),
            reason: 'Add Member, its "few IDs left" popup, and Edit with / '
                'without an ID');
        for (final target in targets) {
          expect(
            target.data['isHead'],
            anyOf('false', '{{fn:isHead(item.member)}}'),
            reason: 'data: ${target.data}',
          );
        }
      });

      test('a hidden date of birth does not block the head\'s submit, a shown '
          'one is still required', () {
        final control = buildFormControl(
          'dobPicker',
          dob,
          page,
          schemaKey: 'ADD_MEMBER',
        );
        final form = FormGroup({'dobPicker': control});
        VisibilityManager manager() => VisibilityManager(
              schemaMap: {'dobPicker': dob},
              form: form,
              formData: const {},
            );

        manager().toggleControlVisibility('dobPicker', false, dob);
        expect(control.value, isNull);
        expect(form.valid, isTrue);

        manager().toggleControlVisibility('dobPicker', true, dob);
        expect(form.valid, isFalse);
        expect(control.errors.keys, contains('required'));
      });
    });
  }
}
