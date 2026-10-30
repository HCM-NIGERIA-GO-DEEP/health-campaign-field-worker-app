import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/transaction_details_presentation.dart';

void main() {
  test('all acceptance routes use the resolved outcome heading', () {
    final config = jsonEncode(sampleInventoryFlows);
    expect(
        config,
        isNot(contains(
            "getViewTransactionHeadingCode(navigation.incomingStockEntryType, 'RECEIVED'")));
    expect(
        RegExp('getAcceptedTransactionHeadingCode').allMatches(config).length,
        5);
    expect(
        config,
        contains(
            'item.items[0].additionalFields.fields.originalIssueClientReferenceId)'));
  });
  test('acceptance and saved-record routes agree for shortfall resolutions',
      () {
    for (final reason in ['STOCK_LOSS', 'STOCK_DAMAGE', 'IN_TRANSIT']) {
      final type = {'STOCK_LOSS': 'LOSS', 'STOCK_DAMAGE': 'DAMAGED'}[reason] ??
          'RETURNED';
      expect(
        TransactionDetailsPresentation.acceptedHeading('RETURNED', reason),
        TransactionDetailsPresentation.heading(
            type, reason, reason, 'original'),
      );
    }
    // Full in-transit acceptance retains RECEIVED, unlike partial acceptance.
    expect(
      TransactionDetailsPresentation.acceptedHeading('RETURNED', 'IN_TRANSIT'),
      TransactionDetailsPresentation.heading(
          'RETURNED', 'RECEIVED', 'IN_TRANSIT', 'original'),
    );
  });

  test('a physical receipt stays a receipt despite its shortfall reason', () {
    for (final reason in ['STOCK_LOSS', 'STOCK_DAMAGE', 'IN_TRANSIT']) {
      expect(
        TransactionDetailsPresentation.acceptedHeading('ISSUED', reason),
        TransactionDetailsPresentation.heading('ISSUED', 'RECEIVED', reason),
      );
      expect(
          TransactionDetailsPresentation.heading('ISSUED', 'RECEIVED', reason),
          'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING');
    }
    expect(TransactionDetailsPresentation.heading('RETURNED', 'RECEIVED', ''),
        'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING');
  });

  test('partial loss, damage and transit distinguish reported and confirmed',
      () {
    for (final entry in [
      ['LOSS', 'STOCK_LOSS', 'INVENTORY_DETAILS_CONFIRMED_LOST'],
      ['DAMAGED', 'STOCK_DAMAGE', 'INVENTORY_DETAILS_CONFIRMED_DAMAGED'],
      ['RETURNED', 'IN_TRANSIT', 'INVENTORY_DETAILS_CONFIRMED_IN_TRANSIT'],
    ]) {
      final display = TransactionDetailsPresentation([
        entry[0],
        entry[1],
        entry[1],
        '20',
        '10',
        '20',
        'original',
        'ACCEPTED',
      ]);
      expect(display.primaryLabel, 'INVENTORY_DETAILS_SHORTFALL_REPORTED');
      expect(display.confirmedLabel, entry[2]);
      expect(display.confirmedQuantity, 10);
      expect(display.difference, 10);
      expect(display.differenceLabel, 'INVENTORY_DETAILS_REMAINING_SHORTFALL');
    }
  });

  test('full write-off zero sentinel is not the confirmed write-off quantity',
      () {
    for (final type in ['LOSS', 'DAMAGED']) {
      final display = TransactionDetailsPresentation([
        type,
        '',
        'STOCK_LOSS',
        null,
        '0',
        '20',
        'original',
        'ACCEPTED',
      ]);
      expect(display.confirmedQuantity, 20);
      expect(display.difference, isNull);
    }
  });

  test('zero and missing quantities remain distinct', () {
    final zero = TransactionDetailsPresentation([
      'ISSUED',
      'RECEIVED',
      'STOCK_LOSS',
      '120',
      '0',
      '120',
      null,
      'ACCEPTED',
    ]);
    expect(zero.primaryLabel, 'APPONE_INVENTORY_QUANTITY_SENT_LABEL');
    expect(zero.confirmedLabel, 'INVENTORY_DETAILS_QUANTITY_RECEIVED');
    expect(zero.confirmedQuantity, 0);
    expect(zero.difference, 120);
    expect(zero.differenceLabel, 'INVENTORY_DETAILS_NOT_RECEIVED');
    final missing = TransactionDetailsPresentation(['ISSUED']);
    expect(missing.confirmedQuantity, isNull);
    expect(missing.difference, isNull);
    final pending = TransactionDetailsPresentation([
      'RETURNED',
      'RETURNED',
      'IN_TRANSIT',
      null,
      null,
      60,
      'original',
      'IN_TRANSIT',
    ]);
    expect(pending.confirmedQuantity, isNull);
  });
  test(
      'returned in-transit resolution without a top-level reason is not a receipt',
      () {
    final display = TransactionDetailsPresentation([
      'RETURNED',
      null,
      'IN_TRANSIT',
      '70',
      '30',
      '70',
      'original',
      'ACCEPTED',
    ]);
    expect(display.primaryLabel, 'INVENTORY_DETAILS_SHORTFALL_REPORTED');
    expect(display.confirmedLabel, 'INVENTORY_DETAILS_CONFIRMED_IN_TRANSIT');
    expect(display.confirmedQuantity, 30);
    expect(display.difference, 40);
  });

  test('lower partial acceptance of a reissue still shows quantity received',
      () {
    final display = TransactionDetailsPresentation([
      'ISSUED',
      'RECEIVED',
      'IN_TRANSIT',
      '70',
      '30',
      '70',
      'original',
      'ACCEPTED',
    ]);
    expect(display.confirmedLabel, 'INVENTORY_DETAILS_QUANTITY_RECEIVED');
    expect(display.confirmedQuantity, 30);
    expect(display.differenceLabel, 'INVENTORY_DETAILS_NOT_RECEIVED');
  });

  test('linked shortfall labels follow the discrepancy even before retagging',
      () {
    for (final entry in [
      ['STOCK_LOSS', 'INVENTORY_DETAILS_CONFIRMED_LOST'],
      ['STOCK_DAMAGE', 'INVENTORY_DETAILS_CONFIRMED_DAMAGED'],
      ['IN_TRANSIT', 'INVENTORY_DETAILS_CONFIRMED_IN_TRANSIT'],
      ['', 'INVENTORY_DETAILS_QUANTITY_CONFIRMED'],
    ]) {
      final display = TransactionDetailsPresentation([
        'RETURNED',
        'RETURNED',
        entry[0],
        '70',
        '30',
        '70',
        'original',
        'ACCEPTED',
      ]);
      expect(display.confirmedLabel, entry[1]);
    }
  });
}
