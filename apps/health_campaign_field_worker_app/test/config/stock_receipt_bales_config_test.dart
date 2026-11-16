import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_scanner/utils/scanned_stock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';

/// Sierra Leone ITN: on the stock Accept screen every receiver may scan the
/// bales that arrived (a record only - nothing is checked), and the screen and
/// its Partially-accept popup show the quantity in bales (50 pieces = 1 bale),
/// worked out automatically and greyed out. Quantities stay in pieces.
void main() {
  late Map<String, dynamic> page;

  setUpAll(() {
    final flows =
        ((sampleInventoryFlows as Map)['flows'] as List).cast<Map<String, dynamic>>();
    final flow = flows.firstWhere((f) => f['name'] == 'stockReceiptDetails');
    page = (flow['pages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['page'] == 'stockReceiptDetails');
  });

  List<Map<String, dynamic>> properties() =>
      (page['properties'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> property(String name) =>
      properties().firstWhere((p) => p['fieldName'] == name,
          orElse: () => fail('stockReceiptDetails has no "$name" field'));

  Map<String, dynamic> popupField(String name) =>
      ((page['showSecondaryAlertPopUp'] as Map)['body'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => f['fieldName'] == name,
              orElse: () => fail('the popup has no "$name" field'));

  num order(String name) => property(name)['order'] as num;

  group('Accept screen', () {
    test('bales is greyed out and worked out from the dispatched quantity', () {
      final bales = PropertySchema.fromJson(property('bales'));
      expect(bales.type, PropertySchemaType.string);
      expect(bales.readOnly, isTrue);
      expect(bales.computedValue,
          const ComputedValueConfig(sourceField: 'quantity', divideBy: 50));
    });

    test('the stock scan is optional, unlimited and records only', () {
      final scan = PropertySchema.fromJson(property('scannedStock'));
      expect(scan.format, PropertySchemaFormat.scanner);
      expect(
          scan.validations?.where((v) => v.type == 'required' && v.value == true),
          isEmpty);
      expect(scan.validations?.where((v) => v.type == 'scanLimit'), isEmpty,
          reason: 'no limit');
      expect(scan.dynamicScanLimit, isNull, reason: 'no limit');
      expect(scan.comparisonConfig, isNull,
          reason: 'record only: no duplicate or must-match check');
      expect(scan.visibilityCondition, isNull, reason: 'every receiver sees it');
    });

    test('a bale is a code with (00), a piece a code with (21)', () {
      final scan = PropertySchema.fromJson(property('scannedStock'));
      final rules = scanTypeRulesFrom(scan.validations
          ?.firstWhere((v) => v.type == scanTypesValidationType)
          .value);
      expect(
          rules.map((r) => [r.type, r.ai, r.saveKey]),
          [
            ['bale', '00', 'baleScannedStock'],
            ['piece', '21', 'piecesScannedStock'],
          ]);
    });

    test('bales and the scan sit between quantity and comment', () {
      expect(order('quantity'), lessThan(order('bales')));
      expect(order('bales'), lessThan(order('scannedStock')));
      expect(order('scannedStock'), lessThan(order('comment')));
    });
  });

  group('Partially-accept popup', () {
    test('shows the typed quantity in bales, after the quantity', () {
      final field = SecondaryAlertBodyField.fromJson(
          popupField('actualBalesReceived'));
      expect(field.computedValue,
          const ComputedValueConfig(
              sourceField: 'actualQuantityReceived', divideBy: 50));
      expect(field.mandatory, isFalse);

      final names = ((page['showSecondaryAlertPopUp'] as Map)['body'] as List)
          .map((f) => (f as Map)['fieldName'])
          .toList();
      expect(names.indexOf('actualBalesReceived'),
          names.indexOf('actualQuantityReceived') + 1);
    });
  });

  test('every "pieces per bale" on this screen is the same number', () {
    final perBale = {
      (property('bales')['computedValue'] as Map)['divideBy'],
      (popupField('actualBalesReceived')['computedValue'] as Map)['divideBy'],
    };
    expect(perBale, {50});
  });
}
