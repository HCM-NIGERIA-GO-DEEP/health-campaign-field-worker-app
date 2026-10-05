import 'package:digit_forms_engine/helper/validator_helper.dart';
import 'package:digit_forms_engine/helper/visibility_manager.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

void main() {
  group('VisibilityManager.toggleControlVisibility', () {
    PropertySchema quantitySchema({int? max}) => PropertySchema(
          type: PropertySchemaType.integer,
          validations: [
            const ValidationRule(type: 'required', value: true, message: 'Required'),
            const ValidationRule(type: 'min', value: 1, message: 'Too small'),
            if (max != null)
              ValidationRule(type: 'max', value: max, message: 'Too large'),
          ],
        );

    VisibilityManager managerFor(FormGroup form) =>
        VisibilityManager(schemaMap: {}, form: form, formData: {});

    // Mirrors the stock issue flow: the Product Details page builds before
    // the stock-in-hand search finishes, so the field's first schema has no
    // `max` rule. The rule arrives on a later build with the same visibility.
    test('applies validation rules added to the schema after the first build',
        () {
      final initial = quantitySchema();
      final form = FormGroup({
        'quantitySent_item_0':
            FormControl<int>(validators: buildValidators(initial)),
      });
      final manager = managerFor(form);

      manager.toggleControlVisibility('quantitySent_item_0', true, initial);
      form.control('quantitySent_item_0').value = 50;
      expect(form.control('quantitySent_item_0').valid, isTrue);

      manager.toggleControlVisibility(
          'quantitySent_item_0', true, quantitySchema(max: 10));
      expect(form.control('quantitySent_item_0').hasError('max'), isTrue);
    });

    test('does not re-emit when visibility and rules are unchanged', () {
      final schema = quantitySchema(max: 10);
      final form = FormGroup({
        'quantitySent_item_0':
            FormControl<int>(validators: buildValidators(schema)),
      });
      final manager = managerFor(form);
      final control = form.control('quantitySent_item_0');

      manager.toggleControlVisibility('quantitySent_item_0', true, schema);

      var statusEvents = 0;
      final sub = control.statusChanged.listen((_) => statusEvents++);
      // A rebuild hands over an equal (not identical) schema.
      manager.toggleControlVisibility(
          'quantitySent_item_0', true, quantitySchema(max: 10));
      sub.cancel();

      expect(statusEvents, 0);
    });

    test('clears validators and value when the field is hidden', () {
      final schema = quantitySchema(max: 10);
      final form = FormGroup({
        'quantitySent_item_0':
            FormControl<int>(validators: buildValidators(schema), value: 50),
      });
      final manager = managerFor(form);

      manager.toggleControlVisibility('quantitySent_item_0', false, schema);
      final control = form.control('quantitySent_item_0');
      expect(control.value, isNull);
      expect(control.valid, isTrue);
    });
  });
}
