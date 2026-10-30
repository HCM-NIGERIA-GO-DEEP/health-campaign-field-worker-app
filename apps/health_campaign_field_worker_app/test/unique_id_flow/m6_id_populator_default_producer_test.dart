// RC-11 (ruled out) and the funnel's last step: the hidden `identifiers`
// control is the single producer of `DEFAULT, <uuid>`
// (form_builder_helper.dart:79-115). It stores a pool ID exactly when the
// navigation parameter UNIQUE_BENEFICIARY_ID is a non-empty string.
import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const kHidden = PropertySchema(
  type: PropertySchemaType.string,
  format: PropertySchemaFormat.idPopulator,
  hidden: true,
);
const kParent = PropertySchema(type: PropertySchemaType.object);
const kDefaults = {
  'availableIDs': {'DEFAULT': 'DEF-1'}
};

dynamic controlValue({
  Map<String, dynamic>? nav,
  Map<String, dynamic>? defaults = kDefaults,
  PropertySchema schema = kHidden,
}) =>
    buildFormControl(
      'identifiers',
      schema,
      kParent,
      defaultValues: defaults,
      navigationParams: nav,
    ).value;

void main() {
  test('no navigation parameter → DEFAULT with the generated id', () {
    expect(controlValue(nav: null), 'DEFAULT, DEF-1');
    expect(controlValue(nav: {}), 'DEFAULT, DEF-1');
  });

  test('an empty parameter → DEFAULT (null and empty are the same)', () {
    expect(controlValue(nav: {'UNIQUE_BENEFICIARY_ID': ''}), 'DEFAULT, DEF-1');
  });

  test('a pool ID in the parameter → UNIQUE_BENEFICIARY_ID', () {
    expect(
      controlValue(nav: {'UNIQUE_BENEFICIARY_ID': 'ID-1'}),
      'UNIQUE_BENEFICIARY_ID, ID-1',
    );
  });

  test('characterization: availableIDs with a UNIQUE key wins without a parameter', () {
    // Dead in production: screen_builder.dart:391 sets only DEFAULT.
    expect(
      controlValue(
        nav: null,
        defaults: {
          'availableIDs': {'UNIQUE_BENEFICIARY_ID': 'POOL-9', 'DEFAULT': 'DEF-1'}
        },
      ),
      'UNIQUE_BENEFICIARY_ID, POOL-9',
    );
  });

  test('characterization: no defaults at all bakes the literal "null"', () {
    expect(controlValue(nav: null, defaults: null), 'DEFAULT, null');
  });

  test('characterization: a non-String parameter throws', () {
    expect(
      () => controlValue(nav: {'UNIQUE_BENEFICIARY_ID': 123}),
      throwsA(isA<TypeError>()),
    );
  });

  test('characterization: an existing UNIQUE value is kept in edit mode', () {
    expect(
      controlValue(
        nav: {'UNIQUE_BENEFICIARY_ID': 'ID-1'},
        defaults: {
          'identifiers': 'UNIQUE_BENEFICIARY_ID, OLD',
          ...kDefaults,
        },
      ),
      'UNIQUE_BENEFICIARY_ID, OLD',
    );
  });

  test('characterization: a visible control starts empty', () {
    const visible = PropertySchema(
      type: PropertySchemaType.string,
      format: PropertySchemaFormat.idPopulator,
      hidden: false,
    );
    expect(controlValue(nav: {'UNIQUE_BENEFICIARY_ID': 'ID-1'}, schema: visible),
        isNull);
  });
}
