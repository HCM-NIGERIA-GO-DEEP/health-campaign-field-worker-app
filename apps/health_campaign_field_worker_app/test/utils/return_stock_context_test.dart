import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';
import 'package:health_campaign_field_worker_app/utils/stock_constants.dart';

void main() {
  // The RECORDSTOCK FETCH_TRANSFORMER_CONFIG entries in the liquid
  // campaign's INVENTORY config. The `stock` transformer maps them to the
  // `quantityPartialUsed` / `quantityWastage` additionalFields.
  const inventoryData = [
    {
      'key': 'quantityPartialML',
      'perEntity': true,
      'value':
          '{{fn:calculatePartial(formData.stockProductDetails.quantityReturned, formData.stockProductDetails.quantityPartialUsed, formData.stockDetails.productdetail.id)}}',
    },
    {
      'key': 'quantityWastage',
      'perEntity': true,
      'value': '{{formData.stockProductDetails.quantityWastage}}',
    },
  ];

  // One product of the return form, after the transformer has mapped its
  // `_item_N` fields to base names.
  Map<String, dynamic> returnedProduct(
    String productId, {
    required dynamic returned,
    required dynamic partial,
    required dynamic wastage,
  }) =>
      {
        'stockDetails': {
          'productdetail': {'id': productId},
        },
        'stockProductDetails': {
          'quantityReturned': returned,
          'quantityPartialUsed': partial,
          'quantityWastage': wastage,
        },
      };

  Map<String, dynamic> contextFor(Map<String, dynamic> product) =>
      TransformerExecutor.resolvePerEntityContext(
        extraData: inventoryData,
        baseContext: const {},
        contextData: const {},
        entityFormValues: product,
      );

  testWidgets('each returned product gets its own partial and wastage',
      (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox.shrink();
    }));
    // Balances are cached in display units.
    StockBalanceCache.instance.setCache('facility-1', {'p1': 305, 'p2': 600});
    addTearDown(StockBalanceCache.instance.clear);

    final first = contextFor(
      returnedProduct('p1', returned: '10', partial: '1', wastage: '3'),
    );
    final second = contextFor(
      returnedProduct('p2', returned: 20, partial: 0, wastage: 7),
    );

    // A reported part-used unit holds the remainder of the balance.
    expect(first['quantityPartialML'], 305 % StockConstants.multiplier);
    expect(second['quantityPartialML'], 0);
    // Wastage is the per-product value the form auto-filled.
    expect(first['quantityWastage'], '3');
    expect(second['quantityWastage'], 7);
  });
}
