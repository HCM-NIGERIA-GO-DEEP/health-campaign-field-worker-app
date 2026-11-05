import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/blocs/wrapper/entity_grouper.dart';
import 'package:digit_flow_builder/blocs/wrapper/value_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grouping incoming stock transactions by MRN broke for anything created
/// from the web (Commodity Management), which does not send an mrnNumber.
///
/// Every such row fell into its own synthetic 'null_0', 'null_1', ... group:
/// the card rendered the literal text "MRN null_0", and because that key
/// exists nowhere in the stored data the drilldown's search could never find
/// the row again - viewTransactionDetails came up as a heading over an empty
/// body.
///
/// groupByFallback gives those rows a real, searchable key instead.
/// clientReferenceId is the right one: it is non-null on every StockModel and
/// is an indexed column rather than a substring of a JSON blob.
///
/// The fallback must apply ONLY where the primary path is null, so that rows
/// carrying a real MRN keep grouping together - a single receipt covering
/// several product variants is several rows sharing one MRN, and that must
/// stay one card.
void main() {
  final grouper = EntityGrouper(ValueResolver());

  const mrnPath = 'additionalFields.fields.mrnNumber';
  const refPath = 'clientReferenceId';

  StockModel stock({String? mrn, required String ref}) => StockModel(
        clientReferenceId: ref,
        additionalFields: mrn == null
            ? null
            : StockAdditionalFields(
                version: 1,
                fields: [AdditionalField('mrnNumber', mrn)],
              ),
      );

  /// groupKey -> number of rows in that group.
  Map<String, int> sizes(List<Map<String, dynamic>> groups) => {
        for (final g in groups)
          g['groupKey'] as String: (g['items'] as List).length,
      };

  group('without a fallback (unchanged behaviour)', () {
    test('groups rows that share an MRN, and only those', () {
      final groups = grouper.groupEntitiesByCustomField(
        [
          stock(mrn: 'MRN-1', ref: 'a'),
          stock(mrn: 'MRN-1', ref: 'b'),
          stock(mrn: 'MRN-2', ref: 'c'),
        ],
        mrnPath,
      );

      expect(sizes(groups), {'MRN-1': 2, 'MRN-2': 1});
    });

    test('still falls back to synthetic null keys when MRN is missing', () {
      // Callers that pass no fallback must behave exactly as before, so
      // adding the parameter cannot regress any other grouped screen.
      final groups = grouper.groupEntitiesByCustomField(
        [stock(ref: 'a'), stock(ref: 'b')],
        mrnPath,
      );

      expect(sizes(groups), {'null_0': 1, 'null_1': 1});
    });
  });

  group('with clientReferenceId as the fallback', () {
    test('keys MRN-less rows by their own id instead of null_N', () {
      final groups = grouper.groupEntitiesByCustomField(
        [stock(ref: 'ref-a'), stock(ref: 'ref-b')],
        mrnPath,
        fallbackFieldPath: refPath,
      );

      expect(sizes(groups), {'ref-a': 1, 'ref-b': 1});
      // The literal string that used to reach the UI as "MRN null_0".
      expect(
        groups.map((g) => g['groupKey']),
        isNot(contains(startsWith('null_'))),
      );
    });

    test('does NOT split rows that share a real MRN', () {
      // The regression that would matter most: if the fallback were applied
      // unconditionally, a multi-product receipt would explode into one card
      // per product variant.
      final groups = grouper.groupEntitiesByCustomField(
        [
          stock(mrn: 'MRN-1', ref: 'a'),
          stock(mrn: 'MRN-1', ref: 'b'),
        ],
        mrnPath,
        fallbackFieldPath: refPath,
      );

      expect(sizes(groups), {'MRN-1': 2});
    });

    test('handles a realistic mixed batch', () {
      // What the district warehouse actually sees: mostly MRN-bearing stock
      // with a handful of web-created rows mixed in.
      final groups = grouper.groupEntitiesByCustomField(
        [
          stock(mrn: 'MRN-1', ref: 'a'),
          stock(mrn: 'MRN-1', ref: 'b'),
          stock(ref: 'web-1'),
          stock(mrn: 'MRN-2', ref: 'c'),
          stock(ref: 'web-2'),
        ],
        mrnPath,
        fallbackFieldPath: refPath,
      );

      expect(sizes(groups), {
        'MRN-1': 2,
        'web-1': 1,
        'MRN-2': 1,
        'web-2': 1,
      });
    });

    test('every group key is resolvable back to the rows it came from', () {
      // The whole point of the change: the key must be usable as a search
      // term. A synthetic null_N is not, which is what left the details
      // screen empty.
      final entities = [
        stock(mrn: 'MRN-1', ref: 'a'),
        stock(ref: 'web-1'),
      ];

      final groups = grouper.groupEntitiesByCustomField(
        entities,
        mrnPath,
        fallbackFieldPath: refPath,
      );

      for (final g in groups) {
        final key = g['groupKey'] as String;
        final items = (g['items'] as List).cast<StockModel>();
        final matchesMrn = items.every((s) =>
            s.additionalFields?.fields
                .firstWhere((f) => f.key == 'mrnNumber')
                .value ==
            key);
        final matchesRef = items.every((s) => s.clientReferenceId == key);

        expect(matchesMrn || matchesRef, isTrue,
            reason: 'group key "$key" matches no field on its own rows');
      }
    });

    test('blank MRNs fall back and matching MRN and row ID stay separate', () {
      final groups = grouper.groupEntitiesByCustomField(
        [
          stock(mrn: 'web-1', ref: 'regular-1'),
          stock(ref: 'web-1'),
          stock(mrn: ' ', ref: 'web-2'),
          stock(mrn: 'null', ref: 'web-3'),
        ],
        mrnPath,
        fallbackFieldPath: refPath,
      );

      expect(groups.map((group) => group['groupKey']),
          ['web-1', 'web-1', 'web-2', 'web-3']);
      expect(
        groups.map((group) =>
            (group['items'] as List).cast<StockModel>().single.clientReferenceId),
        ['regular-1', 'web-1', 'web-2', 'web-3'],
      );
    });

    test('synthetic key remains only when BOTH paths are null', () {
      final groups = grouper.groupEntitiesByCustomField(
        [stock(ref: 'a')],
        mrnPath,
        fallbackFieldPath: 'someFieldThatDoesNotExist',
      );

      expect(sizes(groups), {'null_0': 1});
    });
  });
}
