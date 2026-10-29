import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_forms_engine/helper/form_builder_helper.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// getStockTeamCode is what fills __context:teamCode, which the "stock"
/// transformer config maps straight onto receiverId whenever the receiving
/// party is a delivery team:
///
///   receiverId -> __switch:receiverPartyType{STAFF: __context:teamCode, ...}
///
/// INVENTORY.json called this function but nothing registered it, and
/// FunctionRegistry.call returns null for an unknown name (rendered as ''), so
/// delivery-team receipts were saved with no receiver.
///
/// args: [stockEntryType, primaryRole, warehouseDetails.teamCode,
///        stockDetails.deliveryTeam]
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
  // getStockTeamCode reads only its args, so an empty state is enough.
  final stateData = CrudStateData(const {}, const []);

  /// Registration needs a BuildContext, so pump a throwaway widget to get one.
  Future<void> withRegistry(WidgetTester tester, VoidCallback body) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            FunctionRegistries(context).registerAll();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    body();
  }

  dynamic callIt(List<dynamic> args) =>
      FunctionRegistry.call('getStockTeamCode', args, stateData);

  testWidgets('is registered at all', (tester) async {
    await withRegistry(tester, () {
      expect(FunctionRegistry.get('getStockTeamCode'), isNotNull);
    });
  });

  testWidgets('returns the destination team captured on warehouseDetails',
      (tester) async {
    await withRegistry(tester, () {
      expect(
          callIt(['RECEIPT', 'RECEIVER', 'user-uuid-1', null]), 'user-uuid-1');
    });
  });

  testWidgets('strips the userName from a scanned "userName||userUuid" QR',
      (tester) async {
    await withRegistry(tester, () {
      // receiverId has to be the bare uuid, not the display name (see
      // getTeamCode, which decodes the same scanned format).
      expect(callIt(['ISSUED', 'SENDER', 'Jane Doe||user-uuid-2', null]),
          'user-uuid-2');
    });
  });

  testWidgets('falls back to the sending team when no destination team is set',
      (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['RETURNED', 'SENDER', '', 'user-uuid-3']), 'user-uuid-3');
      expect(callIt(['RETURNED', 'SENDER', null, 'Jane||user-uuid-4']),
          'user-uuid-4');
    });
  });

  testWidgets('prefers the destination team when both sides are populated',
      (tester) async {
    await withRegistry(tester, () {
      // receiverId is the only consumer, so the receiving side wins.
      expect(
          callIt(['RECEIPT', 'RECEIVER', 'to-team', 'from-team']), 'to-team');
    });
  });

  testWidgets('returns empty when neither team field is set', (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['RECEIPT', 'RECEIVER', null, null]), '');
      expect(callIt(['RECEIPT', 'RECEIVER', '  ', '']), '');
      expect(callIt([]), '');
    });
  });

  testWidgets('current three-argument config resolves the receiver and name',
      (tester) async {
    await withRegistry(tester, () {
      final args = ['Jane||user-uuid-2', null, 'F-WAREHOUSE'];
      expect(callIt(args), 'user-uuid-2');
      expect(
          FunctionRegistry.call('getStockTeamName', args, stateData), 'Jane');
      expect(
          callIt([null, 'Jane||user-uuid-2', 'DELIVERY_TEAM']), 'user-uuid-2');
      expect(callIt(['null', null, 'F-WAREHOUSE']), '');
      expect(callIt(['Jane||', null, 'F-WAREHOUSE']), '');
    });
  });

  testWidgets('receipt display functions are registered and identify sender',
      (tester) async {
    await withRegistry(tester, () {
      final fields = [
        {'key': 'stockEntryType', 'value': 'RECEIPT'},
        {'key': 'deliveryTeamName', 'value': 'Jane'},
      ];
      expect(FunctionRegistry.call('resolveTeamName', [fields], stateData),
          'Jane');
      expect(
          FunctionRegistry.call(
              'resolveTeamName',
              [
                {'deliveryTeamName': 'Jane'}
              ],
              stateData),
          'Jane');
      expect(
          FunctionRegistry.call(
              'getSecondPagePartyLabel',
              [
                [const AdditionalField('stockEntryType', 'RECEIPT')]
              ],
              stateData),
          'INVENTORY_SENDER_LABEL');
      expect(
          FunctionRegistry.call(
              'teamPartyDisplay', ['Jane', 'user-uuid-2'], stateData),
          'Jane : user-uuid-2');
      expect(
          FunctionRegistry.call(
              'teamPartyDisplay', ['Jane', 'F-SENDER'], stateData),
          'FAC_F-SENDER');
      expect(
          FunctionRegistry.call('getSecondPagePartyLabel', [fields], stateData),
          'INVENTORY_SENDER_LABEL');
      expect(
          FunctionRegistry.call(
              'getSecondPageParty',
              [fields, 'F-SENDER', 'F-RECEIVER', 'WAREHOUSE', 'WAREHOUSE'],
              stateData),
          'FAC_F-SENDER');
      expect(
          FunctionRegistry.call(
              'getSecondPageParty',
              [fields, 'user-uuid-2', 'F-RECEIVER', 'STAFF', 'WAREHOUSE'],
              stateData),
          'Jane : user-uuid-2');
    });
  });

  testWidgets('configured issue creates a staff receiver with a persisted name',
      (tester) async {
    await withRegistry(tester, () {
      const uuid = '64b9b45f-4349-4ab7-a8d9-35facb95150e';
      final flow = (sampleInventoryFlows['flows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => f['name'] == 'RECORDSTOCK');
      final action =
          (flow['onAction'] as List).cast<Map<String, dynamic>>().first;
      final properties = action['properties'] as Map<String, dynamic>;
      final extraData =
          (properties['data'] as List).cast<Map<String, dynamic>>();
      final form = <String, dynamic>{
        'warehouseDetails': {
          'facilityToWhich': 'DELIVERY_TEAM',
          'teamCode': 'sl-team-1||$uuid',
          'dateOfEntry': DateTime(2026, 10, 30),
        },
        'stockDetails': {
          'facilityFromWhich': 'F-DP',
          'productdetail': {'id': 'PVAR-1', 'sku': 'BEDNET'},
        },
        'stockProductDetails': {'quantitySent': 45},
      };
      final contextData = {
        'formData': form,
        'navigation': {
          'stockEntryType': 'ISSUED',
          'transactionType': 'DISPATCHED',
          'primaryRole': 'SENDER',
          'secondaryRole': 'RECEIVER',
          'mrnNumber': 'MRN-1',
        },
      };
      final extras = <String, dynamic>{
        for (final data in extraData)
          data['key'] as String: resolveValue(data['value'], contextData),
      };
      final stock = FormEntityMapper(config: jsonConfig)
          .mapFormToEntities(
            formValues: form,
            modelsConfig:
                jsonConfig['stock']!['models'] as Map<String, dynamic>,
            context: {
              ...extras,
              'projectId': 'project',
              'tenantId': 'si',
              'userUUID': 'issuer',
            },
            fallbackFormDataString: 'StockModel',
          )
          .single as StockModel;
      expect(stock.receiverId, uuid);
      expect(stock.receiverType, 'STAFF');
      expect(stock.senderId, 'F-DP');
      expect(stock.quantity, '45');
      expect(
          stock.additionalFields!.fields
              .firstWhere((f) => f.key == 'deliveryTeamName')
              .value,
          'sl-team-1');
    });
  });

  test('team scanner rejects a missing ID and accepts a complete team QR', () {
    final flow = (sampleInventoryFlows['flows'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['name'] == 'RECORDSTOCK');
    final warehouse = (flow['pages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['page'] == 'warehouseDetails');
    final field = (warehouse['properties'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['fieldName'] == 'teamCode');
    final schema = PropertySchema.fromJson(field);
    final control = buildFormControl('teamCode', schema, schema);
    expect(control.valid, isFalse);
    control.value = 'sl-team-1||';
    expect(control.valid, isFalse);
    control.value = 'sl-team-1||64b9b45f-4349-4ab7-a8d9-35facb95150e';
    expect(control.valid, isTrue);
    control.dispose();
  });

  test('receipt mapping preserves a staff sender and their display name', () {
    final stock = FormEntityMapper(config: jsonConfig)
        .mapFormToEntities(
          formValues: {'stockReceiptDetails': <String, dynamic>{}},
          modelsConfig:
              jsonConfig['stockReceipt']!['models'] as Map<String, dynamic>,
          context: {
            'senderFacilityId': 'sender-uuid',
            'senderPartyType': 'STAFF',
            'receivedFromName': 'sl-team-1',
            'userFacilityId': 'F-WAREHOUSE',
            'receiverPartyType': 'WAREHOUSE',
            'quantity': '45',
            'stockEntryType': 'RECEIPT',
            'transactionType': 'RECEIVED',
            'projectId': 'project',
            'tenantId': 'si',
            'userUUID': 'receiver',
          },
          fallbackFormDataString: 'StockModel',
        )
        .single as StockModel;
    expect(stock.senderId, 'sender-uuid');
    expect(stock.senderType, 'STAFF');
    expect(stock.receiverId, 'F-WAREHOUSE');
    expect(stock.receiverType, 'WAREHOUSE');
    expect(
        stock.additionalFields!.fields
            .firstWhere((f) => f.key == 'deliveryTeamName')
            .value,
        'sl-team-1');
  });
}
