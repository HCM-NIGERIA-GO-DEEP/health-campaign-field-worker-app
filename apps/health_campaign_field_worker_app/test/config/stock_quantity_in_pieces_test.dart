// ignore_for_file: depend_on_referenced_packages, implementation_imports
import 'dart:convert';
import 'dart:io';

import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_forms_engine/helper/form_builder_helper.dart'
    show buildFormControl;
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/utils/utils.dart'
    show evaluateVisibilityExpression, resolveEntityIndex;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart'
    show
        countsStockInPieces,
        itnPiecesPerBale,
        stockEntryUnit,
        stockReceiptUnit;

/// ITN stock is stored in pieces. A warehouse manager types quantities in
/// bales, and the product details page shows each one in pieces (bales x 50)
/// in a read-only row that is what gets saved. Stock to or from a delivery
/// team moves as loose nets, so there the bales field turns into an editable
/// pieces field and the pieces row goes away. A return instead lets the user
/// pick Bales or Pieces. The stock records how the quantity was typed in
/// additionalFields "stockUnit".
void main() {
  const entryTypes = {
    // stockEntryType: (quantity field, label key part)
    'ISSUED': ('quantitySent', 'SENT'),
    'LOSS': ('quantityLost', 'LOST'),
    'DAMAGED': ('quantityDamaged', 'DAMAGED'),
    'RETURNED': ('quantityReturned', 'RETURNED'),
    'RECEIPT': ('quantityReceived', 'RECEIVED'),
  };
  // A return's unit is picked on the page instead (see 'stock return unit').
  final roleUnitTypes = Map.of(entryTypes)..remove('RETURNED');
  const facilities = ['', 'DELIVERY_TEAM', 'F-2026-10-07-024420'];
  const roleUnits = ['BALES', 'PIECES', ''];

  Map<String, dynamic> recordStock(Map flows) => (flows['flows'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((f) => f['name'] == 'RECORDSTOCK');
  Map<String, dynamic> productDetails(Map flows) =>
      (recordStock(flows)['pages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['page'] == 'stockProductDetails');
  Map<String, dynamic> transformerAction(Map flows) =>
      (recordStock(flows)['onAction'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((a) => a['actionType'] == 'FETCH_TRANSFORMER_CONFIG');
  final dartFlows = sampleInventoryFlows as Map;

  PropertySchema field(String name) => PropertySchema.fromJson(
      (productDetails(dartFlows)['properties'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['fieldName'] == name,
              orElse: () => fail('stockProductDetails has no "$name"')));

  Map<String, dynamic> values(
          String entryType, String unit, String to, String from) =>
      {
        'navigation.stockEntryType': entryType,
        'navigation.stockUnit': unit,
        'warehouseDetails.facilityToWhich': to,
        'stockDetails.facilityFromWhich': from,
      };

  bool holds(String condition, Map<String, dynamic> values) =>
      evaluateVisibilityExpression(
          [VisibilityExpression(condition: condition)], values);

  group('stockEntryUnit', () {
    test('bales only for a bales role with no delivery team on either side',
        () {
      expect(stockEntryUnit('BALES', 'F-1', 'F-2'), 'BALES');
      expect(stockEntryUnit('BALES', null, null), 'BALES');
      expect(stockEntryUnit('BALES', 'DELIVERY_TEAM', 'F-2'), 'PIECES');
      expect(stockEntryUnit('BALES', 'F-1', 'DELIVERY_TEAM'), 'PIECES');
      expect(stockEntryUnit('PIECES', 'F-1', 'F-2'), 'PIECES');
      expect(stockEntryUnit('', 'F-1', 'F-2'), 'PIECES',
          reason: 'a role with no unit is saved as typed');
      expect(stockEntryUnit(null, null, null), 'PIECES');
    });
  });

  group('home stock balance card', () {
    test('counts in pieces for a registrar or distributor, bales otherwise',
        () {
      expect(countsStockInPieces(['REGISTRAR']), isTrue);
      expect(countsStockInPieces(['DISTRIBUTOR']), isTrue);
      expect(countsStockInPieces(['distributor']), isTrue);
      expect(countsStockInPieces(['WAREHOUSE_MANAGER', 'DISTRIBUTOR']), isTrue);
      expect(countsStockInPieces(['WAREHOUSE_MANAGER']), isFalse);
      expect(countsStockInPieces(['DISTRICT_SUPERVISOR']), isFalse);
      expect(countsStockInPieces(['COMMUNITY_DISTRIBUTOR']), isFalse);
      expect(countsStockInPieces(<String>[]), isFalse);
    });

    test('a bale is the 50 pieces the stock forms use', () {
      expect(itnPiecesPerBale, 50);
      expect(field('quantityReceivedPieces').computedValue?.multiplyBy,
          itnPiecesPerBale);
    });
  });

  group('product details page', () {
    for (final MapEntry(key: entryType, value: (quantity, kind))
        in roleUnitTypes.entries) {
      test('$quantity is labelled bales only while typed in bales', () {
        for (final unit in roleUnits) {
          for (final to in facilities) {
            for (final from in facilities) {
              final v = values(entryType, unit, to, from);
              final label = field(quantity)
                      .labelConditions
                      ?.firstWhere((c) => holds(c.condition, v),
                          orElse: () => const LabelCondition(
                              condition: '', label: 'DEFAULT'))
                      .label;
              final expected = switch (unit) {
                '' => 'DEFAULT',
                _ when stockEntryUnit(unit, to, from) == 'BALES' =>
                  'APPONE_INVENTORY_QUANTITY_${kind}_LABEL_BALES',
                _ => 'APPONE_INVENTORY_QUANTITY_${kind}_LABEL_PIECES',
              };
              expect(label, expected, reason: 'unit=$unit to=$to from=$from');
            }
          }
        }
      });

      test('${quantity}Pieces shows bales x 50 exactly when typed in bales',
          () {
        final pieces = field('${quantity}Pieces');
        expect(pieces.computedValue,
            ComputedValueConfig(sourceField: quantity, multiplyBy: 50, decimals: 0));
        expect(pieces.label, 'APPONE_INVENTORY_QUANTITY_${kind}_LABEL_PIECES');
        expect(pieces.readOnly, isFalse,
            reason: 'true would make every product tab share one value');
        expect(pieces.order, greaterThan(field(quantity).order!));

        for (final type in entryTypes.keys) {
          for (final unit in roleUnits) {
            for (final to in facilities) {
              for (final from in facilities) {
                expect(
                  evaluateVisibilityExpression(
                      pieces.visibilityCondition!.expression,
                      values(type, unit, to, from)),
                  type == entryType && stockEntryUnit(unit, to, from) == 'BALES',
                  reason: 'type=$type unit=$unit to=$to from=$from',
                );
              }
            }
          }
        }
      });
    }

    test('the transformer is told the unit, by the same function', () {
      final data = (transformerAction(dartFlows)['properties']['data'] as List)
          .cast<Map<String, dynamic>>();
      expect(
          data.where((d) => d['key'] == 'stockUnit').single['value'],
          '{{fn:stockEntryUnit(navigation.stockUnit, '
          'formData.warehouseDetails.facilityToWhich, '
          'formData.stockDetails.facilityFromWhich)}}');
    });

    test('the bundled INVENTORY.json matches the Dart sample', () {
      // Inventory loads MDMS, then the Dart sample, then the bundled JSON, so
      // a device can run either copy.
      final bundled = jsonDecode(
          File('assets/configs/json/INVENTORY.json').readAsStringSync()) as Map;
      expect(jsonEncode(productDetails(bundled)),
          jsonEncode(productDetails(dartFlows)));
      expect(jsonEncode(transformerAction(bundled)),
          jsonEncode(transformerAction(dartFlows)));
    });
  });

  /// On a return the user picks the unit for each product, whatever their
  /// role: Pieces (the default) shows one quantity field in pieces; Bales
  /// shows it in bales plus a read-only Pieces row (bales x 50).
  group('stock return unit', () {
    // Each product tab has its own copy of the dropdown (returnUnit_item_N),
    // which the page names in conditions as returnUnit_$tabIndex.
    bool holdsOnTab(String condition, int tab, Map<String, dynamic> values) =>
        holds(resolveEntityIndex(condition, tab), values);

    Map<String, dynamic> tabs(String? first, String? second) => {
          'navigation.stockEntryType': 'RETURNED',
          'stockProductDetails.returnUnit_item_0': first,
          'stockProductDetails.returnUnit_item_1': second,
        };

    test('a Bales/Pieces dropdown, Pieces by default, on returns only', () {
      final unit = field('returnUnit');
      expect(unit.format, PropertySchemaFormat.dropdown);
      expect(unit.enums?.map((e) => e.code), ['BALES', 'PIECES']);
      expect(unit.value, 'PIECES');
      expect(unit.readOnly, isFalse,
          reason: 'each product needs its own unit');
      expect(unit.order, lessThan(field('quantityReturned').order!));
      expect(unit.validations?.map((v) => v.type), contains('required'));
      expect(
          buildFormControl('returnUnit_item_0', unit, unit, defaultValues: {})
              .value,
          'PIECES');

      for (final type in entryTypes.keys) {
        expect(
            evaluateVisibilityExpression(unit.visibilityCondition!.expression,
                {'navigation.stockEntryType': type}),
            type == 'RETURNED',
            reason: type);
      }
    });

    test('quantityReturned is labelled with each product\'s own unit', () {
      String? label(int tab, Map<String, dynamic> values) =>
          field('quantityReturned')
              .labelConditions
              ?.firstWhere((c) => holdsOnTab(c.condition, tab, values),
                  orElse: () =>
                      const LabelCondition(condition: '', label: 'DEFAULT'))
              .label;

      final values = tabs('BALES', 'PIECES');
      expect(label(0, values), 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_BALES');
      expect(
          label(1, values), 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_PIECES');
    });

    test('the Pieces row shows only when Bales is picked, whatever the role',
        () {
      final pieces = field('quantityReturnedPieces');
      expect(pieces.computedValue,
          const ComputedValueConfig(
              sourceField: 'quantityReturned', multiplyBy: 50, decimals: 0));

      bool shows(int tab, Map<String, dynamic> values) =>
          evaluateVisibilityExpression([
            for (final e in pieces.visibilityCondition!.expression)
              e.copyWith(condition: resolveEntityIndex(e.condition, tab)),
          ], values);

      for (final unit in roleUnits) {
        for (final to in facilities) {
          final values = {
            ...tabs('BALES', 'PIECES'),
            'navigation.stockUnit': unit,
            'warehouseDetails.facilityToWhich': to,
            'stockDetails.facilityFromWhich': to,
          };
          expect(shows(0, values), isTrue, reason: 'unit=$unit to=$to');
          expect(shows(1, values), isFalse, reason: 'unit=$unit to=$to');
        }
      }
      expect(shows(0, {...tabs('BALES', null), 'navigation.stockEntryType': 'ISSUED'}),
          isFalse);
    });
  });

  /// A registrar or distributor always receives stock in pieces: on the stock
  /// receipt (Accept) screen they type the pieces that arrived, starting from
  /// the pieces sent, and there is no bales row. Everyone else sees the
  /// quantity sent, read-only, with its bales.
  group('stock receipt (Accept) screen', () {
    Map<String, dynamic> receiptFlow(Map flows) => (flows['flows'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['name'] == 'stockReceiptDetails');
    Map<String, dynamic> receiptPage(Map flows) =>
        (receiptFlow(flows)['pages'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['page'] == 'stockReceiptDetails');
    Map<String, dynamic> selectNavigation(Map flows) {
      final incoming = (flows['flows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => f['name'] == 'incomingTransactions');
      final card = (incoming['body'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['fieldName'] == 'incomingList')['child'] as Map;
      final button = (card['children'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['fieldName'] == 'incomingTransactionsSelectButton');
      return ((button['onAction'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((a) => a['actionType'] == 'NAVIGATION')['properties']
          as Map<String, dynamic>);
    }

    List<Map<String, dynamic>> acceptTransformerData(Map flows) =>
        (((receiptFlow(flows)['onAction'] as List)
                    .cast<Map<String, dynamic>>()
                    .firstWhere((a) =>
                        a['actionType'] == 'FETCH_TRANSFORMER_CONFIG')['properties']
                as Map)['data'] as List)
            .cast<Map<String, dynamic>>();

    PropertySchema receiptField(String name) => PropertySchema.fromJson(
        (receiptPage(dartFlows)['properties'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['fieldName'] == name,
                orElse: () => fail('stockReceiptDetails has no "$name"')));

    // The incoming stock list always passes receiptUnit (see below), so the
    // screen never sees it missing; an empty one reads as "".
    bool visible(String name, String? receiptUnit) =>
        evaluateVisibilityExpression(
            receiptField(name).visibilityCondition!.expression,
            {'navigation.receiptUnit': receiptUnit});

    test('pieces for a registrar or distributor, bales otherwise', () {
      expect(stockReceiptUnit(['REGISTRAR']), 'PIECES');
      expect(stockReceiptUnit(['DISTRIBUTOR']), 'PIECES');
      expect(stockReceiptUnit(['WAREHOUSE_MANAGER', 'DISTRIBUTOR']), 'PIECES');
      expect(stockReceiptUnit(['WAREHOUSE_MANAGER']), 'BALES');
      expect(stockReceiptUnit(['COMMUNITY_DISTRIBUTOR']), 'BALES');
      expect(stockReceiptUnit(<String>[]), 'BALES');
    });

    test('in pieces, an editable pieces field replaces quantity and bales',
        () {
      expect(visible('quantityReceived', 'PIECES'), isTrue);
      expect(visible('quantity', 'PIECES'), isFalse);
      expect(visible('bales', 'PIECES'), isFalse);
    });

    test('in bales, or with an empty unit, the screen is as before', () {
      for (final unit in ['BALES', '', null]) {
        expect(visible('quantityReceived', unit), isFalse, reason: 'unit=$unit');
        expect(visible('quantity', unit), isTrue, reason: 'unit=$unit');
        expect(visible('bales', unit), isTrue, reason: 'unit=$unit');
      }
    });

    test('the pieces field starts at the pieces sent and must be filled', () {
      final received = receiptField('quantityReceived');
      expect(received.type, PropertySchemaType.integer);
      expect(received.label, 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_PIECES');
      expect(received.readOnly, isFalse);
      expect(received.computedValue, isNull);
      expect(received.order, greaterThan(receiptField('quantity').order!));
      expect(received.order, lessThan(receiptField('bales').order!));
      expect(received.validations?.map((v) => v.type),
          containsAll(['required', 'min']));

      final control = buildFormControl('quantityReceived', received, received,
          navigationParams: {'quantity': '120'}, defaultValues: {});
      expect(control.value, 120);
    });

    test('the role decides the unit, and the transformer is told it', () {
      expect(
          (selectNavigation(dartFlows)['data'] as List)
              .cast<Map<String, dynamic>>()
              .where((d) => d['key'] == 'receiptUnit')
              .single['value'],
          '{{fn:stockReceiptUnit()}}');
      expect(
          acceptTransformerData(dartFlows)
              .where((d) => d['key'] == 'receiptUnit')
              .single['value'],
          '{{navigation.receiptUnit}}');
    });

    test('the bundled INVENTORY.json matches the Dart sample', () {
      final bundled = jsonDecode(
          File('assets/configs/json/INVENTORY.json').readAsStringSync()) as Map;
      expect(jsonEncode(receiptFlow(bundled)), jsonEncode(receiptFlow(dartFlows)));
      expect(jsonEncode(selectNavigation(bundled)),
          jsonEncode(selectNavigation(dartFlows)));
    });
  });

  group('what the stock record gets', () {
    setUpAll(() {
      StockModelMapper.ensureInitialized();
      StockAdditionalFieldsMapper.ensureInitialized();
      AdditionalFieldMapper.ensureInitialized();
      AuditDetailsMapper.ensureInitialized();
      ClientAuditDetailsMapper.ensureInitialized();
      DataConverterSingleton()
          .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    });

    final stockConfig = jsonConfig['stock'] as Map<String, dynamic>;

    /// One product's values, as TransformerExecutor hands them over after
    /// mapping quantityReceived_item_0 back to quantityReceived. A hidden
    /// field reaches it empty.
    Map<String, dynamic> run(String entryType,
        {required Map<String, dynamic> productValues, String? stockUnit}) {
      final (quantity, _) = entryTypes[entryType]!;
      final page = <String, dynamic>{
        for (final (field, _) in entryTypes.values) ...{
          field: null,
          '${field}Pieces': null,
        },
        'returnUnit': null,
        ...productValues,
      };
      expect(page.keys, contains(quantity));
      final entities = FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: {
          'warehouseDetails': {'facilityToWhich': 'F-2'},
          'stockDetails': {
            'productdetail': {'id': 'pv-001', 'sku': 'ITN'},
            'facilityFromWhich': 'F-1',
          },
          'stockProductDetails': page,
        },
        modelsConfig: stockConfig['models'] as Map<String, dynamic>,
        context: {
          'stockEntryType': entryType,
          'transactionType': 'RECEIVED',
          'projectId': 'proj-1',
          'tenantId': 'lr',
          'mrnNumber': 'MRN-1',
          'senderPartyType': 'WAREHOUSE',
          'receiverPartyType': 'WAREHOUSE',
          'userUUID': 'user-1',
          if (stockUnit != null) 'stockUnit': stockUnit,
        },
        fallbackFormDataString: stockConfig['fallbackModel'] as String?,
      );
      return entities.whereType<StockModel>().single.toMap();
    }

    Map<String, dynamic> additionalFieldsOf(Map<String, dynamic> stock) => {
          for (final f in (stock['additionalFields']?['fields'] as List?) ?? [])
            (f as Map)['key'] as String: f['value'],
        };

    for (final MapEntry(key: entryType, value: (quantity, _))
        in entryTypes.entries) {
      test('$entryType typed in bales is saved in pieces', () {
        final stock = run(entryType,
            stockUnit: 'BALES',
            productValues: {quantity: 3, '${quantity}Pieces': '150'});

        expect(stock['quantity'], '150');
        expect(additionalFieldsOf(stock)['stockUnit'], 'BALES');
      });

      test('$entryType typed in pieces is saved as typed', () {
        final stock = run(entryType,
            stockUnit: 'PIECES', productValues: {quantity: 40});

        expect(stock['quantity'], '40');
        expect(additionalFieldsOf(stock)['stockUnit'], 'PIECES');
      });

      test('$entryType from a config without stockUnit is saved as typed',
          () {
        // The app can update before a remote config does; a missing unit
        // must not drop the stock record.
        final stock =
            run(entryType, productValues: {quantity: 3, '${quantity}Pieces': null});

        expect(stock['quantity'], '3');
        expect(additionalFieldsOf(stock).containsKey('stockUnit'), isFalse);
      });
    }

    // The loop above also covers a config without the return unit dropdown:
    // a return then follows stockUnit, as before.
    for (final stockUnit in ['BALES', 'PIECES', null]) {
      test('a return picked in Bales is saved in pieces (stockUnit=$stockUnit)',
          () {
        final stock = run('RETURNED', stockUnit: stockUnit, productValues: {
          'returnUnit': 'BALES',
          'quantityReturned': 3,
          'quantityReturnedPieces': '150',
        });

        expect(stock['quantity'], '150');
        expect(additionalFieldsOf(stock)['stockUnit'], 'BALES');
        expect(additionalFieldsOf(stock)['quantityReturned'], '3');
      });

      test('a return picked in Pieces is saved as typed (stockUnit=$stockUnit)',
          () {
        final stock = run('RETURNED',
            stockUnit: stockUnit,
            productValues: {'returnUnit': 'PIECES', 'quantityReturned': 125});

        expect(stock['quantity'], '125');
        expect(additionalFieldsOf(stock)['stockUnit'], 'PIECES');
        expect(additionalFieldsOf(stock)['quantityReturned'], '125');
      });
    }

    test('the typed bales stay on the record next to the unit', () {
      final stock = run('RECEIPT',
          stockUnit: 'BALES',
          productValues: {'quantityReceived': 3, 'quantityReceivedPieces': '150'});

      expect(additionalFieldsOf(stock)['quantityReceived'], '3');
      expect(additionalFieldsOf(stock), isNot(contains('quantityReturned')));
      expect(additionalFieldsOf(stock).containsKey('quantityReceivedPieces'),
          isFalse,
          reason: 'saved as quantity, not repeated');
    });

    /// What Accept on the stock receipt screen saves, for 100 pieces
    /// dispatched (the transformer's context quantity). A hidden field
    /// reaches it empty.
    Map<String, dynamic> accept({String? receiptUnit, int? typed}) {
      final receiptConfig = jsonConfig['stockReceipt'] as Map<String, dynamic>;
      final inPieces = receiptUnit == 'PIECES';
      final entities = FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: {
          'stockReceiptDetails': {
            'wayBillNumber': 'WB-1',
            'quantity': inPieces ? null : 100,
            'bales': inPieces ? null : '2.00',
            'quantityReceived': inPieces ? typed : null,
          },
        },
        modelsConfig: receiptConfig['models'] as Map<String, dynamic>,
        context: {
          'stockEntryType': 'RECEIPT',
          'transactionType': 'RECEIVED',
          'primaryRole': 'RECEIVER',
          'secondaryRole': 'SENDER',
          'mrnNumber': 'MRN-1',
          'senderFacilityId': 'F-1',
          'userFacilityId': 'F-2',
          'productVariantId': 'pv-001',
          'sku': 'ITN',
          'quantity': 100,
          'projectId': 'proj-1',
          'tenantId': 'lr',
          'userUUID': 'user-1',
          if (receiptUnit != null) 'receiptUnit': receiptUnit,
        },
        fallbackFormDataString: receiptConfig['fallbackModel'] as String?,
      );
      return entities.whereType<StockModel>().single.toMap();
    }

    test('a registrar or distributor saves the pieces they typed on Accept',
        () {
      final stock = accept(receiptUnit: 'PIECES', typed: 96);

      expect(stock['quantity'], '96');
      expect(additionalFieldsOf(stock).containsKey('quantityReceived'), isFalse,
          reason: 'saved as quantity, not repeated');
    });

    test('anyone else saves the quantity dispatched on Accept', () {
      expect(accept(receiptUnit: 'BALES')['quantity'], '100');
    });

    test('Accept from a config without receiptUnit saves the quantity '
        'dispatched', () {
      expect(accept()['quantity'], '100');
    });
  });
}
