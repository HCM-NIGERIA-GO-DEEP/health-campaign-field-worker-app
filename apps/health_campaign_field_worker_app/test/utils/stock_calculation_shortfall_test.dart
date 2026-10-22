import 'package:digit_data_model/data_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/stock_calculation_utils.dart';

/// Reproduces the exact QA-reported mismatch: a facility ("DP") with 46
/// units on hand partially accepts three separate dispatches from PHU -
/// 10 -> 8 (In-transit), 8 -> 5 (Stock Loss), 6 -> 4 (Stock Damage).
///
/// Partially accepting creates two records per dispatch: a "stockReceipt"
/// entity for the quantity DP actually accepted, and (via the
/// shortfallTransaction transformer) a RETURNED notification - sent by DP,
/// received by PHU - carrying the shortfall back as a bookkeeping message.
///
/// DP's own balance should land at 46 + 8 + 5 + 4 = 63: exactly what was
/// accepted, nothing more, nothing less. Before the originalIssueClientReferenceId
/// gate in calculateStockMetrics, DP's own shortfall-notification records (where
/// DP is sender) were mistakenly folded into DP's own balance too - adding the
/// 2+3+2 shortfall under the non-distributor formula, or subtracting it under the
/// distributor one - landing at 63-7=56 for a distributor-flagged facility.
void main() {
  const facilityId = 'DP-FACILITY';
  const otherFacilityId = 'PHU-FACILITY';
  const productVariantId = 'PVAR-1';

  StockModel priorBalance(double quantity) => StockModel(
        clientReferenceId: 'prior-balance',
        productVariantId: productVariantId,
        senderId: otherFacilityId,
        receiverId: facilityId,
        transactionType: 'RECEIVED',
        quantity: quantity.toString(),
      );

  StockModel acceptedReceipt(String clientReferenceId, double quantity) =>
      StockModel(
        clientReferenceId: clientReferenceId,
        productVariantId: productVariantId,
        senderId: otherFacilityId,
        receiverId: facilityId,
        transactionType: 'RECEIVED',
        quantity: quantity.toString(),
        additionalFields: StockAdditionalFields(
          version: 1,
          fields: const [
            AdditionalField('stockEntryType', 'RECEIPT'),
          ],
        ),
      );

  StockModel shortfallNotification(
    String clientReferenceId,
    String originalIssueClientReferenceId,
    double quantity,
    String discrepancyReason,
  ) =>
      StockModel(
        clientReferenceId: clientReferenceId,
        productVariantId: productVariantId,
        senderId: facilityId,
        receiverId: otherFacilityId,
        transactionType: 'DISPATCHED',
        quantity: quantity.toString(),
        additionalFields: StockAdditionalFields(
          version: 1,
          fields: [
            const AdditionalField('stockEntryType', 'RETURNED'),
            const AdditionalField('status', 'IN_TRANSIT'),
            AdditionalField(
              'originalIssueClientReferenceId',
              originalIssueClientReferenceId,
            ),
            AdditionalField('discrepancyReason', discrepancyReason),
          ],
        ),
      );

  group('partially accepting multiple dispatches with shortfalls', () {
    test(
        'non-distributor facility: own shortfall notifications do not inflate its balance',
        () {
      final stockList = [
        priorBalance(46),
        acceptedReceipt('receipt-1', 8),
        shortfallNotification('shortfall-1', 'dispatch-1', 2, 'IN_TRANSIT'),
        acceptedReceipt('receipt-2', 5),
        shortfallNotification('shortfall-2', 'dispatch-2', 3, 'STOCK_LOSS'),
        acceptedReceipt('receipt-3', 4),
        shortfallNotification('shortfall-3', 'dispatch-3', 2, 'STOCK_DAMAGE'),
      ];

      final balance = StockCalculationUtils.getStockBalance(
        stockList: stockList,
        facilityId: facilityId,
        productId: productVariantId,
        isDistributor: false,
      );

      expect(balance, 63);
    });

    test(
        'distributor-flagged facility: own shortfall notifications do not reduce its balance',
        () {
      final stockList = [
        priorBalance(46),
        acceptedReceipt('receipt-1', 8),
        shortfallNotification('shortfall-1', 'dispatch-1', 2, 'IN_TRANSIT'),
        acceptedReceipt('receipt-2', 5),
        shortfallNotification('shortfall-2', 'dispatch-2', 3, 'STOCK_LOSS'),
        acceptedReceipt('receipt-3', 4),
        shortfallNotification('shortfall-3', 'dispatch-3', 2, 'STOCK_DAMAGE'),
      ];

      final balance = StockCalculationUtils.getStockBalance(
        stockList: stockList,
        facilityId: facilityId,
        productId: productVariantId,
        isDistributor: true,
      );

      expect(balance, 63);
    });

    test(
        'a genuine deliberate Return (no originalIssueClientReferenceId) still decrements normally',
        () {
      final deliberateReturn = StockModel(
        clientReferenceId: 'deliberate-return',
        productVariantId: productVariantId,
        senderId: facilityId,
        receiverId: otherFacilityId,
        transactionType: 'DISPATCHED',
        quantity: '10',
        additionalFields: StockAdditionalFields(
          version: 1,
          fields: const [
            AdditionalField('stockEntryType', 'RETURNED'),
          ],
        ),
      );

      final balance = StockCalculationUtils.getStockBalance(
        stockList: [priorBalance(46), deliberateReturn],
        facilityId: facilityId,
        productId: productVariantId,
        isDistributor: false,
      );

      // A genuine return decrements this facility's balance (46-10=36) -
      // correct, since this facility legitimately owned and shed the stock.
      // Unaffected by the shortfall-notification gate since there's no
      // originalIssueClientReferenceId here.
      expect(balance, 36);
    });
  });

  group('sender (PHU) balance after the receiver partially accepts', () {
    const phuId = 'PHU-FACILITY-2';
    const dpId = 'DP-FACILITY-2';
    const productId = 'PVAR-2';

    /// The ORIGINAL dispatch record, as it sits AFTER DP's partial accept
    /// has run its UPDATE_EVENT: StockModel.quantity is overwritten down to
    /// actualQuantityReceived, with originalQuantityReceived preserving the
    /// true dispatched amount separately. This is the exact shape the
    /// partial-accept onSecondaryAction branch produces in
    /// manage_stock.dart.
    StockModel mutatedDispatch(
      String clientReferenceId,
      double originalQuantity,
      double acceptedQuantity,
    ) =>
        StockModel(
          clientReferenceId: clientReferenceId,
          productVariantId: productId,
          senderId: phuId,
          receiverId: dpId,
          transactionType: 'DISPATCHED',
          quantity: acceptedQuantity.toString(),
          additionalFields: StockAdditionalFields(
            version: 1,
            fields: [
              const AdditionalField('stockEntryType', 'ISSUED'),
              const AdditionalField('status', 'ACCEPTED'),
              AdditionalField(
                  'actualQuantityReceived', acceptedQuantity.toString()),
              AdditionalField(
                  'originalQuantityReceived', originalQuantity.toString()),
            ],
          ),
        );

    test(
        "sender's stockIssued uses the originally dispatched amount, not the "
        "receiver-truncated quantity left on the shared record", () {
      final stockList = [
        mutatedDispatch('dispatch-1', 12, 7),
        mutatedDispatch('dispatch-2', 10, 6),
        mutatedDispatch('dispatch-3', 8, 5),
      ];

      final balance = StockCalculationUtils.getStockBalance(
        stockList: stockList,
        facilityId: phuId,
        productId: productId,
        isDistributor: false,
      );

      // PHU dispatched 12+10+8=30 total - that's what must leave its books,
      // regardless of what DP went on to accept (7+6+5=18). Before the
      // sender/receiver split in the quantity computation, this read back
      // 18 (the post-mutation `quantity` field), undercounting the true
      // issued amount by exactly the accepted total.
      expect(balance, -30);
    });

    test(
        'full saga: issue 12/10/8, DP partially accepts 7/6/5, PHU then '
        'resolves all three returns (in-transit nets to zero via reissue, '
        'lost/damage are terminal write-offs with no balance impact)', () {
      final stockList = [
        // Starting balance.
        StockModel(
          clientReferenceId: 'prior-balance',
          productVariantId: productId,
          senderId: 'SOME-OTHER-FACILITY',
          receiverId: phuId,
          transactionType: 'RECEIVED',
          quantity: '1917',
        ),
        // The three original dispatches, each mutated by DP's partial
        // accept.
        mutatedDispatch('dispatch-1', 12, 7),
        mutatedDispatch('dispatch-2', 10, 6),
        mutatedDispatch('dispatch-3', 8, 5),
        // Shortfall-return #1 (in-transit, 12-7=5): PHU accepts it via the
        // generic in-transit re-issue branch - credited via a fresh
        // "stockReceipt"-style RECEIVED entity, then immediately re-issued
        // back to DP as a brand new DISPATCHED record. Net zero for PHU.
        StockModel(
          clientReferenceId: 'return-receipt-1',
          productVariantId: productId,
          senderId: dpId,
          receiverId: phuId,
          transactionType: 'RECEIVED',
          quantity: '5',
          additionalFields: StockAdditionalFields(
            version: 1,
            fields: const [AdditionalField('stockEntryType', 'RECEIPT')],
          ),
        ),
        StockModel(
          clientReferenceId: 'reissue-1',
          productVariantId: productId,
          senderId: phuId,
          receiverId: dpId,
          transactionType: 'DISPATCHED',
          quantity: '5',
          additionalFields: StockAdditionalFields(
            version: 1,
            fields: const [
              AdditionalField('stockEntryType', 'ISSUED'),
              AdditionalField('status', 'IN_TRANSIT'),
            ],
          ),
        ),
        // Shortfall-return #2 (stock loss, 10-6=4): PHU accepts it as a
        // terminal write-off - quantity zeroed, no balance impact anywhere.
        StockModel(
          clientReferenceId: 'return-2',
          productVariantId: productId,
          senderId: dpId,
          receiverId: phuId,
          transactionType: 'DISPATCHED',
          quantity: '0',
          additionalFields: StockAdditionalFields(
            version: 1,
            fields: const [
              AdditionalField('stockEntryType', 'RETURNED'),
              AdditionalField('status', 'ACCEPTED'),
              AdditionalField('actualQuantityReceived', '0'),
              AdditionalField('originalIssueClientReferenceId', 'dispatch-2'),
            ],
          ),
        ),
        // Shortfall-return #3 (stock damage, 8-5=3): same terminal
        // write-off treatment as loss.
        StockModel(
          clientReferenceId: 'return-3',
          productVariantId: productId,
          senderId: dpId,
          receiverId: phuId,
          transactionType: 'DISPATCHED',
          quantity: '0',
          additionalFields: StockAdditionalFields(
            version: 1,
            fields: const [
              AdditionalField('stockEntryType', 'DAMAGED'),
              AdditionalField('status', 'ACCEPTED'),
              AdditionalField('actualQuantityReceived', '0'),
              AdditionalField('originalIssueClientReferenceId', 'dispatch-3'),
            ],
          ),
        ),
      ];

      final balance = StockCalculationUtils.getStockBalance(
        stockList: stockList,
        facilityId: phuId,
        productId: productId,
        isDistributor: false,
      );

      // 1917 - 30 (the full originally dispatched amount) + 0 (in-transit
      // nets to zero) + 0 (loss/damage never come back) = 1887.
      expect(balance, 1887);
    });
  });
}
