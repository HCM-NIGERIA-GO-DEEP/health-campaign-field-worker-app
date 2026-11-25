// ignore_for_file: depend_on_referenced_packages, implementation_imports
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
import 'package:digit_flow_builder/utils/utils.dart' show resolveValue;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/auth/auth.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/models/role_actions/role_actions_model.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/extensions/extensions.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

class _Auth extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Liberia QA: "View Transactions shows the user uuid instead of the user
/// name for a CDD".
///
/// Three things were missing, and each one alone keeps the uuid on screen:
///  1. the two View Transactions rows called the party functions without the
///     sender / receiver type, so a delivery team member was treated as a
///     facility and never looked up by name;
///  2. the stock save action passed no deliveryTeamName;
///  3. the "stock" transformer mapping had no deliveryTeamName key.
/// The same record is what the Incoming Transactions card reads its sender
/// from.
void main() {
  const cddUuid = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
  const otherUuid = '1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed';
  const teamArgs = 'navigation.stockEntryType, navigation.primaryRole, '
      'formData.warehouseDetails.teamCode, '
      'formData.warehouseDetails.facilityToWhich, '
      'formData.stockDetails.facilityFromWhich, '
      'formData.stockDetails.deliveryTeam';

  final stateData = CrudStateData(const {}, const []);
  final configs = <String, Map>{
    'Dart copy': sampleInventoryFlows as Map,
    'INVENTORY.json':
        jsonDecode(File('assets/configs/json/INVENTORY.json').readAsStringSync())
            as Map,
  };

  /// Registers the app's config functions. With [user], the functions can
  /// read the logged-in user, as they can in the running app.
  Future<void> withRegistry(
    WidgetTester tester,
    VoidCallback body, {
    UserRequestModel? user,
  }) async {
    final registry = Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox.shrink();
    });
    if (user == null) {
      await tester.pumpWidget(MaterialApp(home: registry));
    } else {
      final auth = _Auth();
      whenListen(auth, const Stream<AuthState>.empty(),
          initialState: AuthState.authenticated(
            accessToken: 'a',
            refreshToken: 'r',
            userModel: user,
            actionsWrapper: const RoleActionsWrapperModel(),
          ));
      await tester.pumpWidget(BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp(home: registry),
      ));
    }
    body();
  }

  const cdd = UserRequestModel(
    uuid: cddUuid,
    userName: 'cdd.gbeapo.01',
    name: 'Team One',
    roles: [UserRoleModel(code: 'DISTRIBUTOR')],
  );
  const warehouse = UserRequestModel(
    uuid: otherUuid,
    userName: 'pps.wh.01',
    roles: [UserRoleModel(code: 'WAREHOUSE_MANAGER')],
  );

  dynamic call(String name, List<dynamic> args) =>
      FunctionRegistry.call(name, args, stateData);

  List<Map<String, dynamic>> fields(String entryType, {String? teamName}) => [
        {'key': 'stockEntryType', 'value': entryType},
        if (teamName != null) {'key': 'deliveryTeamName', 'value': teamName},
      ];

  group('team QR', () {
    Future<String> teamCodeOf(WidgetTester tester, UserRequestModel user) async {
      final auth = _Auth();
      whenListen(auth, const Stream<AuthState>.empty(),
          initialState: AuthState.authenticated(
            accessToken: 'a',
            refreshToken: 'r',
            userModel: user,
            actionsWrapper: const RoleActionsWrapperModel(),
          ));
      late String code;
      await tester.pumpWidget(BlocProvider<AuthBloc>.value(
        value: auth,
        child: Builder(builder: (context) {
          code = context.loggedInUserTeamCode;
          return const SizedBox.shrink();
        }),
      ));
      return code;
    }

    testWidgets('the code carries the user name in front of the uuid',
        (tester) async {
      expect(await teamCodeOf(tester, cdd), 'cdd.gbeapo.01||$cddUuid');
      expect(
          await teamCodeOf(
              tester, const UserRequestModel(uuid: cddUuid, name: 'Team One')),
          'Team One||$cddUuid',
          reason: 'no user name: the display name');
      expect(await teamCodeOf(tester, const UserRequestModel(uuid: cddUuid)),
          cddUuid,
          reason: 'no name at all: the bare uuid');
    });

    test('source check: the QR a warehouse scans is that code', () {
      // The page is not mounted here (it needs the attendance repositories).
      final page = File('lib/pages/qr_details_page.dart').readAsStringSync();
      expect(page, contains('data: context.loggedInUserTeamCode'));
      expect(page, isNot(contains('data: context.loggedInUserUuid')));
    });

    testWidgets('scanned by a warehouse, it gives the id and the name',
        (tester) async {
      final qr = await teamCodeOf(tester, cdd);
      await withRegistry(tester, user: warehouse, () {
        final a = ['ISSUED', 'SENDER', qr, 'DELIVERY_TEAM', 'F-1', null];
        expect(call('getStockTeamCode', a), cddUuid);
        expect(call('getStockTeamName', a), 'cdd.gbeapo.01');
        expect(
            call('getStockReceiverId',
                ['ISSUED', 'SENDER', 'DELIVERY_TEAM', qr, null]),
            cddUuid,
            reason: 'the receiver id never includes the name');
      });
    });
  });

  group('getStockTeamName', () {
    List<dynamic> args({
      String? teamCode,
      String? to,
      String? from,
      String? sourceTeam,
    }) =>
        ['ISSUED', 'SENDER', teamCode, to, from, sourceTeam];

    testWidgets('issue to a team: the user name of the scanned team QR',
        (tester) async {
      await withRegistry(tester, () {
        final a = args(
            teamCode: 'cdd.gbeapo.01||$cddUuid', to: 'DELIVERY_TEAM', from: 'F-1');
        expect(call('getStockTeamName', a), 'cdd.gbeapo.01');
        expect(call('getStockTeamCode', a), cddUuid,
            reason: 'the id comes from the same code');
      });
    });

    testWidgets('stock coming from a team: the name of the scanned source team',
        (tester) async {
      // The warehouse user is logged in; the name must be the team's, not
      // theirs.
      await withRegistry(tester, user: warehouse, () {
        final a = args(
            to: 'F-1',
            from: 'DELIVERY_TEAM',
            sourceTeam: 'cdd.gbeapo.01||$cddUuid');
        expect(call('getStockTeamName', a), 'cdd.gbeapo.01');
        expect(call('getStockTeamCode', a), cddUuid);
      });
    });

    testWidgets('a team code typed without a name saves no name',
        (tester) async {
      await withRegistry(tester, user: cdd, () {
        final a = args(teamCode: cddUuid, to: 'DELIVERY_TEAM', from: 'F-1');
        expect(call('getStockTeamName', a), '');
        expect(call('getStockTeamCode', a), cddUuid);
      });
    });

    testWidgets('warehouse to warehouse saves no name', (tester) async {
      await withRegistry(tester, user: cdd, () {
        expect(call('getStockTeamName', args(to: 'F-2', from: 'F-1')), '');
        expect(call('getStockTeamName', args()), '');
      });
    });

    testWidgets('a distributor with no team code: their own user name',
        (tester) async {
      // getStockTeamCode uses the distributor's own uuid here, so the name
      // has to be their own as well.
      await withRegistry(tester, user: cdd, () {
        final a = args(to: 'DELIVERY_TEAM', from: 'F-1');
        expect(call('getStockTeamCode', a), cddUuid);
        expect(call('getStockTeamName', a), 'cdd.gbeapo.01');
      });
    });

    testWidgets('a warehouse manager with no team code saves no name',
        (tester) async {
      await withRegistry(tester, user: warehouse, () {
        final a = args(to: 'DELIVERY_TEAM', from: 'F-1');
        expect(call('getStockTeamCode', a), '');
        expect(call('getStockTeamName', a), '');
      });
    });

    testWidgets('no logged-in user in scope returns blank and does not throw',
        (tester) async {
      await withRegistry(tester, () {
        final a = args(to: 'DELIVERY_TEAM', from: 'F-1');
        expect(call('getStockTeamName', a), '');
        expect(call('getStockTeamName', const []), '');
      });
    });

    testWidgets("a distributor's own return: the name of their own team code",
        (tester) async {
      await withRegistry(tester, user: cdd, () {
        final a = args(
            to: 'F-1',
            from: 'DELIVERY_TEAM',
            sourceTeam: 'cdd.gbeapo.01||$cddUuid');
        expect(call('getStockTeamCode', a), cddUuid);
        expect(call('getStockTeamName', a), 'cdd.gbeapo.01');
      });
    });

    testWidgets('a name is saved only where an id is, for every argument mix',
        (tester) async {
      // The name must never describe a team the id does not.
      const teams = [null, '', cddUuid, 'cdd.gbeapo.01||$cddUuid'];
      const places = [null, 'DELIVERY_TEAM', 'F-1'];
      for (final user in [cdd, warehouse, null]) {
        await withRegistry(tester, user: user, () {
          for (final teamCode in teams) {
            for (final to in places) {
              for (final from in places) {
                for (final sourceTeam in teams) {
                  final a = args(
                      teamCode: teamCode,
                      to: to,
                      from: from,
                      sourceTeam: sourceTeam);
                  final id = call('getStockTeamCode', a) as String;
                  final name = call('getStockTeamName', a) as String;
                  final where = '$a as ${user?.userName}';
                  if (id.isEmpty) expect(name, '', reason: where);
                  if (name.isNotEmpty) {
                    expect(name, 'cdd.gbeapo.01', reason: where);
                    expect(id, cddUuid, reason: where);
                  }
                }
              }
            }
          }
        });
      }
    });
  });

  group('View Transactions party', () {
    testWidgets('a team receiver shows the saved name', (tester) async {
      await withRegistry(tester, user: warehouse, () {
        final f = fields('ISSUED', teamName: 'cdd.gbeapo.01');
        expect(
            call('getFirstPageParty', [f, 'F-1', cddUuid, 'WAREHOUSE', 'STAFF']),
            'cdd.gbeapo.01');
        expect(
            call('getSecondPageParty', [f, 'F-1', cddUuid, 'WAREHOUSE', 'STAFF']),
            'FAC_F-1');
      });
    });

    testWidgets('a team sender shows the saved name', (tester) async {
      await withRegistry(tester, user: warehouse, () {
        final f = fields('RETURNED', teamName: 'cdd.gbeapo.01');
        expect(
            call('getFirstPageParty', [f, cddUuid, 'F-1', 'STAFF', 'WAREHOUSE']),
            'cdd.gbeapo.01');
      });
    });

    testWidgets(
        'a record with no saved name shows the logged-in user their own name',
        (tester) async {
      // Records saved before the name was stored. This is the CDD looking at
      // their own transactions.
      await withRegistry(tester, user: cdd, () {
        expect(
            call('getFirstPageParty',
                [fields('ISSUED'), 'F-1', cddUuid, 'WAREHOUSE', 'STAFF']),
            'cdd.gbeapo.01');
        expect(
            call('getSecondPageParty',
                [fields('RETURNED'), 'F-1', cddUuid, 'WAREHOUSE', 'STAFF']),
            'cdd.gbeapo.01');
        expect(
            call('getSecondPageParty',
                [fields('ISSUED'), cddUuid, 'F-1', 'STAFF', 'WAREHOUSE']),
            'cdd.gbeapo.01');
      });
    });

    testWidgets("another user's uuid with no saved name stays the uuid",
        (tester) async {
      await withRegistry(tester, user: warehouse, () {
        expect(
            call('getFirstPageParty',
                [fields('ISSUED'), 'F-1', cddUuid, 'WAREHOUSE', 'STAFF']),
            cddUuid);
      });
      await withRegistry(tester, () {
        expect(
            call('getFirstPageParty',
                [fields('ISSUED'), 'F-1', cddUuid, 'WAREHOUSE', 'STAFF']),
            cddUuid,
            reason: 'no logged-in user in scope must not throw');
      });
    });

    testWidgets('a facility party keeps its FAC_ prefix', (tester) async {
      await withRegistry(tester, user: cdd, () {
        final f = fields('RECEIPT', teamName: 'cdd.gbeapo.01');
        expect(
            call('getFirstPageParty', [f, 'F-1', cddUuid, 'WAREHOUSE', 'STAFF']),
            'FAC_F-1');
      });
    });

    testWidgets('the old 3-argument call still treats the party as a facility',
        (tester) async {
      // An app update must not change what a not-yet-updated config shows
      // for someone else's id.
      await withRegistry(tester, user: warehouse, () {
        expect(
            call('getFirstPageParty',
                [fields('ISSUED', teamName: 'x'), 'F-1', cddUuid]),
            'FAC_$cddUuid');
        expect(
            call('getSecondPageParty',
                [fields('RECEIPT', teamName: 'x'), 'F-1', cddUuid]),
            'FAC_$cddUuid');
      });
    });

    testWidgets(
        'the record saved when a team member accepts stock shows their name',
        (tester) async {
      // "stockReceipt" saves receiverId = the member's own uuid with
      // receiverType WAREHOUSE. The details page showed FAC_<own uuid>.
      await withRegistry(tester, user: cdd, () {
        final f = fields('RECEIPT');
        expect(
            call('getSecondPageParty',
                [f, 'F-1', cddUuid, 'WAREHOUSE', 'WAREHOUSE']),
            'cdd.gbeapo.01');
        expect(
            call('getFirstPageParty',
                [f, 'F-1', cddUuid, 'WAREHOUSE', 'WAREHOUSE']),
            'FAC_F-1',
            reason: 'the sending facility is unchanged');
        expect(call('getSecondPageParty', [f, 'F-1', cddUuid]), 'cdd.gbeapo.01',
            reason: 'also with a config that has not been updated');
      });
    });

    testWidgets("someone else's uuid saved as a facility keeps the FAC_ form",
        (tester) async {
      await withRegistry(tester, user: warehouse, () {
        expect(
            call('getSecondPageParty',
                [fields('RECEIPT'), 'F-1', cddUuid, 'WAREHOUSE', 'WAREHOUSE']),
            'FAC_$cddUuid');
      });
      await withRegistry(tester, () {
        expect(
            call('getSecondPageParty',
                [fields('RECEIPT'), 'F-1', cddUuid, 'WAREHOUSE', 'WAREHOUSE']),
            'FAC_$cddUuid',
            reason: 'no logged-in user in scope must not throw');
        expect(
            call('getFirstPageParty',
                [fields('RECEIPT'), '', cddUuid, 'WAREHOUSE', 'WAREHOUSE']),
            '',
            reason: 'an empty id never becomes a bare "FAC_"');
      });
    });
  });

  group('Incoming Transactions sender (getFacilityName)', () {
    testWidgets('one argument: unchanged', (tester) async {
      await withRegistry(tester, () {
        expect(call('getFacilityName', ['F-2026-10-07-024420']),
            'FAC_F-2026-10-07-024420');
        expect(call('getFacilityName', [cddUuid]), cddUuid);
        expect(call('getFacilityName', const []), '');
        expect(call('getFacilityName', [null]), '');
      });
    });

    testWidgets('a team sender shows the name saved on the record',
        (tester) async {
      await withRegistry(tester, () {
        expect(
            call('getFacilityName',
                [cddUuid, fields('RETURNED', teamName: 'cdd.gbeapo.01')]),
            'cdd.gbeapo.01');
        expect(call('getFacilityName', [cddUuid, fields('RETURNED')]), cddUuid,
            reason: 'no saved name: the id, as before');
        expect(call('getFacilityName', [cddUuid, null]), cddUuid);
        expect(
            call('getFacilityName', [
              'F-1',
              fields('RETURNED', teamName: 'cdd.gbeapo.01'),
            ]),
            'FAC_F-1',
            reason: 'a facility sender is never given a team name');
      });
    });

    testWidgets('a sender that is not a team member never gets the team name',
        (tester) async {
      // The saved name is the team on either side. On a team member's own
      // Incoming card the sender is the warehouse and the name is their own.
      await withRegistry(tester, () {
        final f = fields('ISSUED', teamName: 'cdd.gbeapo.01');
        const warehouseId = 'a3bb189e-8bf9-3888-9912-ace4e6543002';
        expect(call('getFacilityName', [warehouseId, f, 'WAREHOUSE']),
            warehouseId);
        expect(call('getFacilityName', [cddUuid, f, 'STAFF']), 'cdd.gbeapo.01');
        // A record with no type saved behaves as with two arguments.
        for (final noType in [null, '', 'null']) {
          expect(call('getFacilityName', [cddUuid, f, noType]), 'cdd.gbeapo.01',
              reason: 'type "$noType"');
        }
      });
    });

    testWidgets('the name is also read from the scanned team code on the record',
        (tester) async {
      await withRegistry(tester, () {
        expect(
            call('getFacilityName', [
              cddUuid,
              [
                {'key': 'deliveryTeam', 'value': 'cdd.gbeapo.01||$cddUuid'},
              ],
            ]),
            'cdd.gbeapo.01');
      });
    });

    testWidgets('a plain second argument is used only when it is a name',
        (tester) async {
      await withRegistry(tester, () {
        String shown(Object? second) =>
            call('getFacilityName', [cddUuid, second]) as String;

        expect(shown('cdd.gbeapo.01'), 'cdd.gbeapo.01');
        expect(shown('cdd.gbeapo.01||$cddUuid'), 'cdd.gbeapo.01');
        // Not names: blank, a stringified null, an unresolved config path,
        // a facility id, another uuid (an older config passed receiverId).
        for (final notAName in [
          '',
          '  ',
          'null',
          '{{item.name}}',
          'item.items[0].name',
          'F-2026-10-07-024420',
          otherUuid,
        ]) {
          expect(shown(notAName), cddUuid, reason: '"$notAName"');
        }
      });
    });
  });

  group('config', () {
    Map<String, dynamic> recordStock(Map flows) => (flows['flows'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['name'] == 'RECORDSTOCK');
    List<Map<String, dynamic>> saveData(Map flows) {
      final action = (recordStock(flows)['onAction'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((a) => a['actionType'] == 'FETCH_TRANSFORMER_CONFIG');
      final properties = action['properties'] as Map<String, dynamic>;
      return (properties['data'] as List).cast<Map<String, dynamic>>();
    }
    String valueOf(Map flows, String key) =>
        saveData(flows).singleWhere((e) => e['key'] == key)['value'] as String;

    for (final MapEntry(key: source, value: flows) in configs.entries) {
      final text = jsonEncode(flows);

      test('$source: both View Transactions rows pass the party types', () {
        expect(
            RegExp(r'fn:getFirstPageParty\(([^)]*)\)')
                .allMatches(text)
                .map((m) => m.group(1)),
            [
              'item.items[0].additionalFields.fields, item.items[0].senderId, '
                  'item.items[0].receiverId, item.items[0].senderType, '
                  'item.items[0].receiverType'
            ]);
        expect(
            RegExp(r'fn:getSecondPageParty\(([^)]*)\)')
                .allMatches(text)
                .map((m) => m.group(1)),
            [
              'item.additionalFields.fields, item.senderId, item.receiverId, '
                  'item.senderType, item.receiverType'
            ]);
      });

      test('$source: the Incoming Transactions sender is given the record',
          () {
        expect(
            RegExp(r'fn:getFacilityName\(([^)]*)\)')
                .allMatches(text)
                .map((m) => m.group(1)),
            [
              'item.items[0].senderId, item.items[0].additionalFields.fields, '
                  'item.items[0].senderType'
            ]);
      });

      test('$source: the save action reads the name from the id\'s own code',
          () {
        expect(valueOf(flows, 'teamCode'), '{{fn:getStockTeamCode($teamArgs)}}');
        expect(valueOf(flows, 'deliveryTeamName'),
            '{{fn:getStockTeamName($teamArgs)}}');
      });

      testWidgets('$source: the two values resolve on a real submit context',
          (tester) async {
        await withRegistry(tester, user: warehouse, () {
          final submit = {
            'navigation': {'stockEntryType': 'ISSUED', 'primaryRole': 'SENDER'},
            'formData': {
              'warehouseDetails': {
                'teamCode': 'cdd.gbeapo.01||$cddUuid',
                'facilityToWhich': 'DELIVERY_TEAM',
              },
              'stockDetails': {'facilityFromWhich': 'F-1', 'deliveryTeam': null},
            },
          };
          expect(resolveValue(valueOf(flows, 'teamCode'), submit), cddUuid);
          expect(resolveValue(valueOf(flows, 'deliveryTeamName'), submit),
              'cdd.gbeapo.01');
        });
      });
    }

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

    Map<String, dynamic> savedFields({String? teamName}) {
      final entities = FormEntityMapper(config: jsonConfig).mapFormToEntities(
        formValues: {
          'warehouseDetails': {'facilityToWhich': 'DELIVERY_TEAM'},
          'stockDetails': {
            'productdetail': {'id': 'pv-001', 'sku': 'ITN'},
            'facilityFromWhich': 'F-1',
          },
          'stockProductDetails': {'quantitySent': 40},
        },
        modelsConfig: stockConfig['models'] as Map<String, dynamic>,
        context: {
          'stockEntryType': 'ISSUED',
          'transactionType': 'DISPATCHED',
          'projectId': 'proj-1',
          'tenantId': 'lr',
          'mrnNumber': 'MRN-1',
          'senderPartyType': 'WAREHOUSE',
          'receiverPartyType': 'STAFF',
          'teamCode': cddUuid,
          'userUUID': 'user-1',
          'stockUnit': 'PIECES',
          if (teamName != null) 'deliveryTeamName': teamName,
        },
        fallbackFormDataString: stockConfig['fallbackModel'] as String?,
      );
      final stock = entities.whereType<StockModel>().single.toMap();
      expect(stock['receiverId'], cddUuid);
      expect(stock['receiverType'], 'STAFF');
      final additional = stock['additionalFields'] as Map?;
      return {
        for (final f in (additional?['fields'] as List?) ?? const [])
          (f as Map)['key'] as String: f['value'],
      };
    }

    test('the stock record saves the team name', () {
      expect(savedFields(teamName: 'cdd.gbeapo.01')['deliveryTeamName'],
          'cdd.gbeapo.01');
    });

    test('no team name: the stock is still saved, without the key', () {
      expect(savedFields().containsKey('deliveryTeamName'), isFalse);
      expect(savedFields(teamName: '').containsKey('deliveryTeamName'), isFalse);
    });
  });
}
