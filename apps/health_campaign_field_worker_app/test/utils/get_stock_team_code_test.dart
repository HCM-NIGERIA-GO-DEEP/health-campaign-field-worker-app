import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(callIt(['RECEIPT', 'RECEIVER', 'user-uuid-1', null]),
          'user-uuid-1');
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
      expect(callIt(['RECEIPT', 'RECEIVER', 'to-team', 'from-team']), 'to-team');
    });
  });

  testWidgets('returns empty when neither team field is set', (tester) async {
    await withRegistry(tester, () {
      expect(callIt(['RECEIPT', 'RECEIVER', null, null]), '');
      expect(callIt(['RECEIPT', 'RECEIVER', '  ', '']), '');
      expect(callIt([]), '');
    });
  });
}
