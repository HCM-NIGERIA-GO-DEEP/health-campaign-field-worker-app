import 'package:digit_forms_engine/helper/computed_value_binding.dart';
import 'package:digit_forms_engine/helper/secondary_popup_values.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/utils/computed_value.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Sierra Leone ITN: the stock Accept screen and its Partially-accept popup show
/// the bale equivalent of a quantity in pieces (50 pieces = 1 bale), worked out
/// automatically and not editable. 60 pieces show as "1.20".
void main() {
  group('divideForDisplay', () {
    test('divides and keeps the configured decimals', () {
      expect(divideForDisplay(60, 50, 2), '1.20');
      expect(divideForDisplay(50, 50, 2), '1.00');
      expect(divideForDisplay(1, 50, 2), '0.02');
      expect(divideForDisplay(0, 50, 2), '0.00');
      expect(divideForDisplay(125, 50, 1), '2.5');
    });

    test('reads numbers typed as text, as form and popup values are', () {
      expect(divideForDisplay('60', 50, 2), '1.20');
      expect(divideForDisplay(' 40 ', 50, 2), '0.80');
      expect(divideForDisplay(60.0, 50, 2), '1.20');
    });

    test('gives null instead of throwing for anything it cannot divide', () {
      expect(divideForDisplay(null, 50, 2), isNull);
      expect(divideForDisplay('', 50, 2), isNull);
      expect(divideForDisplay('abc', 50, 2), isNull);
      expect(divideForDisplay(-5, 50, 2), isNull);
      expect(divideForDisplay(60, 0, 2), isNull);
      expect(divideForDisplay(60, -50, 2), isNull);
      expect(divideForDisplay(60, 50, -1), isNull);
      expect(divideForDisplay(double.nan, 50, 2), isNull);
      expect(divideForDisplay(double.infinity, 50, 2), isNull);
    });
  });

  group('ComputedValueConfig in config JSON', () {
    test('a form field reads computedValue', () {
      final schema = PropertySchema.fromJson({
        'type': 'string',
        'readOnly': true,
        'computedValue': {
          'sourceField': 'quantity',
          'divideBy': 50,
          'decimals': 2,
        },
      });
      expect(schema.computedValue,
          const ComputedValueConfig(sourceField: 'quantity', divideBy: 50));
    });

    test('decimals defaults to 2; a field without it has none', () {
      final schema = PropertySchema.fromJson({
        'type': 'string',
        'computedValue': {'sourceField': 'quantity', 'divideBy': 50},
      });
      expect(schema.computedValue?.decimals, 2);
      expect(PropertySchema.fromJson({'type': 'string'}).computedValue, isNull);
    });

    test('a malformed computedValue is ignored, not a crash', () {
      for (final bad in <dynamic>[
        '50',
        50,
        <String, dynamic>{},
        {'sourceField': 'quantity', 'divideBy': '50'},
        {'sourceField': 7, 'divideBy': 50},
      ]) {
        final schema = PropertySchema.fromJson(
            {'type': 'string', 'computedValue': bad});
        expect(schema.computedValue, isNull, reason: 'value: $bad');
      }
    });

    test('a popup body field reads computedValue', () {
      final field = SecondaryAlertBodyField.fromJson({
        'type': 'string',
        'label': 'BALES',
        'fieldName': 'actualBalesReceived',
        'computedValue': {
          'sourceField': 'actualQuantityReceived',
          'divideBy': 50,
        },
      });
      expect(field.computedValue?.sourceField, 'actualQuantityReceived');
      expect(field.computedValue?.divideBy, 50);
    });
  });

  group('ComputedValueBinding (Accept screen form)', () {
    const config = ComputedValueConfig(sourceField: 'quantity', divideBy: 50);

    FormGroup buildForm(Object? quantity) => FormGroup({
          'quantity': FormControl<int>(value: quantity as int?),
          'bales': FormControl<String>(),
        });

    test('fills the target as soon as it starts', () {
      final form = buildForm(60);
      final binding = ComputedValueBinding(
          form: form, targetControlName: 'bales', config: config)
        ..start();
      addTearDown(binding.dispose);

      expect(form.control('bales').value, '1.20');
    });

    test('follows the source field when it changes', () async {
      final form = buildForm(60);
      final binding = ComputedValueBinding(
          form: form, targetControlName: 'bales', config: config)
        ..start();
      addTearDown(binding.dispose);

      form.control('quantity').value = 40;
      await pumpEventQueue();
      expect(form.control('bales').value, '0.80');

      form.control('quantity').value = null;
      await pumpEventQueue();
      expect(form.control('bales').value, isNull,
          reason: 'a stale bale count must not stay on screen');
    });

    test('stops following after dispose', () async {
      final form = buildForm(60);
      ComputedValueBinding(
          form: form, targetControlName: 'bales', config: config)
        ..start()
        ..dispose();

      form.control('quantity').value = 40;
      await pumpEventQueue();
      expect(form.control('bales').value, '1.20');
    });

    test('a missing source or target field leaves the form alone', () {
      final noSource = FormGroup({'bales': FormControl<String>()});
      final noTarget = FormGroup({'quantity': FormControl<int>(value: 60)});

      for (final form in [noSource, noTarget]) {
        final binding = ComputedValueBinding(
            form: form, targetControlName: 'bales', config: config);
        expect(binding.start, returnsNormally);
        binding.dispose();
      }
      expect(noSource.control('bales').value, isNull);
    });
  });

  group('Partially-accept popup values', () {
    const quantityField = SecondaryAlertBodyField(
        type: 'integer',
        label: 'QTY',
        format: 'numeric',
        fieldName: 'actualQuantityReceived',
        mandatory: true);
    const balesField = SecondaryAlertBodyField(
        type: 'string',
        label: 'BALES',
        fieldName: 'actualBalesReceived',
        mandatory: true,
        computedValue: ComputedValueConfig(
            sourceField: 'actualQuantityReceived', divideBy: 50));
    const commentField = SecondaryAlertBodyField(
        type: 'string',
        label: 'COMMENT',
        format: 'textArea',
        fieldName: 'rejectComment',
        mandatory: true);

    test('the computed field shows the typed quantity in bales', () {
      expect(
          computedPopupText(balesField, {'actualQuantityReceived': '40'}),
          '0.80');
      expect(computedPopupText(balesField, {'actualQuantityReceived': ''}), '');
      expect(computedPopupText(balesField, {}), '');
      expect(computedPopupText(quantityField, {'actualQuantityReceived': '40'}),
          isNull,
          reason: 'only fields with computedValue are computed');
    });

    test('confirm hands back typed values only, never the computed one', () {
      final data = secondaryPopupData(
        [quantityField, balesField, commentField],
        {
          'actualQuantityReceived': ' 40 ',
          'actualBalesReceived': '0.80',
          'rejectComment': ' wet ',
        },
      );
      expect(data, {
        'actualQuantityReceived': '40',
        'rejectComment': 'wet',
      });
    });

    test('the page values ride along under the page name', () {
      final data = secondaryPopupData(
        [commentField],
        {'rejectComment': 'torn'},
        pageName: 'stockReceiptDetails',
        pageValues: {'scannedStock': 'x', 'bales': '1.20'},
      );
      expect(data, {
        'stockReceiptDetails': {'scannedStock': 'x', 'bales': '1.20'},
        'rejectComment': 'torn',
      });
      expect(
          secondaryPopupData([commentField], {'rejectComment': 'torn'},
              pageName: '', pageValues: {'a': 1}),
          {'rejectComment': 'torn'},
          reason: 'no page name, nothing added');
    });

    test('isComputedPopupField tells the popup which fields to skip', () {
      expect(isComputedPopupField(balesField), isTrue);
      expect(isComputedPopupField(quantityField), isFalse);
    });
  });
}
