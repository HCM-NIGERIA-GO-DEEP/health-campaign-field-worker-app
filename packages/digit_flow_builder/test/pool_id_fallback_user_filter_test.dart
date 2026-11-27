import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Liberia QA: Individual sync failed with INVALID_USER_ID ("beneficiary id
/// is dispatched to another user"). The pool table survives logout, so on a
/// shared phone the save-time fallback must pick only the logged-in user's
/// ids. Runs the real TransformerExecutor over the real config.

UniqueIdPoolModel _row(String id, String user, int created) =>
    UniqueIdPoolModel(
      id: id,
      status: IdStatus.unAssigned.toValue(),
      userUuid: user,
      deviceUuid: 'device',
      auditDetails: AuditDetails(createdBy: user, createdTime: created),
    );

/// Filters like UniqueIdPoolLocalRepository.search.
class _Pool extends Fake
    implements LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> {
  _Pool(this.rows);
  final List<UniqueIdPoolModel> rows;

  @override
  Future<List<UniqueIdPoolModel>> search(UniqueIdPoolSearchModel query) async =>
      rows
          .where((r) =>
              (query.status == null || r.status == query.status) &&
              (query.userUuid == null || r.userUuid == query.userUuid) &&
              (query.id == null || r.id == query.id))
          .toList();
}

void _login(String uuid) {
  FlowBuilderSingleton().setInitialData(
    loggedInUserUuid: uuid,
    maxRadius: 10,
    projectId: 'project',
    selectedBeneficiaryType: BeneficiaryType.household,
    projectType: null,
    selectedProject:
        ProjectModel(id: 'project', name: 'Project', tenantId: 'lr'),
    loggedInUser: UserModel(uuid: uuid),
    userRoles: const [
      {'code': 'REGISTRAR', 'name': 'REGISTRAR'}
    ],
  );
  FlowBuilderSingleton().setBoundary(
    boundary: BoundaryModel(code: 'COMM_1', name: 'COMM_1'),
  );
}

void main() {
  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  Future<String?> savedBeneficiaryId(
    WidgetTester tester,
    List<UniqueIdPoolModel> rows, {
    String? carried,
  }) async {
    late BuildContext context;
    await tester.pumpWidget(
      RepositoryProvider<
          LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>.value(
        value: _Pool(rows),
        child: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ),
    );
    final result = await tester.runAsync(() => TransformerExecutor().execute(
          ActionConfig(
            action: 'test',
            actionType: 'FETCH_TRANSFORMER_CONFIG',
            properties: const {'configName': 'individualRegistration'},
          ),
          context,
          {
            'formData': {
              'beneficiaryDetails': {
                'nameOfIndividual': 'Kofi',
                'familyname': 'Kollie',
                if (carried != null)
                  'identifiers': 'UNIQUE_BENEFICIARY_ID, ' + carried,
              },
            },
            '_compositeKey': 'poolIdFallbackUserFilterTest',
            'navigation': const {'HouseholdClientReferenceId': 'household-1'},
          },
        ));
    final individual =
        (result!['entities'] as List).whereType<IndividualModel>().single;
    final ids = individual.identifiers
            ?.where((i) => i.identifierType == 'UNIQUE_BENEFICIARY_ID')
            .map((i) => i.identifierId)
            .toList() ??
        [];
    return ids.isEmpty ? null : ids.single;
  }

  testWidgets("takes the logged-in user's id, not another user's older one",
      (tester) async {
    _login('user-b');
    final id = await savedBeneficiaryId(tester, [
      _row('A-OLD', 'user-a', 1),
      _row('B-1', 'user-b', 5),
    ]);
    expect(id, 'B-1');
  });

  testWidgets("never takes another user's id when the user has none",
      (tester) async {
    _login('user-b');
    final id = await savedBeneficiaryId(tester, [_row('A-OLD', 'user-a', 1)]);
    expect(id, isNull);
  });

  testWidgets("still takes the user's oldest id first", (tester) async {
    _login('user-b');
    final id = await savedBeneficiaryId(tester, [
      _row('B-2', 'user-b', 9),
      _row('B-1', 'user-b', 5),
    ]);
    expect(id, 'B-1');
  });

  testWidgets("replaces a carried id that belongs to another user",
      (tester) async {
    _login('user-b');
    final id = await savedBeneficiaryId(
      tester,
      [_row('A-OLD', 'user-a', 1), _row('B-1', 'user-b', 5)],
      carried: 'A-OLD',
    );
    expect(id, 'B-1');
  });

  testWidgets("keeps the user's own carried id, even when not the oldest",
      (tester) async {
    _login('user-b');
    final id = await savedBeneficiaryId(
      tester,
      [_row('B-1', 'user-b', 5), _row('B-2', 'user-b', 9)],
      carried: 'B-2',
    );
    expect(id, 'B-2');
  });

  testWidgets('keeps a carried id that is not in the pool (manual id)',
      (tester) async {
    _login('user-b');
    final id = await savedBeneficiaryId(
      tester,
      [_row('B-1', 'user-b', 5)],
      carried: 'MANUAL-7',
    );
    expect(id, 'MANUAL-7');
  });

  testWidgets('with no logged-in uuid the pool is not filtered (as before)',
      (tester) async {
    _login('');
    final id = await savedBeneficiaryId(tester, [_row('A-OLD', 'user-a', 1)]);
    expect(id, 'A-OLD');
  });
}
