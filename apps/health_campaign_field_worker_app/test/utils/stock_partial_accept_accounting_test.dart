import 'package:digit_data_model/data_model.dart';
import 'package:health_campaign_field_worker_app/utils/stock_calculation_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StockModel dispatchedStock({
    required String status,
    String quantity = '10',
    String? actualQuantityReceived,
    String? originalQuantityReceived,
    String senderId = 'sender-1',
    String receiverId = 'receiver-1',
  }) {
    final fields = <AdditionalField>[
      AdditionalField('status', status),
      if (actualQuantityReceived != null)
        AdditionalField('actualQuantityReceived', actualQuantityReceived),
      if (originalQuantityReceived != null)
        AdditionalField('originalQuantityReceived', originalQuantityReceived),
    ];

    return StockModel(
      clientReferenceId: 'dispatch-1',
      productVariantId: 'product-1',
      quantity: quantity,
      transactionType: 'DISPATCHED',
      senderId: senderId,
      receiverId: receiverId,
      additionalFields: StockAdditionalFields(version: 1, fields: fields),
    );
  }

  test(
      'partial acceptance contributes only actual received quantity to balances',
      () {
    final partial = dispatchedStock(
      status: 'ACCEPTED',
      actualQuantityReceived: '6',
      originalQuantityReceived: '10',
    );

    final receiverMetrics = StockCalculationUtils.calculateStockMetrics(
      stockList: [partial],
      facilityId: 'receiver-1',
      productId: 'product-1',
    );
    final senderMetrics = StockCalculationUtils.calculateStockMetrics(
      stockList: [partial],
      facilityId: 'sender-1',
      productId: 'product-1',
    );

    expect(receiverMetrics['stockReceived'], 6);
    expect(receiverMetrics['stockInHand'], 6);
    expect(senderMetrics['stockIssued'], 10);
    expect(senderMetrics['stockInHand'], -10);
  });

  test('sender reconciliation returns only the undelivered partial quantity',
      () {
    final partial = dispatchedStock(
      status: 'ACCEPTED',
      actualQuantityReceived: '6',
      originalQuantityReceived: '10',
    );

    expect(StockCalculationUtils.getSenderShortfall(partial), 4);
  });

  test('full accepted dispatch has no sender shortfall', () {
    expect(
      StockCalculationUtils.getSenderShortfall(
        dispatchedStock(status: 'ACCEPTED'),
      ),
      0,
    );
  });

  test('legacy outright rejection still restores the full dispatch quantity',
      () {
    expect(
      StockCalculationUtils.getSenderShortfall(
        dispatchedStock(status: 'REJECTED'),
      ),
      10,
    );
  });
}
