import 'dart:convert';

import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:flutter_test/flutter_test.dart';

/// A field default of the form `{{navigation.x}}` is resolved only when a
/// form control is built for it. When its page is never opened the schema
/// still holds the template text, and submit used to hand that text over as
/// the field's value (QA, Liberia 2026-11-25: a household saved
/// `nameOfIndividual: {{navigation.firstName}}`).
void main() {
  group('isUnresolvedNavigationDefault', () {
    test('matches a value that is exactly one navigation template', () {
      for (final value in [
        '{{navigation.firstName}}',
        '{{ navigation.lastName }}',
        '  {{navigation.memberCount}}  ',
        '{{navigation.a.b}}',
      ]) {
        expect(FormsBloc.isUnresolvedNavigationDefault(value), isTrue,
            reason: value);
      }
    });

    test('leaves every other value alone', () {
      for (final value in [
        'Given',
        '',
        '{{mrnNumber}}',
        '{{senderFacilityId}}',
        '{{fn:teamPartyDisplay(navigation.receivedFromName, senderFacilityId)}}',
        'Hello {{navigation.firstName}}',
        '{{navigation.firstName}} {{navigation.lastName}}',
        '{{navigation.}}',
        '{navigation.firstName}',
        'navigation.firstName',
      ]) {
        expect(FormsBloc.isUnresolvedNavigationDefault(value), isFalse,
            reason: value);
      }
    });
  });

  test('submit hands over null for an unresolved navigation default only',
      () async {
    final bloc = FormsBloc();
    addTearDown(bloc.close);

    bloc.add(FormsEvent.load(schemas: [
      jsonEncode({
        'name': 'FORM',
        'version': 1,
        'pages': {
          'opened': {
            'type': 'object',
            'order': 1,
            'properties': {
              'typed': {'type': 'string', 'order': 1, 'value': 'Given'},
              'blank': {'type': 'string', 'order': 2, 'value': ' '},
            },
          },
          'neverOpened': {
            'type': 'object',
            'order': 2,
            'properties': {
              'name': {
                'type': 'string',
                'order': 1,
                'value': '{{navigation.firstName}}',
              },
              'count': {'type': 'integer', 'order': 2, 'value': '1'},
              'other': {'type': 'string', 'order': 3, 'value': '{{mrnNumber}}'},
              'hiddenKept': {
                'type': 'string',
                'order': 4,
                'hidden': true,
                'includeInForm': true,
                'value': '{{navigation.lastName}}',
              },
            },
          },
        },
      }),
    ]));
    await bloc.stream.first;

    bloc.add(const FormsEvent.submit(schemaKey: 'FORM'));
    final submitted = await bloc.stream
        .firstWhere((s) => s is FormsSubmittedState) as FormsSubmittedState;

    expect(submitted.formData, {
      'opened': {'typed': 'Given', 'blank': null},
      'neverOpened': {
        'name': null,
        'count': '1',
        'other': '{{mrnNumber}}',
        'hiddenKept': null,
      },
    });
  });
}
