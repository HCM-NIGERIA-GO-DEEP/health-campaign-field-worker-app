import 'package:digit_crud_bloc/models/global_search_params.dart';
import 'package:digit_crud_bloc/repositories/helpers/query_builder.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/screen_builder.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_formula_parser/digit_formula_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// Guards the inventory config against the null-MRN regression.
///
/// Stock created from the web (Commodity Management) carries no mrnNumber.
/// Both transaction lists grouped on `additionalFields.fields.mrnNumber`, so
/// every such row got a synthetic 'null_0', 'null_1', ... group key. That key
/// exists nowhere in the stored data, which broke two things at once:
///   - the card rendered the literal text "MRN null_0";
///   - viewTransactionDetails searched `additionalFields contains <key>`, a
///     substring that never matches, so the screen showed its heading over an
///     empty body.
///
/// Rows without an MRN group by clientReferenceId. The details screen uses
/// exact row IDs from the selected card or acknowledgement.
///
/// These assertions are deliberately whole-config sweeps rather than checks on
/// the two screens that were fixed by hand: the failure mode is an entry point
/// that was *missed*, and only a sweep catches a third one being added later.
void main() {
  late List<Map<String, dynamic>> flows;

  setUpAll(() {
    flows = (sampleInventoryFlows['flows'] as List).cast<Map<String, dynamic>>();
  });

  Map<String, dynamic> flowNamed(String name) =>
      flows.firstWhere((f) => f['name'] == name);

  /// Every wrapperConfig in the inventory flows, with its owning flow name.
  Iterable<MapEntry<String, Map<String, dynamic>>> wrapperConfigs() sync* {
    for (final flow in flows) {
      final wrapper = flow['wrapperConfig'];
      if (wrapper is Map<String, dynamic>) {
        yield MapEntry(flow['name'] as String, wrapper);
      }
    }
  }

  /// Walks the whole config tree collecting maps that satisfy [matches].
  List<Map<String, dynamic>> findMaps(
    dynamic node,
    bool Function(Map<String, dynamic>) matches,
  ) {
    final found = <Map<String, dynamic>>[];
    void walk(dynamic n) {
      if (n is Map) {
        final map = n.cast<String, dynamic>();
        if (matches(map)) found.add(map);
        for (final v in map.values) {
          walk(v);
        }
      } else if (n is List) {
        for (final v in n) {
          walk(v);
        }
      }
    }

    walk(node);
    return found;
  }

  group('grouping', () {
    test('every MRN-grouped list declares the clientReferenceId fallback', () {
      final mrnGrouped = wrapperConfigs()
          .where((e) => e.value['groupBy'] == 'additionalFields.fields.mrnNumber');

      // Both incomingTransactions and viewTransaction group this way; if a
      // third list is added it must opt in too, or it reintroduces 'null_N'.
      expect(mrnGrouped, isNotEmpty,
          reason: 'expected at least one MRN-grouped list');

      for (final entry in mrnGrouped) {
        expect(
          entry.value['groupByFallback'],
          'clientReferenceId',
          reason: '${entry.key} groups by MRN without a fallback - MRN-less '
              'web stock will group under an unsearchable null_N key',
        );
      }
    });

    test('covers both known transaction lists', () {
      for (final name in ['incomingTransactions', 'viewTransaction']) {
        final wrapper = flowNamed(name)['wrapperConfig'] as Map<String, dynamic>;
        expect(wrapper['groupByFallback'], 'clientReferenceId',
            reason: '$name lost its fallback');
      }
    });
  });

  group('card tags', () {
    test('no tag interpolates the raw group key', () {
      // "MRN {{item.groupKey}}" is exactly what rendered as "MRN null_0".
      // The key may now legitimately be a clientReferenceId, which is
      // meaningless to a storekeeper, so no label may show it directly.
      final offenders = findMaps(
        sampleInventoryFlows,
        (m) => m['label'] is String && (m['label'] as String).contains('item.groupKey'),
      );

      expect(offenders, isEmpty,
          reason: 'labels still showing the raw group key: '
              '${offenders.map((m) => m['fieldName']).toList()}');
    });

    test('both transaction lists tag via transactionTag', () {
      for (final name in ['incomingTransactions', 'viewTransaction']) {
        final tags = findMaps(
          flowNamed(name),
          (m) => m['format'] == 'tag' && m['label'] is String,
        );

        expect(tags, isNotEmpty, reason: '$name has no tag widget');
        expect(
          tags.any((m) => (m['label'] as String).contains('fn:transactionTag(')),
          isTrue,
          reason: '$name no longer renders its tag through transactionTag',
        );
      }
    });
  });

  test('transaction cards localize the SKU before appending quantity', () {
    for (final entry in {
      'incomingTransactions': 'incomingTransactionsGroupedItemText',
      'viewTransaction': 'viewTransactionGroupedItemText',
    }.entries) {
      final cardItem = findMaps(
        flowNamed(entry.key),
        (widget) => widget['fieldName'] == entry.value,
      ).single;
      final value = cardItem['value'] ?? cardItem['data'][0]['value'];
      expect(value,
          startsWith('{{fn:localizeStockSku(item.additionalFields.fields.sku)}}: '));
    }
  });

  group('viewTransactionDetails search', () {
    List<Map<String, dynamic>> routesTo(String name) => findMaps(
          sampleInventoryFlows,
          (m) => m['name'] == name && m['data'] is List,
        ).toList();

    String refsTemplate(Map<String, dynamic> route) =>
        (route['data'] as List).singleWhere(
            (entry) => entry['key'] == 'selectedStockRefs')['value'] as String;

    List<SearchFilter> filtersFor(Map<String, dynamic> navigation) {
      final details = flowNamed('viewTransactionDetails');
      final actions = resolveTemplates(details['initActions'], navigation) as List;
      final search = actions.single;
      return (search['properties']['data'] as List).where((filter) {
        final expression = filter['applyIf'] as String;
        final result = FormulaParser(expression, {'_dummy': ''}).parse;
        expect(result['isSuccess'], isTrue, reason: expression);
        return result['value'] == true;
      }).map((filter) {
        return SearchFilter(
          root: 'stock',
          field: filter['key'] as String,
          operator: filter['operation'] as String,
          value: filter['value'],
        );
      }).toList();
    }

    test('requires row IDs and does not seed details from navigation entities', () {
      final details = flowNamed('viewTransactionDetails');
      final search = (details['initActions'] as List).single;
      expect(details['seedFromNavigation'], isFalse);
      expect(search['properties']['skipAccumulatedFilters'], isTrue);
      expect(filtersFor({}), isEmpty);
      expect(filtersFor({'selectedStock': 'MRN-1'}), isEmpty);
      expect(filtersFor({'selectedStockRefs': ''}), isEmpty);
      expect(filtersFor({'selectedStockRefs': 'null'}), isEmpty);
    });

    test('stock creation waits for persistence before acknowledging', () {
      for (final name in ['RECORDSTOCK', 'RECORDLESSEXCESS']) {
        final actions = flowNamed(name)['onAction'] as List;
        final create = actions.singleWhere(
            (action) => action['actionType'] == 'CREATE_EVENT');
        expect(create['properties']['awaitPersistence'], isTrue, reason: name);
      }
    });

    testWidgets('each entry route resolves only its selected stock row IDs',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        FunctionRegistries(context).registerAll();
        return const SizedBox.shrink();
      })));

      final detailRoutes = routesTo('viewTransactionDetails');
      final acknowledgement = detailRoutes.singleWhere(
          (route) => refsTemplate(route).contains('navigation.'));
      final listRoute = detailRoutes.singleWhere(
          (route) => refsTemplate(route).contains('item.items'));

      void expectLookup(Object? refs, List<String> expected) {
        final filters = filtersFor({
          'selectedStockRefs': refs,
          'selectedStock': 'unrelated-MRN',
        });
        expect(filters.single.field, 'clientReferenceId');
        expect(filters.single.operator, 'in');
        final placeholders = List.filled(expected.length, '?').join(', ');
        expect(QueryBuilder.buildWhereClauseRaw(filters),
            'client_reference_id IN ($placeholders)');
        expect(QueryBuilder.buildWhereArgs(filters).map((arg) => arg.value),
            expected);
      }

      final successRoutes = routesTo('stockSuccess');
      expect(successRoutes, isNotEmpty);
      final created = successRoutes.where(
          (route) => refsTemplate(route).contains('contextData.entities'));
      expect(created, hasLength(2));
      for (final route in successRoutes) {
        final refs = resolveNavigationDataValue(
          rawValue: refsTemplate(route),
          stateFormData: const {},
          contextData: {
            'formData': <String, dynamic>{},
            'entities': [StockModel(clientReferenceId: 'created-row')],
            'navigation': {'clientReferenceId': 'updated-row'},
          },
        );
        final detailRefs = resolveNavigationDataValue(
          rawValue: refsTemplate(acknowledgement),
          contextData: {
            'formData': <String, dynamic>{},
            'navigation': {'selectedStockRefs': refs},
          },
        );
        expectLookup(detailRefs,
            [created.contains(route) ? 'created-row' : 'updated-row']);
      }

      for (final ids in [
        ['mrn-row-1', 'mrn-row-2'],
        ['web-row'],
        ['next-row'],
      ]) {
        final refs = resolveNavigationDataValue(
          rawValue: refsTemplate(listRoute),
          stateWrapperFirst: {
            'formData': <String, dynamic>{},
            'item': {
              'items': ids.map((id) => StockModel(clientReferenceId: id)).toList(),
            },
          },
          contextData: const {},
        );
        expectLookup(refs, ids);
      }
    });
  });
}
