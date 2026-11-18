import 'package:digit_data_model/data_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/stock_calculation_utils.dart';
import 'package:health_campaign_field_worker_app/widgets/inventory/custom_product_selection_card.dart';

// QA 2026-11-18 (SL): a distributor with 115 in hand got "no stock available"
// on Loss, because stock in hand was looked up for warehouseDetails.
// facilityToWhich (the PARENT warehouse) instead of the distributor's uuid.
void main() {
  const pv = 'PVAR-1';
  const parent = 'F-PHU-1';
  const uuid = '11111111-2222-3333-4444-555555555555';

  StockModel stock(String id, String sender, String receiver, String tx,
          double qty, List<AdditionalField> fields) =>
      StockModel(
        clientReferenceId: id,
        productVariantId: pv,
        senderId: sender,
        receiverId: receiver,
        transactionType: tx,
        quantity: qty.toString(),
        additionalFields: StockAdditionalFields(version: 1, fields: fields),
      );

  final stocks = [
    // Issue PHU -> distributor, accepted in place.
    stock('iss', parent, uuid, 'DISPATCHED', 130, const [
      AdditionalField('stockEntryType', 'ISSUED'),
      AdditionalField('status', 'ACCEPTED'),
    ]),
    // Earlier Loss of 10 and Excess of 5 (as stockLessExcess saves them).
    stock('loss', uuid, parent, 'DISPATCHED', 10, const [
      AdditionalField('stockEntryType', 'LESS'),
      AdditionalField('status', 'LOST'),
    ]),
    stock('exc', parent, uuid, 'RECEIVED', 5, const [
      AdditionalField('stockEntryType', 'EXCESS'),
      AdditionalField('status', 'RECEIVED'),
    ]),
    // Return of 10 still in transit.
    stock('ret', uuid, parent, 'DISPATCHED', 10, const [
      AdditionalField('stockEntryType', 'RETURNED'),
      AdditionalField('status', 'IN_TRANSIT'),
    ]),
  ];

  double inHandFor(String holder) =>
      StockCalculationUtils.calculateStockInHandForProducts(
        stockList: stocks,
        facilityId: holder,
        productIds: [pv],
        isDistributor: true,
      )[pv]!;

  test('the distributor holds the stock, the parent warehouse id shows 0', () {
    expect(inHandFor(uuid), 115);
    expect(inHandFor(parent), 0);
  });

  group('lessExcessStockHolderId', () {
    const lessExcess = {'stockEntryType': 'LESS_EXCESS'};

    test('distributor on Loss/Excess -> own uuid', () {
      final holder = lessExcessStockHolderId(
          navigationParams: lessExcess, isDistributor: true, userUuid: uuid);
      expect(holder, uuid);
      expect(inHandFor(holder!), 115);
    });

    test('not a distributor -> usual lookup', () {
      expect(
          lessExcessStockHolderId(
              navigationParams: lessExcess,
              isDistributor: false,
              userUuid: uuid),
          isNull);
    });

    test('other stock entry types -> usual lookup', () {
      for (final type in ['ISSUED', 'RETURNED', 'RECEIPT', null]) {
        expect(
            lessExcessStockHolderId(
                navigationParams: {'stockEntryType': type},
                isDistributor: true,
                userUuid: uuid),
            isNull,
            reason: '$type');
      }
    });

    test('no uuid -> usual lookup', () {
      for (final id in [null, '']) {
        expect(
            lessExcessStockHolderId(
                navigationParams: lessExcess,
                isDistributor: true,
                userUuid: id),
            isNull);
      }
    });
  });
}
