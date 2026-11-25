import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/helper/form_builder_helper.dart'
    show buildFormControl;
import 'package:digit_forms_engine/helper/validation_message_helper.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/stock_quantity_validations.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Stock in hand is counted in pieces, so a quantity typed in bales is
/// checked on its read-only Pieces row (bales x 50), not on the bales field;
/// a quantity typed in pieces is checked on the quantity itself.
void main() {
  // The stock product details page as loaded: properties in config order.
  final page = {
    for (final p in ((((sampleInventoryFlows as Map)['flows'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((f) => f['name'] == 'RECORDSTOCK')['pages'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['page'] == 'stockProductDetails')['properties']
        as List)
        .cast<Map<String, dynamic>>())
      p['fieldName'] as String: PropertySchema.fromJson(p),
  };

  Map<String, PropertySchema> checkFor(List<int> stockInHand,
          {Map<String, PropertySchema>? from}) =>
      stockCheckedQuantityFields(
        properties: from ?? page,
        configuredProperties: page,
        stockInHand: stockInHand,
        stockMessage: (max) => 'over $max',
      );

  List<String> rules(PropertySchema schema) => [
        for (final v in schema.validations ?? const <ValidationRule>[])
          '${v.type}=${v.value}',
      ];

  test('each product gets its own quantity and Pieces row, in place', () {
    final checked = checkFor([120, 80]);
    final keys = checked.keys.toList();

    for (final field in stockCheckedQuantities) {
      expect(keys, isNot(contains(field)));
      expect(keys, isNot(contains('${field}Pieces')));
      // Where the field was: the quantity's copies, then its Pieces row's.
      final at = keys.indexOf('${field}_item_0');
      expect(keys.sublist(at, at + 4), [
        '${field}_item_0',
        '${field}_item_1',
        '${field}Pieces_item_0',
        '${field}Pieces_item_1',
      ]);
    }
    expect(keys.indexOf('returnUnit'),
        lessThan(keys.indexOf('quantityReturned_item_0')));
    expect(keys.last, 'comment');
    expect(checked['quantityReceived'], page['quantityReceived'],
        reason: 'a receipt is not checked against stock in hand');
  });

  test('a bales/pieces quantity keeps its own max and steps aside for its '
      'Pieces row', () {
    final checked = checkFor([120, 80]);

    expect(rules(checked['quantitySent_item_1']!), [
      'required=true',
      'min=1',
      'max=10000000',
      'regex=^[0-9]+\$',
      'maxUnlessFilled={max: 80, unlessFilled: quantitySentPieces_item_1}',
    ]);
    expect(rules(checked['quantitySentPieces_item_1']!), ['max=80']);
    expect(checked['quantitySentPieces_item_1']!.computedValue,
        page['quantitySentPieces']!.computedValue);
  });

  test('a new selection replaces the copies, without stacking checks', () {
    final first = checkFor([120, 80]);
    final again = checkFor([50], from: first);

    expect(again.keys.where((k) => k.contains('_item_1')), isEmpty);
    expect(rules(again['quantityLostPieces_item_0']!), ['max=50']);
    expect(
        rules(again['quantityLost_item_0']!)
            .where((r) => r.startsWith('maxUnlessFilled')),
        ['maxUnlessFilled={max: 50, unlessFilled: quantityLostPieces_item_0}']);
    expect(again.keys.toList(), checkFor([50]).keys.toList());
  });

  group('checking stock in hand (120 pieces)', () {
    late FormGroup form;

    setUp(() {
      final checked = checkFor([120]);
      form = FormGroup({
        for (final name in ['quantitySent_item_0', 'quantitySentPieces_item_0'])
          name: buildFormControl(name, checked[name]!, checked[name]!,
              defaultValues: {}),
      });
    });

    AbstractControl<Object?> quantity() => form.control('quantitySent_item_0');
    AbstractControl<Object?> pieces() =>
        form.control('quantitySentPieces_item_0');

    test('typed in pieces, the quantity itself is checked', () {
      quantity().value = 130;
      expect(quantity().errors.keys, ['maxUnlessFilled']);

      quantity().value = 120;
      expect(quantity().valid, isTrue);
    });

    test('typed in bales, the Pieces row is checked instead', () {
      // The Pieces row shows 3 bales as 150 pieces: over stock in hand.
      pieces().value = '150';
      quantity().value = 3;
      expect(pieces().errors.keys, ['max']);
      expect(quantity().valid, isTrue, reason: 'bales are not pieces');

      pieces().value = '100';
      quantity().value = 2;
      expect(pieces().valid, isTrue);
    });

    test('the error reads the stock in hand message', () {
      final loc = FormLocalization(const Locale('en'), Future.value([]), []);
      final checked = checkFor([120]);

      expect(
          buildValidationMessages(
                  checked['quantitySent_item_0']!.validations, loc)[
              'maxUnlessFilled']!({}),
          'over 120');
      expect(
          buildValidationMessages(
              checked['quantitySentPieces_item_0']!.validations, loc)['max']!(
              {}),
          'over 120');
    });
  });
}
