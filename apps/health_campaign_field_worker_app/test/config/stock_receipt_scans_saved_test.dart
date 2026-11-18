// ignore_for_file: depend_on_referenced_packages
import 'package:digit_crud_bloc/service/crud_service.dart';
import 'package:digit_crud_bloc/utils/utils.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/crud_executor.dart';
import 'package:digit_flow_builder/data/digit_crud_service.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_forms_engine/helper/secondary_popup_values.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_scanner/utils/scanned_stock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// Sierra Leone ITN: bales and nets scanned on the stock Accept screen must
/// be saved on the record that is actually stored. Accepting stock UPDATES
/// the sender's dispatch record (status → ACCEPTED); the receipt model built
/// by FETCH_TRANSFORMER_CONFIG "stockReceipt" is never stored. So every
/// UPDATE_EVENT on the dispatch must write the scans as numbered keys.
class _CapturingCrudService extends CrudService {
  final updated = <EntityModel>[];

  @override
  Future<void> updateEntities(List<EntityModel> entities) async =>
      updated.addAll(entities);
}

void main() {
  const scansKey = 'StockModel.additionalFields.numberedScans';
  const scansValue = '{{formData.stockReceiptDetails.scannedStock}}';
  const gs = '\x1d';

  late Map<String, dynamic> flow;
  setUpAll(() {
    flow = ((sampleInventoryFlows as Map)['flows'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['name'] == 'stockReceiptDetails');
    StockModelMapper.ensureInitialized();
    StockAdditionalFieldsMapper.ensureInitialized();
    AdditionalFieldMapper.ensureInitialized();
    AuditDetailsMapper.ensureInitialized();
    ClientAuditDetailsMapper.ensureInitialized();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  /// Every UPDATE_EVENT on the dispatch record, with where it sits.
  List<MapEntry<String, Map<String, dynamic>>> dispatchUpdates() {
    final found = <MapEntry<String, Map<String, dynamic>>>[];
    void walk(String where, List<dynamic> actions) {
      for (final action in actions.cast<Map<String, dynamic>>()) {
        final props = action['properties'] as Map<String, dynamic>?;
        if (action['actionType'] == 'UPDATE_EVENT' &&
            props?['source'] == 'existingModels') {
          found.add(MapEntry(where, action));
        }
        final nested = action['actions'] as List<dynamic>?;
        if (nested != null) {
          final condition =
              (action['condition'] as Map?)?['expression'] ?? 'nested';
          walk('$where > $condition', nested);
        }
      }
    }

    walk('Accept', flow['onAction'] as List<dynamic>);
    walk('Partially accept', flow['onSecondaryAction'] as List<dynamic>);
    return found;
  }

  test('every update of the dispatch record writes the scans', () {
    final updates = dispatchUpdates();
    expect(updates, isNotEmpty);
    for (final update in updates) {
      final modify = ((update.value['properties'] as Map)['modify'] as List)
          .cast<Map<String, dynamic>>();
      expect(
          modify.where((m) => m['key'] == scansKey && m['value'] == scansValue),
          hasLength(1),
          reason: update.key);
    }
  });

  group('what the dispatch record gets', () {
    final parser = GS1BarcodeParser.defaultParser();
    final rules = scanTypeRulesFrom([
      {'type': 'bale', 'ai': '00', 'saveKey': 'baleScannedStock'},
      {'type': 'piece', 'ai': '21', 'saveKey': 'piecesScannedStock'},
    ]);
    final scanned = encodeScannedStock([
      for (final code in [
        '010764021781161211250400' '10104925${gs}2132ABD3F11',
        '00176402178112799276',
        '010764021781161211250600' '10600725${gs}215EF6E92D5',
      ])
        scannedStockEntryFor(parser.parse(code), rules)!,
    ]);

    final dispatch = StockModel(
      clientReferenceId: 'dispatch-1',
      productVariantId: 'bednet',
      senderId: 'district',
      receiverId: 'phu',
      quantity: '60',
      tenantId: 'si',
      additionalFields: StockAdditionalFields(version: 1, fields: [
        AdditionalField('stockEntryType', 'ISSUED'),
        AdditionalField('status', 'IN_TRANSIT'),
      ]),
    );

    Future<StockModel> run(WidgetTester tester, Map<String, dynamic> action,
        Map<String, dynamic> formData) async {
      final crud = _CapturingCrudService();
      CrudBlocSingleton().setData(
          crudService: crud, dynamicEntityModelListener: EntityModelMapMapper());
      late BuildContext context;
      await tester.pumpWidget(Builder(builder: (c) {
        context = c;
        return const SizedBox();
      }));
      await UpdateExecutor().execute(ActionConfig.fromJson(action), context, {
        'formData': formData,
        'navigation': {'quantity': '60', 'clientReferenceId': 'dispatch-1'},
        'existingModels': [dispatch],
      });
      return crud.updated.whereType<StockModel>().single;
    }

    Map<String, dynamic> fieldsOf(StockModel row) => {
          for (final f in row.additionalFields?.fields ?? <AdditionalField>[])
            f.key: f.value,
        };

    Map<String, dynamic> acceptUpdate() =>
        dispatchUpdates().firstWhere((u) => u.key == 'Accept').value;

    testWidgets('Accept saves each scanned code under its own key',
        (tester) async {
      final row = await run(tester, acceptUpdate(), {
        'stockReceiptDetails': {'scannedStock': scanned, 'bales': '1.20'},
      });
      final fields = fieldsOf(row);

      expect(fields['baleScannedStock1'], '(00)176402178112799276');
      expect(fields['piecesScannedStock1'],
          '(01)07640217811612(11)250400(10)104925(21)32ABD3F11');
      expect(fields['piecesScannedStock2'],
          '(01)07640217811612(11)250600(10)600725(21)5EF6E92D5');
      expect(fields['status'], 'ACCEPTED');
      expect(fields['stockEntryType'], 'ISSUED', reason: 'existing keys kept');
      expect(fields.keys, isNot(contains('numberedScans')));
      expect(fields.keys, isNot(contains('scannedStock')));
      expect(fields.keys, isNot(contains('bales')));
      expect(row.quantity, '60');
    });

    testWidgets('codes typed on manual entry go under <saveKey>Manual keys',
        (tester) async {
      // QA 2026-11-18: a typed bale and a typed net were saved as
      // baleScannedStock2 / piecesScannedStock2, like camera scans.
      final typedBale =
          typedManualCode('123456789987654321', rules.first, rules)!;
      final typedNet = typedManualCode('manualpieces9700', rules.last, rules)!;
      // What the scanner page does on manual entry.
      markManualCode(typedBale);
      markManualCode(typedNet);
      final mixed = encodeScannedStock([
        scannedStockEntryFor(parser.parse('00176402178112799276'), rules)!,
        scannedStockEntryFor(typedBale, rules)!,
        scannedStockEntryFor(typedNet, rules)!,
      ]);

      final fields = fieldsOf(await run(tester, acceptUpdate(), {
        'stockReceiptDetails': {'scannedStock': mixed},
      }));
      expect(fields['baleScannedStock1'], '(00)176402178112799276');
      expect(fields['baleScannedStockManual1'], '(00)123456789987654321');
      expect(fields['piecesScannedStockManual1'], '(21)manualpieces9700');
      expect(fields.keys, isNot(contains('baleScannedStock2')));
      expect(fields.keys, isNot(contains('piecesScannedStock1')));
    });

    testWidgets('Accept with nothing scanned adds no scan keys',
        (tester) async {
      final row = await run(tester, acceptUpdate(), {
        'stockReceiptDetails': {'bales': '1.20'},
      });
      expect(fieldsOf(row).keys.where((k) => k.contains('ScannedStock')),
          isEmpty);
      expect(fieldsOf(row)['status'], 'ACCEPTED');
    });

    testWidgets('Partially accept saves them too, from the popup data',
        (tester) async {
      final partial = dispatchUpdates().firstWhere((u) =>
          u.key.startsWith('Partially accept') &&
          !u.key.contains('RETURNED'));
      // What the popup hands the action: its typed values plus the page's.
      const body = [
        SecondaryAlertBodyField(
            type: 'integer',
            label: 'QTY',
            fieldName: 'actualQuantityReceived',
            mandatory: true),
      ];
      final formData = secondaryPopupData(
        body,
        {'actualQuantityReceived': '40'},
        pageName: 'stockReceiptDetails',
        pageValues: {'scannedStock': scanned, 'bales': '1.20'},
      );

      final fields = fieldsOf(await run(tester, partial.value, formData));
      expect(fields['baleScannedStock1'], '(00)176402178112799276');
      expect(fields['piecesScannedStock2'],
          '(01)07640217811612(11)250600(10)600725(21)5EF6E92D5');
      // The branch's own plain values are still applied alongside.
      expect(fields['status'], 'ACCEPTED');
      expect(fields.keys, isNot(contains('bales')));
      expect(fields.keys, isNot(contains('scannedStock')));
    });

    testWidgets('Partially accept saves the received bales next to the pieces',
        (tester) async {
      await tester.pumpWidget(Builder(builder: (context) {
        FunctionRegistries(context).registerAll();
        return const SizedBox();
      }));
      final partial = dispatchUpdates().firstWhere((u) =>
          u.key.startsWith('Partially accept') &&
          !u.key.contains('RETURNED'));
      final formData = secondaryPopupData(
        const [
          SecondaryAlertBodyField(
              type: 'integer',
              label: 'QTY',
              fieldName: 'actualQuantityReceived',
              mandatory: true),
        ],
        {'actualQuantityReceived': '40'},
        pageName: 'stockReceiptDetails',
        pageValues: const {},
      );

      final row = await run(tester, partial.value, formData);
      final fields = fieldsOf(row);
      expect(fields['actualQuantityReceived'], '40');
      expect(fields['actualBalesReceived'], '0.80');
      expect(row.quantity, '60', reason: 'quantity stays as dispatched');
    });
  });
}
