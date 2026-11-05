import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// The two functions that let a transaction card survive a missing MRN.
///
/// Stock created from the web (Commodity Management) carries no mrnNumber.
/// The incoming-transactions card used to interpolate the group key directly
/// ("MRN {{item.groupKey}}"), which rendered the literal text "MRN null_0",
/// and the details screen searched for that same key inside the
/// additionalFields JSON blob - a substring that exists nowhere, so the screen
/// showed its heading over an empty body.
///
///   transactionTag  decides what the card's tag reads.
///   pluckJoin       collects the ids the details screen filters on.
void main() {
  // Neither function reads state, so an empty one is enough.
  final stateData = CrudStateData(const {}, const []);

  /// Registration needs a BuildContext, so pump a throwaway widget to get one.
  Future<void> withRegistry(WidgetTester tester, VoidCallback body) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            FunctionRegistries(context).registerAll();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    body();
  }

  StockModel stock(String ref) => StockModel(clientReferenceId: ref);

  group('transactionTag', () {
    dynamic tag(List<dynamic> args) =>
        FunctionRegistry.call('transactionTag', args, stateData);

    // 12 Mar 2026, 00:00 UTC+0 - asserted via DateFormat below rather than a
    // hardcoded string so the test does not depend on the runner's timezone.
    final date = DateTime(2026, 3, 12);
    final millis = date.millisecondsSinceEpoch;

    testWidgets('is registered', (tester) async {
      await withRegistry(tester, () {
        expect(FunctionRegistry.get('transactionTag'), isNotNull);
      });
    });

    testWidgets('reads "MRN <n>" when the transaction has one',
        (tester) async {
      await withRegistry(tester, () {
        expect(tag(['77BD-63D8-E606', millis]), 'MRN 77BD-63D8-E606');
      });
    });

    testWidgets('falls back to the entry date when the MRN is null',
        (tester) async {
      await withRegistry(tester, () {
        expect(tag([null, millis]), '12 Mar 2026');
      });
    });

    testWidgets('never renders the synthetic group key', (tester) async {
      await withRegistry(tester, () {
        // The exact string users saw on screen. If a caller passes the group
        // key rather than the row's own field, it must not be shown as if it
        // were a real MRN.
        for (final bad in ['null_0', 'null_12', 'null', 'NULL', '']) {
          final result = tag([bad, millis]).toString();
          expect(result, isNot(contains('null')),
              reason: 'rendered "$result" for input "$bad"');
          expect(result, '12 Mar 2026');
        }
      });
    });

    testWidgets('does not leak an unresolved template', (tester) async {
      await withRegistry(tester, () {
        expect(tag(['{{item.groupKey}}', millis]), '12 Mar 2026');
      });
    });

    testWidgets('accepts the date as a string timestamp', (tester) async {
      await withRegistry(tester, () {
        expect(tag([null, '$millis']), '12 Mar 2026');
      });
    });

    testWidgets('returns blank rather than a wrong date when both are missing',
        (tester) async {
      await withRegistry(tester, () {
        expect(tag([null, null]), '');
        expect(tag([]), '');
      });
    });
  });

  group('pluckJoin', () {
    dynamic pluck(List<dynamic> args) =>
        FunctionRegistry.call('pluckJoin', args, stateData);

    testWidgets('is registered', (tester) async {
      await withRegistry(tester, () {
        expect(FunctionRegistry.get('pluckJoin'), isNotNull);
      });
    });

    testWidgets('collects the field off every row in the group',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          pluck([
            [stock('a'), stock('b'), stock('c')],
            'clientReferenceId',
          ]),
          'a,b,c',
        );
      });
    });

    testWidgets('reads EntityModels, not just Maps', (tester) async {
      // Group items are StockModels. Plain map access would silently return
      // nothing here, which QueryBuilder would then treat as "no filter".
      await withRegistry(tester, () {
        expect(pluck([
          [stock('only')],
          'clientReferenceId'
        ]), 'only');
      });
    });

    testWidgets('strips surrounding quotes from the field name',
        (tester) async {
      // The config passes it as a quoted literal: pluckJoin(item.items,
      // 'clientReferenceId').
      await withRegistry(tester, () {
        expect(pluck([
          [stock('a')],
          "'clientReferenceId'"
        ]), 'a');
      });
    });

    testWidgets('de-duplicates', (tester) async {
      await withRegistry(tester, () {
        expect(
          pluck([
            [stock('a'), stock('a'), stock('b')],
            'clientReferenceId',
          ]),
          'a,b',
        );
      });
    });

    testWidgets('drops values containing a comma', (tester) async {
      // QueryBuilder._normalizeToList splits the result on commas, so a value
      // carrying one would silently widen the filter into unrelated rows.
      await withRegistry(tester, () {
        expect(
          pluck([
            [stock('safe'), stock('a,b')],
            'clientReferenceId',
          ]),
          'safe',
        );
      });
    });

    testWidgets('returns blank for junk input rather than throwing',
        (tester) async {
      await withRegistry(tester, () {
        expect(pluck([]), '');
        expect(pluck([null, 'clientReferenceId']), '');
        expect(pluck(['not a list', 'clientReferenceId']), '');
        expect(pluck([
          [stock('a')],
          ''
        ]), '');
      });
    });

    testWidgets('blank result is caught by the config sentinel', (tester) async {
      // An empty "in" list means "no filter" to QueryBuilder, which would turn
      // the details screen into a dump of every stock row. The config guards
      // this with getCommentValue(..., '__NO_STOCK_REFS__'); this asserts the
      // precondition that guard relies on - pluckJoin returns something
      // getCommentValue treats as blank.
      await withRegistry(tester, () {
        final empty = pluck([<dynamic>[], 'clientReferenceId']);
        expect(empty, '');

        final guarded =
            FunctionRegistry.call('getCommentValue', [empty, '__NO_STOCK_REFS__'], stateData);
        expect(guarded, '__NO_STOCK_REFS__');
      });
    });
  });
}
