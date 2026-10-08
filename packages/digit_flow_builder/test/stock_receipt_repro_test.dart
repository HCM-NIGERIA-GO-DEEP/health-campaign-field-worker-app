import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the RECORDSTOCK "receive stock" submission, reproduced from the
/// shape the debugger showed: `stockDetails.productdetail` is a one-item list
/// (so the executor takes its multiEntityField branch) and the per-product
/// values live under `<field>_item_0`.
///
/// The `status` mapping in the `stock` config switched on stockEntryType with
/// no RECEIPT case and no `default`. A __switch that matches nothing throws,
/// mapFormToEntities aborts the entire model on a throw, and the executor's
/// multi-entity branch catches that exception silently - so a receipt wrote
/// nothing while still issuing an MRN and showing the success screen.
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

  final stockConfig = jsonConfig['stock'] as Map<String, dynamic>;
  final stockModels = stockConfig['models'] as Map<String, dynamic>;

  /// The forms bloc exposes state.formData as Map<String, Map<String, dynamic>>
  /// (see forms.freezed.dart), which is what reaches the executor.
  Map<String, Map<String, dynamic>> formDataForEntry(String entryType) => {
        'warehouseDetails': <String, dynamic>{
          'dateOfEntry': DateTime(2026, 10, 8, 9, 49, 5),
          'administrativeArea': 'Bomi',
          'facilityToWhich': 'F-2026-10-07-024420',
          'teamCode': null,
        },
        'stockDetails': <String, dynamic>{
          'productdetail': [
            {'id': 'pv-001', 'sku': 'SKU-001'},
          ],
          'facilityFromWhich': 'F-2026-10-07-024418',
          'deliveryTeam': null,
          'transactionReason': 'DAMAGED_IN_TRANSIT',
        },
        'stockProductDetails': <String, dynamic>{
          'batchNumber': null,
          'quantityReceived': null,
          'comment': null,
          'quantitySent_item_0': 10,
          'quantityLost_item_0': 10,
          'quantityDamaged_item_0': 10,
          'quantityReturned_item_0': 10,
          'batchNumber_item_0': null,
          'quantityReceived_item_0': 5000,
        },
      };

  Map<String, dynamic> contextFor(String entryType) => <String, dynamic>{
        'stockEntryType': entryType,
        'transactionType': 'RECEIVED',
        'projectId': 'proj-1',
        'tenantId': 'liberia',
        'mrnNumber': 'MRN-1',
        'senderPartyType': 'WAREHOUSE',
        'receiverPartyType': 'WAREHOUSE',
        // __generate:audit / __generate:clientAudit read createdBy from here.
        'userUUID': 'user-1',
      };

  /// Mirrors TransformerExecutor's multiEntityField branch: swap the one-item
  /// product list for the item itself, then map.
  List<EntityModel> runStockMapping(String entryType) {
    final formValues =
        Map<String, dynamic>.from(formDataForEntry(entryType));
    final products =
        (formValues['stockDetails'] as Map<String, dynamic>)['productdetail']
            as List;
    (formValues['stockDetails'] as Map<String, dynamic>)['productdetail'] =
        products.first;

    return FormEntityMapper(config: jsonConfig).mapFormToEntities(
      formValues: formValues,
      modelsConfig: stockModels,
      context: contextFor(entryType),
      fallbackFormDataString: stockConfig['fallbackModel'] as String?,
    );
  }

  String? statusOf(List<EntityModel> entities) {
    final fields =
        (entities.single.toMap()['additionalFields']?['fields'] as List?) ?? [];
    for (final f in fields) {
      if (f is Map && f['key'] == 'status') return f['value'] as String?;
    }
    return null;
  }

  test('a RECEIPT produces a StockModel instead of throwing on the status switch',
      () {
    final entities = runStockMapping('RECEIPT');

    expect(entities, hasLength(1),
        reason: 'receiving stock must create exactly one StockModel');
  });

  test('a RECEIPT is not left IN_TRANSIT, so it is not picked up as incoming stock',
      () {
    // incomingTransactions filters StockModel on additionalFields containing
    // IN_TRANSIT (see INVENTORY.json); received stock has already arrived and
    // must not match that query, whatever status it carries.
    expect(statusOf(runStockMapping('RECEIPT')), isNot('IN_TRANSIT'));
    expect(statusOf(runStockMapping('RECEIPT')), 'RECEIVED');
  });

  /// receiverId maps to __switch:receiverPartyType{STAFF: __context:teamCode},
  /// and receiverPartyType is STAFF exactly when the destination is a delivery
  /// team. getStockTeamCode (registered in function_registries.dart) is what
  /// fills __context:teamCode; while it was unregistered the context value came
  /// through empty and every delivery-team receipt saved with no receiver.
  group('a delivery-team receipt records the team as the receiver', () {
    List<EntityModel> runWithTeam(String teamCode) {
      final formValues = Map<String, dynamic>.from(formDataForEntry('RECEIPT'));
      final warehouse =
          Map<String, dynamic>.from(formValues['warehouseDetails'] as Map);
      warehouse['facilityToWhich'] = 'DELIVERY_TEAM';
      formValues['warehouseDetails'] = warehouse;

      final products =
          (formValues['stockDetails'] as Map<String, dynamic>)['productdetail']
              as List;
      (formValues['stockDetails'] as Map<String, dynamic>)['productdetail'] =
          products.first;

      final context = contextFor('RECEIPT')
        // getSecondaryType('DELIVERY_TEAM') resolves this to STAFF in the app.
        ..['receiverPartyType'] = 'STAFF'
        ..['teamCode'] = teamCode;

      return FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: formValues,
        modelsConfig: stockModels,
        context: context,
        fallbackFormDataString: stockConfig['fallbackModel'] as String?,
      );
    }

    test('receiverId is the team code, not null', () {
      final stock = runWithTeam('user-uuid-1').single.toMap();

      expect(stock['receiverId'], 'user-uuid-1');
      expect(stock['receiverType'], 'STAFF');
    });

    test('an empty team code is what the unregistered function produced', () {
      // Guards the regression itself: FunctionRegistry.call renders an unknown
      // function as '', which is what used to reach receiverId.
      expect(runWithTeam('').single.toMap()['receiverId'], isNot('DELIVERY_TEAM'));
    });
  });

  group('the entry types that already worked are unchanged', () {
    const expected = {
      'ISSUED': 'IN_TRANSIT',
      'RETURNED': 'IN_TRANSIT',
      'LOSS': 'LOST',
      'DAMAGED': 'DAMAGED',
    };

    for (final entry in expected.entries) {
      test('${entry.key} still maps to ${entry.value}', () {
        final entities = runStockMapping(entry.key);

        expect(entities, hasLength(1));
        expect(statusOf(entities), entry.value);
      });
    }
  });
}
