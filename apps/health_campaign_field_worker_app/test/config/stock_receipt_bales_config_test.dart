import 'dart:convert';
import 'dart:io';

import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_scanner/utils/scanned_stock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';

/// ITN (ported from Sierra Leone): on the stock Accept screen every receiver
/// may scan the bales and nets that arrived (a record only - nothing is
/// checked), and the screen shows the quantity in bales (50 pieces = 1 bale),
/// worked out automatically and greyed out. Quantities stay in pieces.
/// Liberia's receipt screen has Accept + Decline only (no Partially-accept
/// popup), so there is no popup bales row here.
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

  test('the bundled INVENTORY.json Accept screen matches the Dart sample', () {
    // Inventory loads MDMS, then the Dart sample, then the bundled JSON, so a
    // device runs either copy; both must carry the same bales/scan setup.
    final json = jsonDecode(
            File('assets/configs/json/INVENTORY.json').readAsStringSync())
        as Map<String, dynamic>;
    Map<String, dynamic> receiptFlow(Map flows) =>
        (flows['flows'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((f) => f['name'] == 'stockReceiptDetails');
    final dart = receiptFlow(sampleInventoryFlows as Map);
    final bundled = receiptFlow(json);
    expect(jsonEncode(bundled), jsonEncode(dart));
  });
}
