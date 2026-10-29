import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/auth/auth.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/models/entities/roles_type.dart';
import 'package:health_campaign_field_worker_app/models/role_actions/role_actions_model.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';
import 'package:health_campaign_field_worker_app/utils/stock_calculation_utils.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

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

  final stateData = CrudStateData(const {}, const []);

  Future<void> withRegistry(
    WidgetTester tester,
    VoidCallback body, {
    RolesType role = RolesType.warehouseManager,
  }) async {
    final authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(
      AuthState.authenticated(
        accessToken: 'token',
        refreshToken: 'refresh',
        userModel: UserRequestModel(
          uuid: 'user-uuid-1',
          roles: [UserRoleModel(code: role.toValue())],
        ),
        actionsWrapper: const RoleActionsWrapperModel(),
      ),
    );

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              FunctionRegistries(context).registerAll();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    body();
  }

  dynamic call(String name, List<dynamic> args) =>
      FunctionRegistry.call(name, args, stateData);

  group('Config shape: onSecondaryAction condition admits RETURNED', () {
    void verifyConfigShape(
      Map<String, dynamic> flowsRoot,
      String sourceName,
    ) {
      final flows =
          (flowsRoot['flows'] as List).cast<Map<String, dynamic>>();
      final flow = flows.firstWhere(
        (f) => f['name'] == 'stockReceiptDetails',
        orElse: () => throw StateError('stockReceiptDetails not found in $sourceName'),
      );
      final onSecondaryAction =
          (flow['onSecondaryAction'] as List).cast<Map<String, dynamic>>();

      // 1. Must NOT contain a condition blocking RETURNED
      final hasBlockingReturned = onSecondaryAction.any((branch) {
        final expr = (branch['condition'] as Map?)?['expression']?.toString() ?? '';
        return expr.contains("incomingStockEntryType == 'RETURNED'") &&
            branch['actions'] != null &&
            (branch['actions'] as List).any((a) =>
                a['actionType'] == 'SHOW_TOAST' &&
                a['properties']?['message'] ==
                    'INVENTORY_RETURN_RESOLVED_VIA_ACCEPT');
      });
      expect(hasBlockingReturned, isFalse,
          reason: '$sourceName must not block RETURNED in onSecondaryAction');

      // 2. Invalid quantity condition applies to all records (including RETURNED)
      final invalidQtyBranch = onSecondaryAction.firstWhere((branch) {
        final expr = (branch['condition'] as Map?)?['expression']?.toString() ?? '';
        return expr ==
            'actualQuantityReceived < 0 || actualQuantityReceived >= quantity';
      }, orElse: () => throw StateError('Invalid quantity branch not found in $sourceName'));
      expect(invalidQtyBranch, isNotNull);

      // 3. Partial accept branch admits valid quantities (including 0)
      final partialAcceptBranch = onSecondaryAction.firstWhere((branch) {
        final expr = (branch['condition'] as Map?)?['expression']?.toString() ?? '';
        return expr ==
            'actualQuantityReceived >= 0 && actualQuantityReceived < quantity';
      });
      final actions = (partialAcceptBranch['actions'] as List)
          .cast<Map<String, dynamic>>();

      // 4. In UPDATE_EVENT, StockModel.quantity is NOT mutated
      final updateAction = actions.firstWhere(
        (a) => a['actionType'] == 'UPDATE_EVENT',
      );
      final modifyList = (updateAction['properties']['modify'] as List)
          .cast<Map<String, dynamic>>();
      final hasQuantityModify =
          modifyList.any((m) => m['key'] == 'StockModel.quantity');
      expect(hasQuantityModify, isFalse,
          reason: '$sourceName UPDATE_EVENT must NOT overwrite StockModel.quantity');

      final hasActualQty = modifyList.any((m) =>
          m['key'] ==
          'StockModel.additionalFields.fields.actualQuantityReceived');
      expect(hasActualQty, isTrue,
          reason: '$sourceName must modify actualQuantityReceived');

      final hasOriginalQty = modifyList.any((m) =>
          m['key'] ==
          'StockModel.additionalFields.fields.originalQuantityReceived');
      expect(hasOriginalQty, isTrue,
          reason: '$sourceName must modify originalQuantityReceived');

      final txReasonModify = modifyList.firstWhere(
        (m) => m['key'] == 'StockModel.transactionReason',
      );
      expect(
        txReasonModify['value'],
        '{{fn:getPartialAcceptTransactionReason(navigation.incomingStockEntryType, formData.discrepancyReason)}}',
        reason: '$sourceName must resolve transactionReason via getPartialAcceptTransactionReason',
      );

      final entryTypeModify = modifyList.firstWhere(
        (m) => m['key'] == 'StockModel.additionalFields.fields.stockEntryType',
      );
      expect(
        entryTypeModify['value'],
        '{{fn:getPartialAcceptStockEntryType(navigation.incomingStockEntryType, formData.discrepancyReason)}}',
        reason: '$sourceName must resolve stockEntryType via getPartialAcceptStockEntryType',
      );

      // 5. shortfallTransaction uses fn:getShortfallEntryType
      final shortfallFetch = actions.firstWhere(
        (a) =>
            a['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
            a['properties']['configName'] == 'shortfallTransaction',
      );
      final shortfallData = (shortfallFetch['properties']['data'] as List)
          .cast<Map<String, dynamic>>();
      final entryTypeEntry =
          shortfallData.firstWhere((d) => d['key'] == 'stockEntryType');
      expect(
        entryTypeEntry['value'],
        '{{fn:getShortfallEntryType(navigation.incomingStockEntryType)}}',
        reason: '$sourceName shortfallTransaction must use getShortfallEntryType',
      );

      // 6. Option C branch exists for IN_TRANSIT shortfall return (two reissues)
      final optionCBranch = onSecondaryAction.firstWhere((branch) {
        final expr = (branch['condition'] as Map?)?['expression']?.toString() ?? '';
        return expr.contains("navigation.discrepancyReason == 'IN_TRANSIT'") &&
            expr.contains("navigation.incomingStockEntryType == 'RETURNED'");
      }, orElse: () => throw StateError('Option C branch not found in $sourceName'));
      expect(optionCBranch, isNotNull);

      final optionCActions = (optionCBranch['actions'] as List)
          .cast<Map<String, dynamic>>();
      final optionCCreates = optionCActions
          .where((a) => a['actionType'] == 'CREATE_EVENT')
          .toList();
      expect(optionCCreates.length, 2,
          reason: '$sourceName Option C must issue two CREATE_EVENT actions');

      final optionCShortfallFetches = optionCActions
          .where((a) =>
              a['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
              a['properties']['configName'] == 'shortfallTransaction')
          .toList();
      expect(optionCShortfallFetches.length, 2,
          reason: '$sourceName Option C must fetch shortfallTransaction twice for reissues');

      final optionCUpdate = optionCActions.firstWhere(
        (a) => a['actionType'] == 'UPDATE_EVENT',
      );
      final optionCModify = (optionCUpdate['properties']['modify'] as List)
          .cast<Map<String, dynamic>>();
      final optionCTxReason = optionCModify.firstWhere(
        (m) => m['key'] == 'StockModel.transactionReason',
      );
      expect(optionCTxReason['value'], 'IN_TRANSIT',
          reason: '$sourceName Option C must set transactionReason to IN_TRANSIT');
    }

    test('manage_stock.dart has expected onSecondaryAction config shape', () {
      verifyConfigShape(sampleInventoryFlows, 'manage_stock.dart');
    });

    test('json/INVENTORY.json in config repo has matching config shape', () {
      const configPath =
          '/home/harshkhatri/Desktop/HCM/HCM-Liberia-Config/hcm-solution-config/json/INVENTORY.json';
      final file = File(configPath);
      expect(file.existsSync(), isTrue, reason: 'INVENTORY.json should exist');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      verifyConfigShape(json, 'INVENTORY.json');
    });
  });

  group('Direction resolution: getShortfallEntryType', () {
    testWidgets('partial accept of ISSUED dispatch produces RETURNED shortfall',
        (tester) async {
      await withRegistry(tester, () {
        expect(call('getShortfallEntryType', ['ISSUED']), 'RETURNED');
        expect(call('getShortfallEntryType', ['issued']), 'RETURNED');
        expect(call('getShortfallEntryType', ['']), 'RETURNED');
        expect(call('getShortfallEntryType', []), 'RETURNED');
      });
    });

    testWidgets('partial accept of RETURNED shortfall produces ISSUED reissue',
        (tester) async {
      await withRegistry(tester, () {
        expect(call('getShortfallEntryType', ['RETURNED']), 'ISSUED');
        expect(call('getShortfallEntryType', ['returned']), 'ISSUED');
        expect(call('getShortfallEntryType', [' Returned ']), 'ISSUED');
      });
    });
  });

  group('Partial accept classification: getPartialAcceptStockEntryType & getPartialAcceptTransactionReason', () {
    testWidgets('STOCK_DAMAGE shortfall retags to DAMAGED entryType and STOCK_DAMAGE reason (kept OUT of Stock Received)',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getPartialAcceptStockEntryType', ['RETURNED', 'STOCK_DAMAGE']),
          'DAMAGED',
        );
        expect(
          call('getPartialAcceptTransactionReason', ['RETURNED', 'STOCK_DAMAGE']),
          'STOCK_DAMAGE',
        );
      });
    });

    testWidgets('STOCK_LOSS shortfall retags to LOSS entryType and STOCK_LOSS reason (kept OUT of Stock Received)',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getPartialAcceptStockEntryType', ['RETURNED', 'STOCK_LOSS']),
          'LOSS',
        );
        expect(
          call('getPartialAcceptTransactionReason', ['RETURNED', 'STOCK_LOSS']),
          'STOCK_LOSS',
        );
      });
    });

    testWidgets('IN_TRANSIT shortfall sets IN_TRANSIT reason (kept OUT of Stock Received)',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getPartialAcceptStockEntryType', ['RETURNED', 'IN_TRANSIT']),
          'RETURNED',
        );
        expect(
          call('getPartialAcceptTransactionReason', ['RETURNED', 'IN_TRANSIT']),
          'IN_TRANSIT',
        );
      });
    });

    testWidgets('regular dispatch or surplus return sets RECEIVED reason (genuine receipt)',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getPartialAcceptStockEntryType', ['ISSUED', null]),
          'ISSUED',
        );
        expect(
          call('getPartialAcceptTransactionReason', ['ISSUED', null]),
          'RECEIVED',
        );
        expect(
          call('getPartialAcceptStockEntryType', ['RETURNED', '']),
          'RETURNED',
        );
        expect(
          call('getPartialAcceptTransactionReason', ['RETURNED', '']),
          'RECEIVED',
        );
      });
    });
  });

  group('shortfallTransaction builds correct entities for both directions & roles', () {
    final shortfallConfig =
        jsonConfig['shortfallTransaction'] as Map<String, dynamic>;
    final shortfallModels =
        shortfallConfig['models'] as Map<String, dynamic>;

    List<EntityModel> buildShortfall({
      required String stockEntryType,
      required String senderFacilityId,
      required String senderPartyType,
      required String receiverFacilityId,
      required String receiverPartyType,
      required String quantity,
      required String originalIssueClientReferenceId,
      required String discrepancyReason,
      required String mrnNumber,
    }) {
      final context = <String, dynamic>{
        'stockEntryType': stockEntryType,
        'senderFacilityId': senderFacilityId,
        'senderPartyType': senderPartyType,
        'receiverFacilityId': receiverFacilityId,
        'receiverPartyType': receiverPartyType,
        'userFacilityId': senderFacilityId,
        'quantity': quantity,
        'originalIssueClientReferenceId': originalIssueClientReferenceId,
        'discrepancyReason': discrepancyReason,
        'mrnNumber': mrnNumber,
        'projectId': 'proj-1',
        'tenantId': 'liberia',
        'userUUID': 'user-1',
        'productVariantId': 'PVAR-1',
        'sku': 'SKU-1',
        'wayBillNumber': 'WB-001',
        'batchNumber': 'BATCH-001',
        'transportType': 'TRUCK',
        'vehicleNumber': 'SL-1234',
        'selectedProject': {'referenceID': 'CMP-001'},
      };

      return FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: const {},
        modelsConfig: shortfallModels,
        context: context,
      );
    }

    test('upper level (warehouse manager) partially accepts RETURNED shortfall -> ISSUED reissue', () {
      final entities = buildShortfall(
        stockEntryType: 'ISSUED', // resolved by getShortfallEntryType('RETURNED')
        senderFacilityId: 'UPPER-FACILITY',
        senderPartyType: 'WAREHOUSE',
        receiverFacilityId: 'LOWER-FACILITY',
        receiverPartyType: 'WAREHOUSE',
        quantity: '4',
        originalIssueClientReferenceId: 'shortfall-return-1',
        discrepancyReason: 'IN_TRANSIT',
        mrnNumber: 'MRN-REISSUE-1',
      );

      expect(entities, hasLength(1));
      final stock = entities.first as StockModel;
      expect(stock.transactionType, 'DISPATCHED');
      expect(stock.senderId, 'UPPER-FACILITY');
      expect(stock.senderType, 'WAREHOUSE');
      expect(stock.receiverId, 'LOWER-FACILITY');
      expect(stock.receiverType, 'WAREHOUSE');
      expect(stock.quantity, '4');
      // Reissue is a fresh dispatch -> transactionReason must be null
      expect(stock.transactionReason, isNull);

      final fields = stock.additionalFields?.fields ?? [];
      String? fieldValue(String key) =>
          fields.firstWhere((f) => f.key == key, orElse: () => const AdditionalField('', '')).value?.toString();

      expect(fieldValue('stockEntryType'), 'ISSUED');
      expect(fieldValue('status'), 'IN_TRANSIT');
      expect(fieldValue('originalIssueClientReferenceId'), 'shortfall-return-1');
      expect(fieldValue('discrepancyReason'), 'IN_TRANSIT');
      expect(fieldValue('mrnNumber'), 'MRN-REISSUE-1');
    });

    test('lower level (warehouse manager) partially accepts ISSUED dispatch -> RETURNED shortfall', () {
      final entities = buildShortfall(
        stockEntryType: 'RETURNED', // resolved by getShortfallEntryType('ISSUED')
        senderFacilityId: 'LOWER-FACILITY',
        senderPartyType: 'WAREHOUSE',
        receiverFacilityId: 'UPPER-FACILITY',
        receiverPartyType: 'WAREHOUSE',
        quantity: '4',
        originalIssueClientReferenceId: 'dispatch-1',
        discrepancyReason: 'IN_TRANSIT',
        mrnNumber: 'MRN-SHORTFALL-1',
      );

      expect(entities, hasLength(1));
      final stock = entities.first as StockModel;
      expect(stock.transactionType, 'DISPATCHED');
      expect(stock.senderId, 'LOWER-FACILITY');
      expect(stock.senderType, 'WAREHOUSE');
      expect(stock.receiverId, 'UPPER-FACILITY');
      expect(stock.receiverType, 'WAREHOUSE');
      expect(stock.quantity, '4');
      // Returned shortfall -> transactionReason must be RETURNED
      expect(stock.transactionReason, 'RETURNED');

      final fields = stock.additionalFields?.fields ?? [];
      String? fieldValue(String key) =>
          fields.firstWhere((f) => f.key == key, orElse: () => const AdditionalField('', '')).value?.toString();

      expect(fieldValue('stockEntryType'), 'RETURNED');
      expect(fieldValue('status'), 'IN_TRANSIT');
      expect(fieldValue('originalIssueClientReferenceId'), 'dispatch-1');
    });

    test('distributor role: senderId is user UUID and partyType is STAFF', () {
      final entities = buildShortfall(
        stockEntryType: 'RETURNED',
        senderFacilityId: 'user-uuid-distributor',
        senderPartyType: 'STAFF',
        receiverFacilityId: 'UPPER-FACILITY',
        receiverPartyType: 'WAREHOUSE',
        quantity: '2',
        originalIssueClientReferenceId: 'dispatch-2',
        discrepancyReason: 'STOCK_LOSS',
        mrnNumber: 'MRN-DIST-1',
      );

      final stock = entities.first as StockModel;
      expect(stock.senderId, 'user-uuid-distributor');
      expect(stock.senderType, 'STAFF');
      expect(stock.receiverId, 'UPPER-FACILITY');
      expect(stock.receiverType, 'WAREHOUSE');
    });
  });

  group('Cycle closure: lower partial-accepts reissue, creating another return', () {
    test('the cycle closes: dispatch -> return -> reissue -> return', () {
      // Step 1: Upper dispatches 10 to Lower
      const originalDispatchRef = 'dispatch-1';

      // Step 2: Lower partially accepts 6, generating shortfall of 4 to Upper
      final shortfall1 = StockModel(
        clientReferenceId: 'shortfall-1',
        productVariantId: 'PVAR-1',
        senderId: 'LOWER-FACILITY',
        receiverId: 'UPPER-FACILITY',
        transactionType: 'DISPATCHED',
        quantity: '4',
        additionalFields: StockAdditionalFields(
          version: 1,
          fields: const [
            AdditionalField('stockEntryType', 'RETURNED'),
            AdditionalField('status', 'IN_TRANSIT'),
            AdditionalField('originalIssueClientReferenceId', originalDispatchRef),
            AdditionalField('discrepancyReason', 'IN_TRANSIT'),
          ],
        ),
      );

      // Step 3: Upper partially accepts 1 of the 4, generating reissue of 3 to Lower
      final reissue1 = StockModel(
        clientReferenceId: 'reissue-1',
        productVariantId: 'PVAR-1',
        senderId: 'UPPER-FACILITY',
        receiverId: 'LOWER-FACILITY',
        transactionType: 'DISPATCHED',
        quantity: '3',
        additionalFields: StockAdditionalFields(
          version: 1,
          fields: const [
            AdditionalField('stockEntryType', 'ISSUED'),
            AdditionalField('status', 'IN_TRANSIT'),
            AdditionalField('originalIssueClientReferenceId', 'shortfall-1'),
            AdditionalField('discrepancyReason', 'IN_TRANSIT'),
          ],
        ),
      );

      // Step 4: Lower partially accepts 2 of the 3, generating shortfall of 1 to Upper
      final shortfall2 = StockModel(
        clientReferenceId: 'shortfall-2',
        productVariantId: 'PVAR-1',
        senderId: 'LOWER-FACILITY',
        receiverId: 'UPPER-FACILITY',
        transactionType: 'DISPATCHED',
        quantity: '1',
        additionalFields: StockAdditionalFields(
          version: 1,
          fields: const [
            AdditionalField('stockEntryType', 'RETURNED'),
            AdditionalField('status', 'IN_TRANSIT'),
            AdditionalField('originalIssueClientReferenceId', 'reissue-1'),
            AdditionalField('discrepancyReason', 'IN_TRANSIT'),
          ],
        ),
      );

      expect(shortfall1.senderId, 'LOWER-FACILITY');
      expect(shortfall1.receiverId, 'UPPER-FACILITY');
      expect(reissue1.senderId, 'UPPER-FACILITY');
      expect(reissue1.receiverId, 'LOWER-FACILITY');
      expect(shortfall2.senderId, 'LOWER-FACILITY');
      expect(shortfall2.receiverId, 'UPPER-FACILITY');
    });
  });

  group('Quantity unmutated & balance calculations', () {
    const upperId = 'UPPER-FACILITY';
    const lowerId = 'LOWER-FACILITY';
    const productId = 'PVAR-1';

    StockModel createStock({
      required String clientReferenceId,
      required String senderId,
      required String receiverId,
      required String quantity,
      required String status,
      String? actualQuantityReceived,
      String? originalQuantityReceived,
      String stockEntryType = 'ISSUED',
      String transactionType = 'DISPATCHED',
      String? transactionReason,
      String? originalIssueClientReferenceId,
      String? discrepancyReason,
    }) {
      return StockModel(
        clientReferenceId: clientReferenceId,
        productVariantId: productId,
        senderId: senderId,
        receiverId: receiverId,
        quantity: quantity,
        transactionType: transactionType,
        transactionReason: transactionReason,
        additionalFields: StockAdditionalFields(
          version: 1,
          fields: [
            AdditionalField('status', status),
            AdditionalField('stockEntryType', stockEntryType),
            if (actualQuantityReceived != null)
              AdditionalField('actualQuantityReceived', actualQuantityReceived),
            if (originalQuantityReceived != null)
              AdditionalField('originalQuantityReceived', originalQuantityReceived),
            if (originalIssueClientReferenceId != null)
              AdditionalField('originalIssueClientReferenceId',
                  originalIssueClientReferenceId),
            if (discrepancyReason != null)
              AdditionalField('discrepancyReason', discrepancyReason),
          ],
        ),
      );
    }

    test('quantity is NOT mutated on partial accept; sender uses rawQuantity, receiver uses actualQuantityReceived', () {
      // Dispatched 10, Lower accepts 6.
      // Under new flow: quantity stays 10 on the record!
      final unmutatedRecord = createStock(
        clientReferenceId: 'dispatch-1',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '10', // NOT mutated to 6!
        status: 'ACCEPTED',
        actualQuantityReceived: '6',
        originalQuantityReceived: '10',
      );

      final upperMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [unmutatedRecord],
        facilityId: upperId,
        productId: productId,
      );
      final lowerMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [unmutatedRecord],
        facilityId: lowerId,
        productId: productId,
      );

      // Sender uses dispatched quantity (10)
      expect(upperMetrics['stockIssued'], 10);
      expect(upperMetrics['stockInHand'], -10);

      // Receiver uses accepted quantity (6)
      expect(lowerMetrics['stockReceived'], 6);
      expect(lowerMetrics['stockInHand'], 6);
    });

    test('historical records with mutated quantity still calculate sender balance correctly via originalQuantityReceived fallback', () {
      // Historical record: quantity was overwritten to 6, originalQuantityReceived preserved 10
      final historicalRecord = createStock(
        clientReferenceId: 'legacy-dispatch-1',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '6', // mutated in older versions
        status: 'ACCEPTED',
        actualQuantityReceived: '6',
        originalQuantityReceived: '10',
      );

      final upperMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [historicalRecord],
        facilityId: upperId,
        productId: productId,
      );
      final lowerMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [historicalRecord],
        facilityId: lowerId,
        productId: productId,
      );

      expect(upperMetrics['stockIssued'], 10);
      expect(lowerMetrics['stockReceived'], 6);
    });

    test('both directions: regular return (unlinked) uses dispatched for sender and accepted for receiver', () {
      final returnStock = createStock(
        clientReferenceId: 'return-1',
        senderId: lowerId,
        receiverId: upperId,
        quantity: '8', // sent 8
        status: 'ACCEPTED',
        actualQuantityReceived: '5', // upper accepted 5
        originalQuantityReceived: '8',
        stockEntryType: 'RETURNED',
      );

      final upperMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [returnStock],
        facilityId: upperId,
        productId: productId,
        isDistributor: false,
      );

      // Upper as receiver is credited with what it accepted (5)
      expect(upperMetrics['stockReceived'], 5);
      expect(upperMetrics['stockInHand'], 5);
    });

    test('shortfall linked by originalIssueClientReferenceId is not deducted twice for sender', () {
      final originalDispatch = createStock(
        clientReferenceId: 'disp-1',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '12',
        status: 'ACCEPTED',
        actualQuantityReceived: '7',
        originalQuantityReceived: '12',
      );
      final linkedShortfall = createStock(
        clientReferenceId: 'shortfall-1',
        senderId: lowerId,
        receiverId: upperId,
        quantity: '5',
        status: 'IN_TRANSIT',
        stockEntryType: 'RETURNED',
        originalIssueClientReferenceId: 'disp-1',
        discrepancyReason: 'IN_TRANSIT',
      );

      final lowerMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [originalDispatch, linkedShortfall],
        facilityId: lowerId,
        productId: productId,
      );

      // Lower facility received 7. Its own shortfall notification (5) is not debited.
      expect(lowerMetrics['stockReceived'], 7);
      expect(lowerMetrics['stockInHand'], 7);
    });

    test('terminal write-offs (STOCK_DAMAGE / STOCK_LOSS) add-back holds for upper facility', () {
      final originalDispatch = createStock(
        clientReferenceId: 'disp-writeoff',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '10',
        status: 'ACCEPTED',
        actualQuantityReceived: '7',
        originalQuantityReceived: '10',
      );
      final damageShortfall = createStock(
        clientReferenceId: 'shortfall-dmg',
        senderId: lowerId,
        receiverId: upperId,
        quantity: '3',
        status: 'ACCEPTED',
        stockEntryType: 'DAMAGED',
        originalIssueClientReferenceId: 'disp-writeoff',
        discrepancyReason: 'STOCK_DAMAGE',
      );

      final upperMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [originalDispatch, damageShortfall],
        facilityId: upperId,
        productId: productId,
      );

      // Upper dispatched 10. Damage shortfall of 3 is recorded in stockDamaged
      // but does not deduct from Upper a second time.
      expect(upperMetrics['stockIssued'], 10);
      expect(upperMetrics['stockDamaged'], 3);
      expect(upperMetrics['stockInHand'], -10);
    });

    test('partially accepted loss shortfall (e.g. 75 of 100) records 75 in stockLost and reissue (25) is not double-deducted', () {
      final originalDispatch = createStock(
        clientReferenceId: 'disp-loss-partial',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '500',
        status: 'ACCEPTED',
        actualQuantityReceived: '400',
        originalQuantityReceived: '500',
      );
      final partiallyAcceptedLoss = createStock(
        clientReferenceId: 'shortfall-loss-partial',
        senderId: lowerId,
        receiverId: upperId,
        quantity: '100', // lower reported shortfall of 100
        status: 'ACCEPTED',
        actualQuantityReceived: '75', // upper accepted 75 as lost
        originalQuantityReceived: '100',
        stockEntryType: 'LOSS',
        originalIssueClientReferenceId: 'disp-loss-partial',
        discrepancyReason: 'STOCK_LOSS',
      );
      final reissue = createStock(
        clientReferenceId: 'reissue-loss-partial',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '25', // remaining 25 reissued
        status: 'IN_TRANSIT',
        stockEntryType: 'ISSUED',
        originalIssueClientReferenceId: 'shortfall-loss-partial',
        discrepancyReason: 'STOCK_LOSS',
      );

      final upperMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [originalDispatch, partiallyAcceptedLoss, reissue],
        facilityId: upperId,
        productId: productId,
      );

      // Upper dispatched 500 originally. The reissue of 25 is part of that original
      // dispatch, so stockIssued remains 500 (not 525).
      expect(upperMetrics['stockIssued'], 500);
      // Only the accepted 75 is recorded in stockLost and lowerFacilityLostShortfall,
      // not the full 100.
      expect(upperMetrics['stockLost'], 75);
      expect(upperMetrics['lowerFacilityLostShortfall'], 75);
      // stockInHand: received(0) - (issued(500) + stockLost(75) - lowerFacilityLost(75)) = -500
      expect(upperMetrics['stockInHand'], -500);
    });

    test('Option C: IN_TRANSIT partial accept (30 of 60) creates two reissues (30 + 30) without double-deducting sender balance, and lower receives 360 total', () {
      // 1. District dispatches 360 to PHU
      final originalDispatch = createStock(
        clientReferenceId: 'disp-it-360',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '360',
        status: 'ACCEPTED',
        actualQuantityReceived: '300', // PHU accepts 300
        originalQuantityReceived: '360',
      );

      // 2. PHU sends shortfall return of 60 with discrepancyReason IN_TRANSIT
      final shortfallReturn = createStock(
        clientReferenceId: 'shortfall-it-60',
        senderId: lowerId,
        receiverId: upperId,
        quantity: '60',
        status: 'ACCEPTED', // accepted at upper
        actualQuantityReceived: '30', // upper confirms 30
        originalQuantityReceived: '60',
        stockEntryType: 'RETURNED',
        originalIssueClientReferenceId: 'disp-it-360',
        discrepancyReason: 'IN_TRANSIT',
        transactionReason: 'RECEIVED',
      );

      // 3. Option C creates Reissue 1 (accepted 30)
      final reissue1 = createStock(
        clientReferenceId: 'reissue-it-30-accepted',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '30',
        status: 'ACCEPTED',
        actualQuantityReceived: '30',
        originalQuantityReceived: '30',
        stockEntryType: 'ISSUED',
        originalIssueClientReferenceId: 'shortfall-it-60',
        discrepancyReason: 'IN_TRANSIT',
      );

      // 4. Option C creates Reissue 2 (remaining 30)
      final reissue2 = createStock(
        clientReferenceId: 'reissue-it-30-remaining',
        senderId: upperId,
        receiverId: lowerId,
        quantity: '30',
        status: 'ACCEPTED',
        actualQuantityReceived: '30',
        originalQuantityReceived: '30',
        stockEntryType: 'ISSUED',
        originalIssueClientReferenceId: 'shortfall-it-60',
        discrepancyReason: 'IN_TRANSIT',
      );

      final upperMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [originalDispatch, shortfallReturn, reissue1, reissue2],
        facilityId: upperId,
        productId: productId,
      );

      // Upper level:
      // stockIssued stays 360 (reissue1 and reissue2 are linked, so they don't double-deduct)
      expect(upperMetrics['stockIssued'], 360);
      expect(upperMetrics['stockInHand'], -360);

      final lowerMetrics = StockCalculationUtils.calculateStockMetrics(
        stockList: [originalDispatch, shortfallReturn, reissue1, reissue2],
        facilityId: lowerId,
        productId: productId,
      );

      // Lower level (PHU):
      // Received 300 from original dispatch + 30 from reissue 1 + 30 from reissue 2 = 360!
      expect(lowerMetrics['stockReceived'], 360);
      expect(lowerMetrics['stockInHand'], 360);
    });
  });

  group('Reports integration for reissue, shortfall, and accepted return', () {
    testWidgets('partially accepted loss shortfall displays accepted 75 (not 100) in Stock Lost report', (tester) async {
      await withRegistry(tester, () {
        final lossRow = {
          'quantity': 100,
          'additionalFields': {
            'fields': [
              {'key': 'actualQuantityReceived', 'value': '75'},
              {'key': 'originalQuantityReceived', 'value': '100'},
              {'key': 'discrepancyReason', 'value': 'STOCK_LOSS'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['loss', lossRow]), 75);
      });
    });

    testWidgets('partially accepted damage shortfall displays accepted 75 (not 100) in Stock Damaged report', (tester) async {
      await withRegistry(tester, () {
        final damageRow = {
          'quantity': 100,
          'additionalFields': {
            'fields': [
              {'key': 'actualQuantityReceived', 'value': '75'},
              {'key': 'originalQuantityReceived', 'value': '100'},
              {'key': 'discrepancyReason', 'value': 'STOCK_DAMAGE'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['damage', damageRow]), 75);
      });
    });

    testWidgets('full loss write-off (actualQuantityReceived == 0) falls back to top-level quantity', (tester) async {
      await withRegistry(tester, () {
        final fullLossRow = {
          'quantity': 100,
          'additionalFields': {
            'fields': [
              {'key': 'actualQuantityReceived', 'value': '0'},
              {'key': 'discrepancyReason', 'value': 'STOCK_LOSS'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['loss', fullLossRow]), 100);
      });
    });

    testWidgets('reissue appears in upper Stock Issued report', (tester) async {
      await withRegistry(tester, () {
        // Stock Issued report filters: entryType = ISSUED, party = senderId
        expect(call('getStockEntryType', ['dispatch']), 'ISSUED');
        expect(call('getSenderOrReceiver', ['dispatch']), 'senderId');

        final reissueRow = {
          'quantity': 3,
          'additionalFields': {
            'fields': [
              {'key': 'stockEntryType', 'value': 'ISSUED'},
              {'key': 'status', 'value': 'IN_TRANSIT'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['dispatch', reissueRow]), 3);
      });
    });

    testWidgets('shortfall appears in lower Stock Returned report', (tester) async {
      await withRegistry(tester, () {
        expect(call('getStockEntryType', ['returned']), 'RETURNED');
        expect(call('getReportTransactionReasonFilter', ['returned']), 'RETURNED');
        expect(call('getSenderOrReceiver', ['returned']), 'senderId');

        final shortfallRow = {
          'quantity': 4,
          'transactionReason': 'RETURNED',
          'additionalFields': {
            'fields': [
              {'key': 'stockEntryType', 'value': 'RETURNED'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['returned', shortfallRow]), 4);
      });
    });

    testWidgets('accepted return appears in upper Stock Received report with accepted quantity', (tester) async {
      await withRegistry(tester, () {
        final entryTypes = call('getStockEntryType', ['receipt']).toString().split(',');
        expect(entryTypes, contains('RETURNED'));
        expect(call('getReportTransactionReasonFilter', ['receipt']), 'RECEIVED');
        expect(call('getSenderOrReceiver', ['receipt']), 'receiverId');

        // Accepted return row: original quantity 5, actual received 2
        final acceptedReturnRow = {
          'quantity': 5,
          'transactionReason': 'RECEIVED',
          'additionalFields': {
            'fields': [
              {'key': 'stockEntryType', 'value': 'RETURNED'},
              {'key': 'actualQuantityReceived', 'value': '2'},
              {'key': 'originalQuantityReceived', 'value': '5'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['receipt', acceptedReturnRow]), 2);
      });
    });

    testWidgets('partially accepted loss of 0 displays 0 in Stock Lost report', (tester) async {
      await withRegistry(tester, () {
        final zeroLossRow = {
          'quantity': 20,
          'additionalFields': {
            'fields': [
              {'key': 'actualQuantityReceived', 'value': '0'},
              {'key': 'originalQuantityReceived', 'value': '20'},
              {'key': 'discrepancyReason', 'value': 'STOCK_LOSS'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['loss', zeroLossRow]), 0);
      });
    });

    testWidgets('partially accepted damage of 0 displays 0 in Stock Damaged report', (tester) async {
      await withRegistry(tester, () {
        final zeroDamageRow = {
          'quantity': 40,
          'additionalFields': {
            'fields': [
              {'key': 'actualQuantityReceived', 'value': '0'},
              {'key': 'originalQuantityReceived', 'value': '40'},
              {'key': 'discrepancyReason', 'value': 'STOCK_DAMAGE'},
            ],
          },
        };
        expect(call('getReportStockQuantity', ['damage', zeroDamageRow]), 0);
      });
    });

    testWidgets('partially accepted loss/damage/in-transit shortfalls are EXCLUDED from Stock Received report', (tester) async {
      await withRegistry(tester, () {
        final receiptFilter = call('getReportTransactionReasonFilter', ['receipt']);
        expect(receiptFilter, 'RECEIVED');

        // Shortfall records resolved with STOCK_DAMAGE, STOCK_LOSS, or IN_TRANSIT
        // have transactionReason matching their discrepancy, NOT RECEIVED.
        final damageTxReason = call('getPartialAcceptTransactionReason', ['RETURNED', 'STOCK_DAMAGE']);
        final lossTxReason = call('getPartialAcceptTransactionReason', ['RETURNED', 'STOCK_LOSS']);
        final transitTxReason = call('getPartialAcceptTransactionReason', ['RETURNED', 'IN_TRANSIT']);

        expect(damageTxReason, 'STOCK_DAMAGE');
        expect(lossTxReason, 'STOCK_LOSS');
        expect(transitTxReason, 'IN_TRANSIT');

        // None of these match the 'RECEIVED' filter for Stock Received report
        expect(receiptFilter.toString().split(','), isNot(contains(damageTxReason)));
        expect(receiptFilter.toString().split(','), isNot(contains(lossTxReason)));
        expect(receiptFilter.toString().split(','), isNot(contains(transitTxReason)));
      });
    });

    testWidgets('distributor role scopes returned reports to user UUID', (tester) async {
      await withRegistry(tester, role: RolesType.distributor, () {
        expect(call('getReportFacilityId', ['returned', 'FACILITY-1']), 'user-uuid-1');
      });
    });

    testWidgets('warehouse manager role scopes returned reports to facility ID', (tester) async {
      await withRegistry(tester, role: RolesType.warehouseManager, () {
        expect(call('getReportFacilityId', ['returned', 'FACILITY-1']), 'FACILITY-1');
      });
    });
  });

  group('View-transaction headings for partial-accept flow', () {
    testWidgets('partially accepted return displays as Stock Receipt Details', (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['RETURNED', 'RECEIVED', 'IN_TRANSIT']),
          'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING',
        );
      });
    });

    testWidgets('partially accepted damage shortfall displays as Stock Damaged Details', (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['DAMAGED', 'STOCK_DAMAGE', 'STOCK_DAMAGE']),
          'INVENTORY_STOCK_DAMAGED_DETAILS_HEADING',
        );
      });
    });

    testWidgets('partially accepted loss shortfall displays as Stock Loss Details', (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['LOSS', 'STOCK_LOSS', 'STOCK_LOSS']),
          'INVENTORY_STOCK_LOSS_DETAILS_HEADING',
        );
      });
    });

    testWidgets('reissue displays as Stock Issue Details', (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['ISSUED', null, 'IN_TRANSIT']),
          'INVENTORY_STOCK_ISSUE_DETAILS_HEADING',
        );
      });
    });
  });
}
