import 'package:digit_flow_builder/utils/additional_fields_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Amit, 2026-11-26: no additional field may be saved with a null or empty
/// value (the server rejects a null value with 400 and the whole sync stops).
void main() {
  Map<String, dynamic> entity(List<dynamic> fields) => {
        'clientReferenceId': 'household',
        'memberCount': 2,
        'additionalFields': {
          'schema': 'Household',
          'version': 1,
          'fields': fields,
        },
      };

  List<dynamic> fieldsOf(Map<String, dynamic> map) =>
      (map['additionalFields'] as Map)['fields'] as List;

  test('empty means null or a string of nothing but spaces', () {
    for (final value in [null, '', ' ', '   ', '\n\t']) {
      expect(isEmptyAdditionalValue(value), isTrue, reason: '"$value"');
    }
    for (final value in ['x', ' x ', 0, 0.0, false, true, 'null', <String>[]]) {
      expect(isEmptyAdditionalValue(value), isFalse, reason: '"$value"');
    }
  });

  test('drops fields whose value is null or empty and keeps the rest in order',
      () {
    final cleaned = dropEmptyAdditionalFields(entity([
      {'key': 'caregiverConsent', 'value': 'TRUE'},
      {'key': 'nameOfIndividual', 'value': null},
      {'key': 'familyname', 'value': ''},
      {'key': 'childrenCount', 'value': 0},
      {'key': 'comments', 'value': '   '},
      {'key': 'isHeadOfFamily', 'value': false},
    ]))!;

    expect(fieldsOf(cleaned), [
      {'key': 'caregiverConsent', 'value': 'TRUE'},
      {'key': 'childrenCount', 'value': 0},
      {'key': 'isHeadOfFamily', 'value': false},
    ]);
    expect(cleaned['clientReferenceId'], 'household');
    expect(cleaned['memberCount'], 2);
    expect((cleaned['additionalFields'] as Map)['schema'], 'Household');
    expect((cleaned['additionalFields'] as Map)['version'], 1);
  });

  test('drops a value that is still template text', () {
    final cleaned = dropEmptyAdditionalFields(entity([
      {'key': 'nameOfIndividual', 'value': '{{navigation.firstName}}'},
      {'key': 'familyname', 'value': ' {{ navigation.lastName }} '},
      {'key': 'note', 'value': 'see {{this}}'},
      {'key': 'familyName', 'value': 'Family'},
    ]))!;

    expect(fieldsOf(cleaned), [
      {'key': 'note', 'value': 'see {{this}}'},
      {'key': 'familyName', 'value': 'Family'},
    ]);
  });

  test('returns null when there is nothing to drop', () {
    expect(
      dropEmptyAdditionalFields(entity([
        {'key': 'caregiverConsent', 'value': 'TRUE'},
        {'key': 'childrenCount', 'value': 0},
      ])),
      isNull,
    );
    expect(dropEmptyAdditionalFields({'clientReferenceId': 'x'}), isNull);
    expect(
      dropEmptyAdditionalFields(
          {'clientReferenceId': 'x', 'additionalFields': null}),
      isNull,
    );
    expect(dropEmptyAdditionalFields(entity(const [])), isNull);
  });

  test('does not change the map it was given', () {
    final original = entity([
      {'key': 'a', 'value': null},
      {'key': 'b', 'value': 'kept'},
    ]);

    dropEmptyAdditionalFields(original);

    expect(fieldsOf(original), hasLength(2));
  });

  test('cleans additional fields of nested records too', () {
    final cleaned = dropEmptyAdditionalFields({
      'clientReferenceId': 'task',
      'resources': [
        {
          'clientReferenceId': 'resource',
          'additionalFields': {
            'schema': 'TaskResource',
            'version': 1,
            'fields': [
              {'key': 'a', 'value': ''},
              {'key': 'b', 'value': 'kept'},
            ],
          },
        },
      ],
      'address': {
        'additionalFields': {
          'fields': [
            {'key': 'c', 'value': null},
          ],
        },
      },
    })!;

    expect(
      ((cleaned['resources'] as List).single as Map)['additionalFields']
          ['fields'],
      [
        {'key': 'b', 'value': 'kept'},
      ],
    );
    expect((cleaned['address'] as Map)['additionalFields']['fields'], isEmpty);
  });

  test('leaves a fields entry it cannot read as it is', () {
    final cleaned = dropEmptyAdditionalFields(entity([
      'not a field',
      {'key': 'a', 'value': null},
    ]))!;

    expect(fieldsOf(cleaned), ['not a field']);
  });

  test('an unresolved template is not a value', () {
    expect(isUnresolvedTemplate('{{formData.householdDetails.familyname}}'),
        isTrue);
    expect(isUnresolvedTemplate('  {{ navigation.mrnNumber }} '), isTrue);
    expect(isUnresolvedTemplate('Family'), isFalse);
    // Text that only contains a template is data.
    expect(isUnresolvedTemplate('Hello {{name}}'), isFalse);
    expect(isUnresolvedTemplate('{{first}} {{last}}'), isFalse);
    expect(isUnresolvedTemplate(''), isFalse);
    expect(isUnresolvedTemplate(null), isFalse);
    expect(isUnresolvedTemplate(3), isFalse);
  });
}
