import 'package:digit_forms_engine/helper/validator_helper.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// A household always has at least one non-child member - the head - so
/// childrenCount can never equal memberCount. The form accepted 7 children in
/// a 7-member household because `maxField` could only express
/// "<= memberCount", with no way to shift the ceiling.
///
/// `maxField` now also takes {"field": ..., "offset": ...}. pregnantWomenCount
/// deliberately keeps the plain form: a pregnant woman can be the only member
/// of her household, and she may also be counted among the children.
void main() {
  bool childrenValid({
    required int members,
    required int children,
    required Object maxFieldValue,
  }) {
    final schema = PropertySchema(
      type: PropertySchemaType.integer,
      label: 'Number of children',
      validations: [
        ValidationRule(
          type: 'maxField',
          value: maxFieldValue,
          message: 'Too many children',
        ),
      ],
    );

    final form = FormGroup({
      'memberCount': FormControl<String>(value: members.toString()),
      // buildValidators is called without an explicit type argument, the
      // same way the form engine calls it - its internal
      // `Validators.delegate(...) as Validator<T>` casts only hold for
      // dynamic.
      'childrenCount': FormControl<String>(
        value: children.toString(),
        validators: buildValidators(schema),
      ),
    });

    // The delegate validator reads control.parent, which is not attached
    // while FormGroup's constructor runs, so the first validation pass sees
    // no sibling. Re-run it now the group is built - the live form does the
    // same via ValidationContextManager when memberCount changes.
    form.control('childrenCount').updateValueAndValidity();
    return form.control('childrenCount').valid;
  }

  const offsetRule = {'field': 'memberCount', 'offset': -1};

  group('children must leave room for a head of household', () {
    test('7 children in a 7-member household is rejected', () {
      expect(
        childrenValid(members: 7, children: 7, maxFieldValue: offsetRule),
        isFalse,
      );
    });

    test('6 children in a 7-member household is accepted', () {
      expect(
        childrenValid(members: 7, children: 6, maxFieldValue: offsetRule),
        isTrue,
      );
    });

    test('more children than members is still rejected', () {
      expect(
        childrenValid(members: 3, children: 5, maxFieldValue: offsetRule),
        isFalse,
      );
    });

    test('a single-member household admits no children', () {
      expect(
        childrenValid(members: 1, children: 1, maxFieldValue: offsetRule),
        isFalse,
      );
      expect(
        childrenValid(members: 1, children: 0, maxFieldValue: offsetRule),
        isTrue,
      );
    });

    test('an empty household does not report a negative ceiling', () {
      // memberCount 0 would give a ceiling of -1; it is clamped to 0 so the
      // only error surfaced is memberCount's own min validation.
      expect(
        childrenValid(members: 0, children: 0, maxFieldValue: offsetRule),
        isTrue,
      );
    });
  });

  group('the plain string form is unchanged', () {
    test('equal to the ceiling is still allowed without an offset', () {
      expect(
        childrenValid(members: 7, children: 7, maxFieldValue: 'memberCount'),
        isTrue,
      );
    });

    test('above the ceiling is still rejected without an offset', () {
      expect(
        childrenValid(members: 7, children: 8, maxFieldValue: 'memberCount'),
        isFalse,
      );
    });
  });
}
