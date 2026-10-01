import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransformerExecutor.resolvePerEntityContext', () {
    // One item of a multi-entity form after _mapEntityFieldsToBase: the
    // item's fields carry their base names.
    Map<String, dynamic> itemForm(String productId, num wastage) => {
          'stockDetails': {
            'productdetail': {'id': productId},
          },
          'stockProductDetails': {'quantityWastage': wastage},
        };

    const wastageEntry = {
      'key': 'quantityWastage',
      'perEntity': true,
      'value': '{{formData.stockProductDetails.quantityWastage}}',
    };

    test('returns the base context as-is when no entry is perEntity', () {
      final base = {'mrnNumber': 'MRN-1'};
      final result = TransformerExecutor.resolvePerEntityContext(
        extraData: [
          {'key': 'mrnNumber', 'value': '{{navigation.mrnNumber}}'},
        ],
        baseContext: base,
        contextData: const {},
        entityFormValues: itemForm('p1', 3),
      );
      expect(identical(result, base), isTrue);
    });

    test('resolves perEntity entries against each item separately', () {
      final base = {'mrnNumber': 'MRN-1'};
      final first = TransformerExecutor.resolvePerEntityContext(
        extraData: [wastageEntry],
        baseContext: base,
        contextData: const {},
        entityFormValues: itemForm('p1', 3),
      );
      final second = TransformerExecutor.resolvePerEntityContext(
        extraData: [wastageEntry],
        baseContext: base,
        contextData: const {},
        entityFormValues: itemForm('p2', 7),
      );

      expect(first['quantityWastage'], 3);
      expect(second['quantityWastage'], 7);
      // Non-perEntity keys are carried over and the base is not mutated.
      expect(first['mrnNumber'], 'MRN-1');
      expect(base.containsKey('quantityWastage'), isFalse);
    });

    test('passes the item fields into fn: arguments', () {
      FunctionRegistry.register(
          'testEchoProduct', (args, stateData) => 'product:${args.first}');

      final result = TransformerExecutor.resolvePerEntityContext(
        extraData: [
          {
            'key': 'productLabel',
            'perEntity': true,
            'value':
                '{{fn:testEchoProduct(formData.stockDetails.productdetail.id)}}',
          },
        ],
        baseContext: const {},
        contextData: const {},
        entityFormValues: itemForm('p9', 0),
      );

      expect(result['productLabel'], 'product:p9');
    });

    test('drops a key that does not resolve for this item', () {
      final result = TransformerExecutor.resolvePerEntityContext(
        extraData: [wastageEntry],
        // Value resolved against the whole form, which must not leak into
        // an item that has no wastage of its own.
        baseContext: const {'quantityWastage': 99},
        contextData: const {},
        entityFormValues: const {'stockProductDetails': <String, dynamic>{}},
      );

      expect(result.containsKey('quantityWastage'), isFalse);
    });

    test('keeps the rest of contextData visible to the templates', () {
      final result = TransformerExecutor.resolvePerEntityContext(
        extraData: [
          {
            'key': 'entryType',
            'perEntity': true,
            'value': '{{navigation.stockEntryType}}',
          },
        ],
        baseContext: const {},
        contextData: const {
          'navigation': {'stockEntryType': 'RETURNED'},
        },
        entityFormValues: itemForm('p1', 0),
      );

      expect(result['entryType'], 'RETURNED');
    });
  });
}
