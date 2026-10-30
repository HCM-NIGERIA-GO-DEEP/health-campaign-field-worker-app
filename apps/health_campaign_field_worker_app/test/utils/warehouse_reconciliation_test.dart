import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/inventory_reports.dart';
import 'package:health_campaign_field_worker_app/utils/stock_calculation_utils.dart';

void main() {
  StockModel stock(String id, String type, String quantity,
      {String sender = 'upper',
      String receiver = 'lower',
      String transactionType = 'DISPATCHED',
      List<AdditionalField> extra = const []}) {
    return StockModel(
      clientReferenceId: id,
      productVariantId: 'bednet',
      senderId: sender,
      receiverId: receiver,
      transactionType: transactionType,
      quantity: quantity,
      additionalFields: StockAdditionalFields(version: 1, fields: [
        AdditionalField('stockEntryType', type),
        const AdditionalField('status', 'ACCEPTED'),
        ...extra,
      ]),
    );
  }

  test('PDF shortfalls remain auditable without reducing warehouse stock twice',
      () {
    final stocks = [
      stock('receipt', 'RECEIPT', '500',
          sender: 'national', receiver: 'upper', transactionType: 'RECEIVED'),
      stock('loss-dispatch', 'ISSUED', '120'),
      stock('damage-dispatch', 'ISSUED', '240'),
      stock('loss-shortfall', 'LOSS', '20',
          sender: 'lower',
          receiver: 'upper',
          extra: [
            const AdditionalField('discrepancyReason', 'STOCK_LOSS'),
            const AdditionalField(
                'originalIssueClientReferenceId', 'loss-dispatch'),
            const AdditionalField('originalQuantityReceived', '20'),
            const AdditionalField('actualQuantityReceived', '10'),
          ]),
      stock('damage-shortfall', 'DAMAGED', '40',
          sender: 'lower',
          receiver: 'upper',
          extra: [
            const AdditionalField('discrepancyReason', 'STOCK_DAMAGE'),
            const AdditionalField(
                'originalIssueClientReferenceId', 'damage-dispatch'),
            const AdditionalField('originalQuantityReceived', '40'),
            const AdditionalField('actualQuantityReceived', '20'),
          ]),
    ];
    Map<String, double> metrics() =>
        StockCalculationUtils.calculateStockMetrics(
            stockList: stocks, facilityId: 'upper', productId: 'bednet');
    double own(Map<String, double> values, String total, String lower) =>
        StockCalculationUtils.warehouseWriteOffQuantity(
            values[total], values[lower]);

    final lowerOnly = metrics();
    expect(lowerOnly['stockLost'], 10);
    expect(lowerOnly['stockDamaged'], 20);
    expect(own(lowerOnly, 'stockLost', 'lowerFacilityLostShortfall'), 0);
    expect(own(lowerOnly, 'stockDamaged', 'lowerFacilityDamagedShortfall'), 0);
    expect(lowerOnly['stockInHand'], 140);

    stocks.addAll(
        [stock('own-loss', 'LOSS', '3'), stock('own-damage', 'DAMAGED', '2')]);
    final mixed = metrics();
    final lost = own(mixed, 'stockLost', 'lowerFacilityLostShortfall');
    final damaged = own(mixed, 'stockDamaged', 'lowerFacilityDamagedShortfall');
    expect(lost, 3);
    expect(damaged, 2);
    expect(mixed['stockLost'], 13);
    expect(mixed['stockDamaged'], 22);
    expect(mixed['stockInHand'], 135);
    // The numbers now shown on reconciliation explain the physical balance.
    expect(mixed['stockReceived']! - mixed['stockIssued']! - lost - damaged,
        mixed['stockInHand']);
  });

  test('historical snapshots without lower-facility offsets keep their totals',
      () {
    expect(StockCalculationUtils.warehouseWriteOffQuantity('7', null), 7);
    expect(StockCalculationUtils.warehouseWriteOffQuantity('7', ''), 7);
    expect(StockCalculationUtils.warehouseWriteOffQuantity('7.5', '2'), 5.5);
    expect(StockCalculationUtils.warehouseWriteOffQuantity(null, null), 0);
  });

  test(
      'warehouse report keeps balance rows and adds informational shortfalls',
      () {
    Map<String, dynamic> table(String name) {
      final flow = (inventoryReportFlows['flows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => (f['body'] as List? ?? [])
              .any((body) => body['fieldName'] == name));
      return (flow['body'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((body) => body['fieldName'] == name);
    }

    final warehouse = table('tableInfoReckonReportDetails');
    final columns = ((warehouse['data'] as Map)['columns'] as List)
        .cast<Map<String, dynamic>>();
    expect(
        columns.where(
            (c) => c['header'] == 'STOCK_RECONCILIATION_WAREHOUSE_STOCK_LOST'),
        hasLength(1));
    expect(
        columns.where((c) =>
            c['header'] == 'STOCK_RECONCILIATION_WAREHOUSE_STOCK_DAMAGED'),
        hasLength(1));
    expect(
        columns.where((c) => c['header'].toString().contains('_LOWER_LABEL')),
        isEmpty);
    final loss = columns.firstWhere(
        (c) => c['header'] == 'STOCK_RECONCILIATION_WAREHOUSE_STOCK_LOST');
    expect(loss['cellValue'], contains('getWarehouseWriteOffQuantity'));
    expect(loss['cellValue'], contains('lowerFacilityLostShortfall'));
    for (final suffix in ['LOST', 'DAMAGED']) {
      expect(
          columns.where((column) =>
              column['header'] ==
              'STOCK_RECONCILIATION_REPORTED_SHORTFALL_$suffix'),
          hasLength(1));
    }
    final models = jsonConfig['stockReconciliation']!['models'] as Map;
    final mappings = (models['StockReconciliationModel'] as Map)['mappings'] as Map;
    final fields = mappings['additionalFields'] as Map;
    expect(fields['reportedLostShortfall'],
        'stockRecon.stockReconciliationCard.stockMetrics.reportedLostShortfall');
    expect(fields['reportedDamagedShortfall'],
        'stockRecon.stockReconciliationCard.stockMetrics.reportedDamagedShortfall');

    final distributor = table('distributorTableInfoReckonReportDetails');
    final distributorColumns = ((distributor['data'] as Map)['columns'] as List)
        .cast<Map<String, dynamic>>();
    expect(
        distributorColumns.firstWhere((c) =>
            c['header'] ==
            'STOCKRECON_REPORT_DETAILS_TABLE_HEADER_5_LABEL')['cellValue'],
        '{{item.additionalFields.fields.stockLost}}');
  });
  test(
      'reported 70-unit shortfall is visible on both sides without a second deduction',
      () {
    final receipt = stock('receipt', 'ISSUED', '100', extra: [
      const AdditionalField('originalQuantityReceived', '100'),
      const AdditionalField('actualQuantityReceived', '30'),
      const AdditionalField('discrepancyReason', 'STOCK_LOSS'),
    ]);
    final shortfall = stock('shortfall', 'LOSS', '70',
        sender: 'lower',
        receiver: 'upper',
        extra: [
          const AdditionalField('actualQuantityReceived', '0'),
          const AdditionalField('discrepancyReason', 'STOCK_LOSS'),
          const AdditionalField('originalIssueClientReferenceId', 'receipt'),
        ]);
    final rows = [receipt, shortfall];
    final lower = StockCalculationUtils.calculateStockMetrics(
        stockList: rows, facilityId: 'lower', productId: 'bednet');
    final upper = StockCalculationUtils.calculateStockMetrics(
        stockList: rows, facilityId: 'upper', productId: 'bednet');
    expect(lower['reportedLostShortfall'], 70);
    expect(lower['stockReceived'], 30);
    expect(lower['stockInHand'], 30);
    expect(lower['stockLost'], 0);
    expect(upper['reportedLostShortfall'], 70);
    expect(upper['lowerFacilityLostShortfall'], 70);
    expect(upper['stockIssued'], 100);
    expect(upper['stockInHand'], -100);
    expect(
        StockCalculationUtils.warehouseWriteOffQuantity(
            upper['stockLost'], upper['lowerFacilityLostShortfall']),
        0);
  });

  test(
      'partial and pending shortfall confirmations do not inflate reported totals',
      () {
    final resolved = stock('damage', 'DAMAGED', '70',
        sender: 'lower',
        receiver: 'upper',
        extra: [
          const AdditionalField('originalQuantityReceived', '70'),
          const AdditionalField('actualQuantityReceived', '20'),
          const AdditionalField('discrepancyReason', 'STOCK_DAMAGE'),
          const AdditionalField('originalIssueClientReferenceId', 'receipt'),
        ]);
    final pending = resolved.copyWith(
        clientReferenceId: 'pending',
        additionalFields: StockAdditionalFields(version: 1, fields: [
          const AdditionalField('stockEntryType', 'RETURNED'),
          const AdditionalField('status', 'IN_TRANSIT'),
          const AdditionalField('discrepancyReason', 'STOCK_DAMAGE'),
          const AdditionalField(
              'originalIssueClientReferenceId', 'other-receipt'),
        ]));
    final metrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [resolved, pending],
        facilityId: 'lower',
        productId: 'bednet');
    expect(metrics['reportedDamagedShortfall'], 20);
    expect(metrics['reportedLostShortfall'], 0);
    expect(metrics['stockInHand'], 0);
    final scaled = StockCalculationUtils.calculateStockMetrics(
        stockList: [resolved],
        facilityId: 'lower',
        productId: 'bednet',
        multiplier: 30);
    expect(scaled['reportedDamagedShortfall'], 600);
  });
}
