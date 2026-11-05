import 'package:collection/collection.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_formula_parser/digit_formula_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';

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
/// The fix keys those rows on clientReferenceId instead, and has the details
/// screen filter on that column rather than substring-matching a JSON blob.
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

  group('viewTransactionDetails search', () {
    List<Map<String, dynamic>> detailsFilters() {
      final details = flowNamed('viewTransactionDetails');
      final initActions = (details['initActions'] as List).cast<Map<String, dynamic>>();
      final search = initActions.firstWhere(
        (a) => a['actionType'] == 'SEARCH_EVENT',
        orElse: () => throw StateError('viewTransactionDetails has no SEARCH_EVENT'),
      );
      return ((search['properties'] as Map)['data'] as List)
          .cast<Map<String, dynamic>>();
    }

    test('carries both an id filter and an MRN filter', () {
      // Routes in supply different identifiers, so the screen needs both:
      // a transactions list has clientReferenceIds; stockSuccess after
      // RECORDSTOCK / RECORDLESSEXCESS has only the MRN, because those flows
      // create a record and never capture its clientReferenceId.
      final filters = detailsFilters();

      final byRef = filters.firstWhere(
        (f) => f['key'] == 'clientReferenceId',
        orElse: () => throw StateError('no clientReferenceId filter'),
      );
      expect(byRef['operation'], 'in');

      final byMrn = filters.firstWhere(
        (f) => f['key'] == 'additionalFields',
        orElse: () => throw StateError('no additionalFields/MRN filter - the '
            'MRN-only routes (PHU return) cannot resolve their record'),
      );
      expect(byMrn['operation'], 'contains');
    });

    test('details search applies only the filters with identifiers', () {
      List<String> activeFields(Map<String, dynamic> navigation) {
        return detailsFilters()
            .where((filter) {
              final guard = filter['applyIf'] as String?;
              if (guard == null) return true;
              final expression =
                  resolveTemplate(guard, {'navigation': navigation});
              final result = FormulaParser(expression, {'_dummy': ''}).parse;
              expect(result['isSuccess'], isTrue, reason: expression);
              return result['value'] == true;
            })
            .map((filter) => filter['key'] as String)
            .toList();
      }

      expect(activeFields({'selectedStock': 'AB12-CD34-EF56'}),
          ['additionalFields']);
      expect(activeFields({'selectedStockRefs': '', 'selectedStock': 'MRN-1'}),
          ['additionalFields']);
      expect(activeFields({'selectedStockRefs': 'stock-1,stock-2'}),
          ['clientReferenceId']);
      expect(
          activeFields({'selectedStockRefs': 'stock-1', 'selectedStock': ''}),
          ['clientReferenceId']);
      expect(
          activeFields(
              {'selectedStockRefs': 'stock-1', 'selectedStock': 'MRN-1'}),
          ['clientReferenceId', 'additionalFields']);
      expect(activeFields({}), isEmpty);
    });

    test('neither filter uses a non-matching sentinel', () {
      // The filter list is AND-ed, so a filter that matches NOTHING when its
      // input is absent makes the whole query unsatisfiable - that is exactly
      // how a __NO_STOCK_REFS__ fallback blanked this screen for a PHU return,
      // where the MRN was present and would have found the record.
      for (final f in detailsFilters()) {
        final value = f['value'] as String;
        expect(value, isNot(contains('__NO_')),
            reason: '${f['key']} falls back to a value that matches nothing; '
                'AND-ed with the other filter that blanks the screen');
      }
    });

    test('EVERY navigation supplies at least one identifier', () {
      // At least one filter must be active for the details search to run.
      final navs = findMaps(
        sampleInventoryFlows,
        (m) => m['name'] == 'viewTransactionDetails' && m['data'] is List,
      );

      expect(navs.length, greaterThanOrEqualTo(2),
          reason: 'expected the success screen and the transactions list');

      for (final nav in navs) {
        final keys = (nav['data'] as List)
            .cast<Map<String, dynamic>>()
            .map((d) => d['key'])
            .toSet();

        expect(
          keys.contains('selectedStockRefs') || keys.contains('selectedStock'),
          isTrue,
          reason: 'a navigation to viewTransactionDetails passes neither '
              'selectedStockRefs nor selectedStock, so both filters stand '
              'down and the details search is skipped. '
              'Passed keys: ${keys.toList()}',
        );
      }
    });

    test('the refs-less flows are entered with a generated MRN', () {
      // RECORDSTOCK and RECORDLESSEXCESS create a record and never capture its
      // clientReferenceId, so their success screen can only identify it by
      // MRN. That MRN is minted when the flow is ENTERED - if a flow were ever
      // entered without one, both filters on viewTransactionDetails would
      // stand down and the details search would be skipped.
      //
      // This is the runtime half of the "at least one identifier" invariant:
      // the test above proves a key is passed, this one proves it has a value.
      for (final flow in ['RECORDSTOCK', 'RECORDLESSEXCESS']) {
        final navsIn = findMaps(
          sampleInventoryFlows,
          (m) => m['name'] == flow && m['data'] is List,
        );

        expect(navsIn, isNotEmpty, reason: 'no navigation into $flow');

        final anyMintsMrn = navsIn.any((nav) =>
            (nav['data'] as List).cast<Map<String, dynamic>>().any((d) =>
                d['key'] == 'mrnNumber' &&
                (d['value'] as String?)
                        ?.contains('generateUniqueMaterialNoteNumber') ==
                    true));

        expect(anyMintsMrn, isTrue,
            reason: '$flow is entered without minting an mrnNumber. Its '
                'success screen has no clientReferenceId either, so '
                'viewTransactionDetails would skip the search.');
      }
    });

    test('the list route passes the row MRN, never the group key', () {
      // Since groupByFallback the group key may be a clientReferenceId, which
      // appears nowhere in the additionalFields blob - passing it as
      // selectedStock would make the MRN filter match nothing and blank the
      // screen for exactly the web-created rows this all exists to fix.
      final navs = findMaps(
        sampleInventoryFlows,
        (m) => m['name'] == 'viewTransactionDetails' && m['data'] is List,
      );

      for (final nav in navs) {
        final entry = (nav['data'] as List)
            .cast<Map<String, dynamic>>()
            .where((d) => d['key'] == 'selectedStock')
            .firstOrNull;
        if (entry == null) continue;

        expect(entry['value'], isNot(contains('groupKey')),
            reason: 'selectedStock is the group key, which may be a '
                'clientReferenceId and will not substring-match '
                'additionalFields');
      }
    });
  });
}
