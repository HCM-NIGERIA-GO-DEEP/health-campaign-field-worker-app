import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/stock_calculation_utils.dart';
import 'package:health_campaign_field_worker_app/utils/transaction_details_presentation.dart';

void main() {
  setUpAll(() {
    StockModelMapper.ensureInitialized();
    StockAdditionalFieldsMapper.ensureInitialized();
    AdditionalFieldMapper.ensureInitialized();
    AuditDetailsMapper.ensureInitialized();
    ClientAuditDetailsMapper.ensureInitialized();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });
  dynamic field(StockModel row, String key) => row.additionalFields?.fields
      .where((f) => f.key == key)
      .firstOrNull
      ?.value;
  StockModel row(String id, String type, int quantity,
          {String sender = 'district',
          String receiver = 'phu',
          String status = 'ACCEPTED',
          String? reason,
          String? parent,
          int? original,
          int? actual,
          String discrepancy = 'IN_TRANSIT'}) =>
      StockModel(
          clientReferenceId: id,
          productVariantId: 'bednet',
          senderId: sender,
          receiverId: receiver,
          transactionType: 'DISPATCHED',
          transactionReason: reason,
          quantity: '$quantity',
          additionalFields: StockAdditionalFields(version: 1, fields: [
            AdditionalField('stockEntryType', type),
            AdditionalField('status', status),
            AdditionalField('discrepancyReason', discrepancy),
            if (parent != null)
              AdditionalField('originalIssueClientReferenceId', parent),
            if (original != null)
              AdditionalField('originalQuantityReceived', '$original'),
            if (actual != null)
              AdditionalField('actualQuantityReceived', '$actual'),
          ]));
  TransactionDetailsPresentation view(StockModel stock, String viewer) =>
      TransactionDetailsPresentation.fromStock(stock, viewerId: viewer);

  test(
      '600/400 original dispatch has party-specific quantities and destination wording',
      () {
    final original = row('original', 'ISSUED', 600,
        original: 600, actual: 400, reason: 'RECEIVED');
    expect(view(original, 'district').listQuantity, 600);
    expect(view(original, 'phu').listQuantity, 400);
    expect(view(original, 'district').confirmedLabel,
        'INVENTORY_DETAILS_ACCEPTED_BY_DESTINATION');
    expect(view(original, 'phu').confirmedLabel,
        'INVENTORY_DETAILS_QUANTITY_RECEIVED');
  });
  test(
      'legacy inherited accepted values cannot replace a pending shortfall or reissue quantity',
      () {
    final shortfall = row('shortfall', 'RETURNED', 200,
        sender: 'phu',
        receiver: 'district',
        status: 'IN_TRANSIT',
        parent: 'original',
        actual: 400);
    expect(view(shortfall, 'district').listQuantity, 200);
    expect(view(shortfall, 'phu').listQuantity, 200);
    expect(view(shortfall, 'district').confirmedQuantity, isNull);
    for (final quantity in [150, 50]) {
      final reissue = row('reissue-$quantity', 'ISSUED', quantity,
          parent: 'shortfall', actual: 150, status: 'IN_TRANSIT');
      expect(view(reissue, 'district').listQuantity, quantity);
      expect(view(reissue, 'phu').listQuantity, quantity);
      expect(view(reissue, 'district').confirmedQuantity, isNull);
    }
  });
  test('new 150 and 50 reissues never inherit parent acceptance form values',
      () {
    for (final quantity in [150, 50]) {
      final config = jsonConfig['shortfallTransaction']!;
      final model = FormEntityMapper(config: jsonConfig)
          .mapFormToEntities(
            formValues: {
              'actualQuantityReceived': '150',
              'originalQuantityReceived': '200',
              'rejectComment': 'parent comment'
            },
            modelsConfig: config['models'] as Map<String, dynamic>,
            fallbackFormDataString: config['fallbackModel'] as String?,
            context: {
              'stockEntryType': 'ISSUED',
              'quantity': '$quantity',
              'senderFacilityId': 'district',
              'receiverFacilityId': 'phu',
              'productVariantId': 'bednet',
              'projectId': 'campaign',
              'tenantId': 'si',
              'userUUID': 'user',
              'mrnNumber': 'mrn-$quantity',
              'originalIssueClientReferenceId': 'shortfall',
              'discrepancyReason': 'IN_TRANSIT'
            },
          )
          .whereType<StockModel>()
          .single;
      expect(model.quantity, '$quantity');
      expect(field(model, 'actualQuantityReceived'), isNull);
      expect(field(model, 'originalQuantityReceived'), isNull);
      expect(field(model, 'partial_flow'), isTrue);
    }
  });
  test('normal issue, receipt and return carry a boolean false partial_flow',
      () {
    for (final type in ['ISSUED', 'RECEIPT', 'RETURNED']) {
      final config = jsonConfig['stock']!;
      final model = FormEntityMapper(config: jsonConfig)
          .mapFormToEntities(
            formValues: {
              'warehouseDetails': {'facilityToWhich': 'phu'},
              'stockDetails': {
                'facilityFromWhich': 'district',
                'productdetail': {'id': 'bednet'}
              },
              'stockProductDetails': {
                'quantitySent': 600,
                'quantityReceived': 600,
                'quantityReturned': 600
              }
            },
            modelsConfig: config['models'] as Map<String, dynamic>,
            fallbackFormDataString: config['fallbackModel'] as String?,
            context: {
              'stockEntryType': type,
              'transactionType': type == 'RECEIPT' ? 'RECEIVED' : 'DISPATCHED',
              'senderPartyType': 'WAREHOUSE',
              'receiverPartyType': 'WAREHOUSE',
              'tenantId': 'si',
              'userUUID': 'user',
              'projectId': 'campaign'
            },
          )
          .whereType<StockModel>()
          .single;
      expect(field(model, 'partial_flow'), isFalse);
    }
  });
  test(
      'in-transit and loss reissue receipts credit 100 and 30 without another sender deduction',
      () {
    final rows = [
      row('original', 'ISSUED', 600,
          original: 600, actual: 400, reason: 'RECEIVED'),
      row('shortfall', 'RETURNED', 200,
          sender: 'phu',
          receiver: 'district',
          parent: 'original',
          original: 200,
          actual: 150,
          reason: 'IN_TRANSIT'),
      row('reissue-150', 'ISSUED', 150,
          parent: 'shortfall', original: 150, actual: 100, reason: 'RECEIVED'),
      row('reissue-50', 'ISSUED', 50,
          parent: 'shortfall',
          original: 50,
          actual: 30,
          reason: 'RECEIVED',
          discrepancy: 'STOCK_LOSS'),
      row('shortfall-50', 'RETURNED', 50,
          sender: 'phu',
          receiver: 'district',
          parent: 'reissue-150',
          status: 'IN_TRANSIT'),
      row('shortfall-20', 'RETURNED', 20,
          sender: 'phu',
          receiver: 'district',
          parent: 'reissue-50',
          status: 'IN_TRANSIT',
          discrepancy: 'STOCK_LOSS'),
    ];
    final phu = StockCalculationUtils.calculateStockMetrics(
        stockList: rows, facilityId: 'phu', productId: 'bednet');
    expect(phu['stockReceived'], 530);
    expect(phu['stockLost'], 0);
    expect(phu['stockInHand'], 530);
    final district = StockCalculationUtils.calculateStockMetrics(
        stockList: rows, facilityId: 'district', productId: 'bednet');
    expect(district['stockIssued'], 600);
    expect(district['stockInHand'], -600);
  });
  test('acknowledgement details discard the success route and detail Back pops',
      () {
    final flows =
        (sampleInventoryFlows['flows'] as List).cast<Map<String, dynamic>>();
    final success = flows.firstWhere((f) => f['name'] == 'stockSuccess');
    final props =
        success['body'][0]['primaryAction']['onAction'][0]['properties'];
    expect(props['navigationMode'], 'popUntilAndPush');
    expect(props['popUntilPageName'], 'manageStock');
    final details =
        flows.firstWhere((f) => f['name'] == 'viewTransactionDetails');
    expect(
        details['header'][0]['onAction'][0]['actionType'], 'BACK_NAVIGATION');
  });
  test('transient receipts retain the boolean partial-flow classification', () {
    for (final partial in [true, false]) {
      final config = jsonConfig['stockReceipt']!;
      final model = FormEntityMapper(config: jsonConfig)
          .mapFormToEntities(
            formValues: {'stockReceiptDetails': <String, dynamic>{}},
            modelsConfig: config['models'] as Map<String, dynamic>,
            fallbackFormDataString: config['fallbackModel'] as String?,
            context: {
              'stockEntryType': 'RECEIPT',
              'transactionType': 'RECEIVED',
              'quantity': '100',
              'productVariantId': 'bednet',
              'userFacilityId': 'phu',
              'senderFacilityId': 'district',
              'tenantId': 'si',
              'projectId': 'campaign',
              'userUUID': 'user',
              'partial_flow': partial
            },
          )
          .whereType<StockModel>()
          .single;
      expect(field(model, 'partial_flow'), partial);
    }
  });
  test(
      'list quantity labels are localized separately and incoming comment locking is handled at runtime',
      () {
    final flows =
        (sampleInventoryFlows['flows'] as List).cast<Map<String, dynamic>>();
    final view = flows.firstWhere((f) => f['name'] == 'viewTransaction');
    final group = view['body'][1]['child']['children'][2]['child'];
    expect(group['format'], 'labelPairList');
    expect(
        group['data'][0]['key'], contains('getViewTransactionQuantityLabel'));
    expect(group['data'][0]['value'],
        contains('getViewTransactionQuantity(item)'));
    final receipt = flows.firstWhere((f) => f['name'] == 'stockReceiptDetails');
    final comment = (receipt['pages'][0]['properties'] as List)
        .firstWhere((f) => f['fieldName'] == 'comment');
    expect(comment['readOnly'], false);
    expect(comment['value'], '{{navigation.originalComment}}');
  });

  test(
      'legacy retagged in-transit confirmation is not received into the upper warehouse',
      () {
    final notice = row('notice', 'ISSUED', 200,
        sender: 'phu',
        receiver: 'district',
        parent: 'original',
        original: 200,
        actual: 150,
        reason: 'IN_TRANSIT');
    final metrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [notice], facilityId: 'district', productId: 'bednet');
    expect(metrics['stockReceived'], 0);
    expect(metrics['stockInHand'], 0);
    expect(view(notice, 'district').confirmedLabel,
        'INVENTORY_DETAILS_CONFIRMED_IN_TRANSIT');
  });
  test(
      'server omission of transactionReason does not turn a physical reissue receipt into a notice',
      () {
    final receipt = row('reissue', 'ISSUED', 150,
        parent: 'shortfall', original: 150, actual: 100);
    expect(view(receipt, 'phu').listQuantity, 100);
    expect(view(receipt, 'phu').confirmedLabel,
        'INVENTORY_DETAILS_QUANTITY_RECEIVED');
    expect(view(receipt, 'district').listQuantity, 150);
    expect(view(receipt, 'district').confirmedLabel,
        'INVENTORY_DETAILS_ACCEPTED_BY_DESTINATION');
  });
}
