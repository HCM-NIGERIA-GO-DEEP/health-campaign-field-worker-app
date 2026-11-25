import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:digit_forms_engine/helper/visibility_manager.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Sierra Leone QA rows 10 and 13: names on the caregiver consent page.
///
/// The page's first and last name fields are visible only while
/// consentToParticipate == FALSE. VisibilityManager.toggleControlVisibility
/// runs on every build of a conditional field and reset() the control
/// whenever it is hidden. That wiped:
///  - row 10: the name typed in the search bar, which the Register button
///    hands to the form as a default value. The field starts hidden, so the
///    default is erased before the user ever picks "No".
///  - row 13: names the user typed after picking "No", once they switched to
///    "Yes" and back to "No".
///
/// A hidden field must still hold no value, because hidden values must not be
/// saved. The value it held is kept aside and put back when it is shown again.
void main() {
  const field = 'nameOfIndividual';
  const schema = PropertySchema(type: PropertySchemaType.string);

  FormGroup buildForm({Map<String, dynamic>? defaultValues}) => FormGroup({
        field: buildFormControl(
          field,
          schema,
          schema,
          defaultValues: defaultValues,
        ),
      });

  void toggle(FormGroup form, bool isVisible) => VisibilityManager(
        schemaMap: {field: schema},
        form: form,
        formData: form.rawValue,
      ).toggleControlVisibility(field, isVisible, schema);

  test('row 10: the searched name reappears when the field is first shown',
      () {
    final form = buildForm(defaultValues: {field: 'Amara'});

    // First build: consent not answered yet, so the field is hidden.
    toggle(form, false);
    expect(form.control(field).value, isNull,
        reason: 'a hidden field must hold no value');

    // The user picks "No": the field is shown.
    toggle(form, true);
    expect(form.control(field).value, 'Amara');
  });

  test('row 13: typed names come back after switching to Yes and back to No',
      () {
    final form = buildForm();
    toggle(form, true);
    form.control(field).value = 'Fatu';

    toggle(form, false); // "Yes"
    expect(form.control(field).value, isNull);

    toggle(form, true); // "No" again
    expect(form.control(field).value, 'Fatu');
  });

  test('repeated builds while hidden keep the value aside', () {
    final form = buildForm();
    toggle(form, true);
    form.control(field).value = 'Fatu';

    // The field widget rebuilds many times while hidden; each build toggles.
    toggle(form, false);
    toggle(form, false);
    toggle(form, false);

    toggle(form, true);
    expect(form.control(field).value, 'Fatu');
  });

  test('a value the user cleared is not brought back later', () {
    final form = buildForm(defaultValues: {field: 'Amara'});
    toggle(form, false);
    toggle(form, true);
    expect(form.control(field).value, 'Amara');

    // The user deletes the restored name, then hides and shows the field.
    form.control(field).value = null;
    toggle(form, true); // more builds while visible
    toggle(form, false);
    toggle(form, true);

    expect(form.control(field).value, isNull);
  });

  test('a visible field keeps its current value on every build', () {
    final form = buildForm(defaultValues: {field: 'Amara'});
    toggle(form, true);
    form.control(field).value = 'Kadiatu';
    toggle(form, true);

    expect(form.control(field).value, 'Kadiatu');
  });
}
