// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// Sierra Leone ITN, QA 2026-11-16: the records the partial-accept flow
/// creates (shortfall return, and the re-issues of an in-transit shortfall)
/// carried no balesQuantity. Each shortfallTransaction call now passes
/// `fn:toBales(<its own quantity>, <pieces per bale>)`; pieces per bale sits in
/// config so it can change (50 today).
void main() {
  // QA's case: 297 dispatched, 100 accepted, 197 short.
  final contextData = {
    'navigation': {'quantity': '297'},
    'formData': {'actualQuantityReceived': '100'},
  };

  // {{fn:toBales(<pieces>, <per bale>[, <minus>])}}
  final shortfallCall =
      RegExp(r'^\{\{fn:toBales\(([\w.]+), (\d+)(?:, ([\w.]+))?\)\}\}$');

  /// Every shortfallTransaction FETCH data list in a flow config.
  List<List<Map<String, dynamic>>> shortfallCalls(Object? node) {
    final found = <List<Map<String, dynamic>>>[];
    void walk(Object? n) {
      if (n is Map) {
        final props = n['properties'];
        if (n['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
            props is Map &&
            props['configName'] == 'shortfallTransaction') {
          found.add((props['data'] as List).cast<Map<String, dynamic>>());
        }
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(node);
    return found;
  }

  final configs = {
    'manage_stock.dart': sampleInventoryFlows,
    'INVENTORY.json': jsonDecode(
        File('assets/configs/json/INVENTORY.json').readAsStringSync()),
  };

  /// Distinct `computedValue.divideBy` values (pieces per bale on screen).
  Set<num> divideByValues(Object? node) {
    final found = <num>{};
    void walk(Object? n) {
      if (n is Map) {
        final computed = n['computedValue'];
        if (computed is Map && computed['divideBy'] is num) {
          found.add(computed['divideBy'] as num);
        }
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(node);
    return found;
  }

  String valueOf(List<Map<String, dynamic>> data, String key) =>
      data.singleWhere((e) => e['key'] == key)['value'] as String;

  testWidgets('every shortfall record gets bales from its own quantity',
      (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox();
    }));

    for (final entry in configs.entries) {
      // Pieces per bale is repeated in config: the screen's bales rows
      // (computedValue.divideBy) and every toBales call must use one value,
      // or the saved bales differ from the bales shown.
      final perBale = divideByValues(entry.value);
      expect(perBale, hasLength(1), reason: '${entry.key}: $perBale');

      final calls = shortfallCalls(entry.value);
      expect(calls, hasLength(4), reason: entry.key);

      for (final data in calls) {
        final expression = valueOf(data, 'balesQuantity');
        expect(shortfallCall.firstMatch(expression)?.group(2),
            '${perBale.single}',
            reason: '${entry.key}: $expression');
        // Bales describe the record's own quantity.
        final bales = '${resolveValue(expression, contextData)}';
        final quantity =
            num.parse('${resolveValue(valueOf(data, 'quantity'), contextData)}');
        expect(bales, (quantity / perBale.single).toStringAsFixed(2),
            reason: entry.key);
      }
    }
  });

  testWidgets("QA's case: 197 short of 297 at 50 per bale is 3.94 bales",
      (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox();
    }));
    expect(
        resolveValue(
            '{{fn:toBales(navigation.quantity, 50, '
            'formData.actualQuantityReceived)}}',
            contextData),
        '3.94');
  });

  testWidgets('pieces per bale comes from config, not code', (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox();
    }));
    expect(
        resolveValue(
            '{{fn:toBales(navigation.quantity, 60, '
            'formData.actualQuantityReceived)}}',
            contextData),
        '3.28');
  });

  testWidgets('toBales gives nothing, never throws, on unusable input',
      (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox();
    }));
    for (final bad in [
      '{{fn:toBales(navigation.missing, 50)}}',
      '{{fn:toBales(navigation.quantity, 0)}}',
      '{{fn:toBales(navigation.quantity, abc)}}',
      '{{fn:toBales(navigation.quantity)}}',
      '{{fn:toBales(navigation.quantity, 50, navigation.missing)}}',
      // More accepted than sent: no negative bales.
      '{{fn:toBales(formData.actualQuantityReceived, 50, navigation.quantity)}}',
    ]) {
      expect('${resolveValue(bad, contextData) ?? ''}', '', reason: bad);
    }
  });

  group('the shortfall record', () {
    setUpAll(() {
      StockModelMapper.ensureInitialized();
      StockAdditionalFieldsMapper.ensureInitialized();
      AdditionalFieldMapper.ensureInitialized();
      AuditDetailsMapper.ensureInitialized();
      ClientAuditDetailsMapper.ensureInitialized();
      DataConverterSingleton()
          .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    });

    StockModel build({String? bales}) {
      final config = jsonConfig['shortfallTransaction']!;
      return FormEntityMapper(config: jsonConfig)
          .mapFormToEntities(
            formValues: const {},
            modelsConfig: config['models'] as Map<String, dynamic>,
            context: {
              'stockEntryType': 'RETURNED',
              'quantity': '197',
              'senderFacilityId': 'district',
              'receiverFacilityId': 'province',
              'productVariantId': 'bednet',
              'projectId': 'campaign',
              'tenantId': 'si',
              'userUUID': 'user',
              'mrnNumber': 'mrn-1',
              'originalIssueClientReferenceId': 'dispatch-1',
              'discrepancyReason': 'IN_TRANSIT',
              if (bales != null) 'balesQuantity': bales,
            },
          )
          .whereType<StockModel>()
          .single;
    }

    Object? field(StockModel row, String key) => row.additionalFields?.fields
        .where((f) => f.key == key)
        .firstOrNull
        ?.value;

    test('carries balesQuantity in additionalFields', () {
      final row = build(bales: '3.94');
      expect(field(row, 'balesQuantity'), '3.94');
      expect(row.quantity, '197');
    });

    test('without a bales value the key is left out, not saved empty', () {
      // No key: config not uploaded, or an older APK (toBales unknown → null,
      // dropped before mapping). '': unusable numbers.
      for (final bales in [null, '']) {
        final row = build(bales: bales);
        expect(row.additionalFields?.fields.map((f) => f.key),
            isNot(contains('balesQuantity')),
            reason: '$bales');
        expect(row.quantity, '197');
      }
    });
  });
}
