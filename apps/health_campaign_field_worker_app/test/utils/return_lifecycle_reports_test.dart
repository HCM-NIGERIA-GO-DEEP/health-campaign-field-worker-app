import 'dart:convert';
import 'package:digit_crud_bloc/models/global_search_params.dart';
import 'package:digit_crud_bloc/repositories/helpers/query_builder.dart';
import 'package:bloc_test/bloc_test.dart';
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
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';
import 'package:mocktail/mocktail.dart';

/// The partial-accept feature added a second way for stock to move UP the
/// hierarchy (a shortfall return), and a second kind of record that can be
/// accepted (a RETURNED one). Three places still assumed "accept" only ever
/// happened to an ISSUED record:
///
///   1. shortfallTransaction wrote transactionReason null, so the returned
///      shortfall never matched the Stock Returned report's reason filter.
///      It was visible only via View Transactions, which filters on MRN.
///   2. getViewTransactionHeadingCode titled an accepted return "Stock
///      Return Details" instead of "Stock Receipt Details".
///   3. The Stock Received report filtered stockEntryType ISSUED only, so an
///      accepted return never appeared in it.
class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  final stateData = CrudStateData(const {}, const []);

  /// Several of these helpers read context.loggedInUserRoles, which throws
  /// unless an authenticated AuthBloc is in the tree. Role matters to the
  /// report filters (a distributor is keyed by user UUID, a warehouse
  /// manager by facility), so the role is a parameter here.
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

  group('Stock Received report admits accepted returns', () {
    testWidgets('receipt report matches both ISSUED and RETURNED records',
        (tester) async {
      await withRegistry(tester, () {
        final entryTypes = call('getStockEntryType', ['receipt']).toString();
        expect(
            entryTypes.split(','), containsAll(<String>['ISSUED', 'RETURNED']));
      });
    });

    testWidgets(
        'the reason filter stays RECEIVED, which is what keeps pending '
        'returns and write-offs out', (tester) async {
      await withRegistry(tester, () {
        // A pending return carries reason RETURNED and a resolved write-off
        // carries STOCK_DAMAGE / STOCK_LOSS, so neither matches RECEIVED.
        expect(
            call('getReportTransactionReasonFilter', ['receipt']), 'RECEIVED');
      });
    });

    testWidgets('the receiving side is still matched on receiverId',
        (tester) async {
      await withRegistry(tester, () {
        expect(call('getSenderOrReceiver', ['receipt']), 'receiverId');
      });
    });

    testWidgets('an accepted return shows the quantity actually accepted',
        (tester) async {
      await withRegistry(tester, () {
        final partiallyAccepted = {
          'quantity': 10,
          'additionalFields': {
            'fields': [
              {'key': 'actualQuantityReceived', 'value': '7'},
            ],
          },
        };
        expect(
            call('getReportStockQuantity', ['receipt', partiallyAccepted]), 7);

        // A full accept records no actualQuantityReceived, so the stored
        // quantity is the accepted quantity.
        final fullyAccepted = {
          'quantity': 10,
          'additionalFields': {'fields': <dynamic>[]},
        };
        expect(call('getReportStockQuantity', ['receipt', fullyAccepted]), 10);
      });
    });
  });

  group('View-transaction heading follows who is looking at the record', () {
    testWidgets('an accepted return reads as a receipt', (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['RETURNED', 'RECEIVED', null]),
          'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING',
        );
      });
    });

    testWidgets('a return not yet accepted still reads as a return',
        (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['RETURNED', 'RETURNED', null]),
          'INVENTORY_STOCK_RETURN_DETAILS_HEADING',
        );
      });
    });

    testWidgets('an accepted issue still reads as a receipt', (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['ISSUED', 'RECEIVED', null]),
          'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING',
        );
      });
    });

    testWidgets('a shortfall resolved as a write-off keeps its own title',
        (tester) async {
      await withRegistry(tester, () {
        // The upper level retags these, so entry type and reason both move
        // off RETURNED/RECEIVED and the receipt branch must not catch them.
        expect(
          call('getViewTransactionHeadingCode',
              ['DAMAGED', 'STOCK_DAMAGE', 'STOCK_DAMAGE']),
          'INVENTORY_STOCK_DAMAGED_DETAILS_HEADING',
        );
        expect(
          call('getViewTransactionHeadingCode',
              ['LOSS', 'STOCK_LOSS', 'STOCK_LOSS']),
          'INVENTORY_STOCK_LOSS_DETAILS_HEADING',
        );
      });
    });

    testWidgets('a re-issue reads as an issue', (tester) async {
      await withRegistry(tester, () {
        expect(
          call('getViewTransactionHeadingCode', ['ISSUED', null, 'IN_TRANSIT']),
          'INVENTORY_STOCK_ISSUE_DETAILS_HEADING',
        );
      });
    });
  });

  group('shortfallTransaction reason is per-half, not blanket null', () {
    // One config builds both the RETURNED shortfall and the ISSUED re-issue.
    final mapping = ((jsonConfig['shortfallTransaction']
            as Map<String, dynamic>)['models']
        as Map<String, dynamic>)['StockModel'] as Map<String, dynamic>;
    final reason =
        (mapping['mappings'] as Map<String, dynamic>)['transactionReason']
            as String;

    test('a RETURNED shortfall is stamped RETURNED so the report finds it',
        () {
      expect(reason, contains('RETURNED:__value:RETURNED'));
    });

    test('the re-issue half stays null - it is a fresh dispatch', () {
      expect(reason, contains('default:__value:null'));
    });

    test('it switches on stockEntryType', () {
      expect(reason, startsWith('__switch:__context:stockEntryType:'));
    });
  });

  group('the rules hold for both roles', () {
    for (final role in [RolesType.warehouseManager, RolesType.distributor]) {
      testWidgets('${role.toValue()}: returns are scoped to the sender',
          (tester) async {
        await withRegistry(tester, role: role, () {
          // A shortfall return is written with senderId =
          // getUserFacilityId(), which is the facility id for a warehouse
          // manager and the raw user UUID for a distributor.
          // getReportFacilityId mirrors that split, so both roles find
          // their own returns.
          expect(call('getSenderOrReceiver', ['returned']), 'senderId');
          expect(
              call('getReportTransactionReasonFilter', ['returned']),
              'RETURNED');
        });
      });

      testWidgets('${role.toValue()}: receipts admit accepted returns',
          (tester) async {
        await withRegistry(tester, role: role, () {
          expect(call('getStockEntryType', ['receipt']).toString(),
              contains('RETURNED'));
          expect(call('getSenderOrReceiver', ['receipt']), 'receiverId');
        });
      });
    }

    testWidgets('a distributor is keyed by their own uuid, not a facility',
        (tester) async {
      await withRegistry(tester, role: RolesType.distributor, () {
        expect(call('getReportFacilityId', ['returned', 'FAC-1']),
            'user-uuid-1');
      });
    });

    testWidgets('a warehouse manager is keyed by the selected facility',
        (tester) async {
      await withRegistry(tester, role: RolesType.warehouseManager, () {
        expect(call('getReportFacilityId', ['returned', 'FAC-1']), 'FAC-1');
      });
    });
  });
  testWidgets('100 sent / 30 received selects only the linked 70-unit loss',
      (tester) async {
    await withRegistry(tester, () {
      Map<String, dynamic> stock(String type, String quantity, String actual,
              {String? original}) =>
          {
            'quantity': quantity,
            'additionalFields': {
              'fields': [
                {'key': 'stockEntryType', 'value': type},
                {'key': 'discrepancyReason', 'value': 'STOCK_LOSS'},
                {'key': 'status', 'value': 'ACCEPTED'},
                {'key': 'actualQuantityReceived', 'value': actual},
                if (original != null)
                  {'key': 'originalQuantityReceived', 'value': original},
              ]
            },
          };
      final receipt = stock('ISSUED', '100', '30', original: '100');
      final loss = stock('LOSS', '70', '0');
      final fragments =
          (call('getReportStockEntryFilter', ['loss']) as List).cast<String>();
      expect(fragments.any(jsonEncode(receipt['additionalFields']).contains),
          false);
      expect(
          fragments.any(jsonEncode(loss['additionalFields']).contains), true);
      expect(call('getReportStockQuantity', ['receipt', receipt]), 30);
      expect(call('getReportStockQuantity', ['loss', loss]), 70);
      expect(call('getSenderOrReceiver', ['loss']), 'senderId,receiverId');
      expect(call('getSenderOrReceiver', ['damage']), 'senderId,receiverId');
      expect(call('isResolvedDamageReport', ['loss']), true);
    });
  });

  testWidgets('distributor loss keeps the existing LESS and sender filters',
      (tester) async {
    await withRegistry(tester, () {
      expect(call('getStockEntryType', ['loss']), 'LESS');
      expect(call('getSenderOrReceiver', ['loss']), 'senderId');
      expect(call('isResolvedDamageReport', ['loss']), false);
    }, role: RolesType.distributor);
  });

  testWidgets(
      'SQL loss filters keep exact JSON fragments and both facility directions',
      (tester) async {
    await withRegistry(tester, () {
      final filters = [
        SearchFilter(
            root: 'stock',
            field: 'additionalFields',
            operator: 'containsAny',
            value: call('getReportStockEntryFilter', ['loss'])),
        SearchFilter(
            root: 'stock',
            field: call('getSenderOrReceiver', ['loss']).toString(),
            operator: 'equalsAny',
            value: 'lower'),
      ];
      expect(QueryBuilder.buildWhereClauseRaw(filters),
          '(additional_fields LIKE ?) AND (sender_id = ? OR receiver_id = ?)');
      expect(QueryBuilder.buildWhereArgs(filters).map((arg) => arg.value),
          ['%"key":"stockEntryType","value":"LOSS"%', 'lower', 'lower']);
    });
  });
}
