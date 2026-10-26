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

  /// Second round of the in-transit cycle: PHU reissues the shortfall, and
  /// DP partially accepts THAT reissue too.
  ///
  /// The existing saga stops after the first reissue - it is left IN_TRANSIT
  /// and never re-accepted - so nothing covered what happens when the cycle
  /// repeats. Note also that the saga's `reissue-1` fixture carries only
  /// stockEntryType/status, while the real reissue written by
  /// manage_stock.dart additionally sets originalIssueClientReferenceId and
  /// discrepancyReason. The reissue branch in calculateStockMetrics keys off
  /// BOTH of those, so it was never exercised by any test.
  group('second round: DP partially accepts the reissue as well', () {
    const phuId = 'PHU-FACILITY-3';
    const dpId = 'DP-FACILITY-3';
    const productId = 'PVAR-3';

    /// A reissue as manage_stock.dart actually writes it: an ISSUED record
    /// carrying the ORIGINAL dispatch's reference plus the IN_TRANSIT
    /// discrepancy reason. Shown here after DP's own partial accept has
    /// mutated it (status ACCEPTED, quantity truncated to the accepted
    /// amount, original amount preserved separately).
    StockModel mutatedReissue({
      required String clientReferenceId,
      required String originalIssueClientReferenceId,
      required double reissuedQuantity,
      required double acceptedQuantity,
    }) =>
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
              const AdditionalField('discrepancyReason', 'IN_TRANSIT'),
              AdditionalField(
                  'actualQuantityReceived', acceptedQuantity.toString()),
              AdditionalField(
                  'originalQuantityReceived', reissuedQuantity.toString()),
              AdditionalField('originalIssueClientReferenceId',
                  originalIssueClientReferenceId),
            ],
          ),
        );

    // NOTE: no separate "RECEIPT" entity is modelled here. Per
    // getStockEntryType in function_registries.dart, stockEntryType RECEIPT
    // is never persisted - the stockReceipt transformer only builds it on a
    // transient entity that seeds the UPDATE_EVENT, and the record actually
    // saved is the original dispatch mutated in place, still ISSUED. The
    // mutated dispatch below therefore IS DP's credit; adding a RECEIPT row
    // as well would double-count it.

    /// DP's shortfall message back to PHU for the part it could not account
    /// for. In round two this points at the REISSUE, not the original
    /// dispatch.
    StockModel shortfallFromDp(
      String clientReferenceId,
      String originalIssueClientReferenceId,
      double quantity,
    ) =>
        StockModel(
          clientReferenceId: clientReferenceId,
          productVariantId: productId,
          senderId: dpId,
          receiverId: phuId,
          transactionType: 'DISPATCHED',
          quantity: quantity.toString(),
          additionalFields: StockAdditionalFields(
            version: 1,
            fields: [
              const AdditionalField('stockEntryType', 'RETURNED'),
              const AdditionalField('status', 'IN_TRANSIT'),
              const AdditionalField('discrepancyReason', 'IN_TRANSIT'),
              AdditionalField('originalIssueClientReferenceId',
                  originalIssueClientReferenceId),
            ],
          ),
        );

    // PHU issues 12. DP accepts 7, shortfall 5. PHU reissues the 5.
    // DP then accepts 3 of that reissue, shortfall 2.
    List<StockModel> sagaRecords() => [
          StockModel(
            clientReferenceId: 'dispatch-1',
            productVariantId: productId,
            senderId: phuId,
            receiverId: dpId,
            transactionType: 'DISPATCHED',
            quantity: '7',
            additionalFields: StockAdditionalFields(
              version: 1,
              fields: const [
                AdditionalField('stockEntryType', 'ISSUED'),
                AdditionalField('status', 'ACCEPTED'),
                AdditionalField('actualQuantityReceived', '7'),
                AdditionalField('originalQuantityReceived', '12'),
              ],
            ),
          ),
          shortfallFromDp('shortfall-1', 'dispatch-1', 5),
          mutatedReissue(
            clientReferenceId: 'reissue-1',
            originalIssueClientReferenceId: 'dispatch-1',
            reissuedQuantity: 5,
            acceptedQuantity: 3,
          ),
          shortfallFromDp('shortfall-2', 'reissue-1', 2),
        ];

    test('DP is credited for what it accepted in BOTH rounds (7 + 3)', () {
      final balance = StockCalculationUtils.getStockBalance(
        stockList: sagaRecords(),
        facilityId: dpId,
        productId: productId,
        isDistributor: false,
      );

      // DP physically holds 7 from the first accept plus 3 from the reissue.
      // The two shortfall messages are DP's own bookkeeping and must not move
      // its balance either way.
      expect(balance, 10);
    });

    test("PHU's books show the original 12 only once, not again per reissue",
        () {
      final balance = StockCalculationUtils.getStockBalance(
        stockList: sagaRecords(),
        facilityId: phuId,
        productId: productId,
        isDistributor: false,
      );

      // The full 12 left PHU on the original dispatch. Reissuing part of it
      // moves already-deducted stock, so it must not deduct a second time -
      // and the shortfalls coming back are notifications, not returns of
      // physical stock.
      expect(balance, -12);
    });
  });
}
