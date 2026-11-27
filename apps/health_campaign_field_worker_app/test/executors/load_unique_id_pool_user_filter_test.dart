import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/executors/load_unique_id_pool_executor.dart';

/// Liberia QA: Individual sync failed with INVALID_USER_ID ("beneficiary id
/// is dispatched to another user"). The pool table survives logout, so on a
/// shared phone LOAD_UNIQUE_ID_POOL must offer and count only the logged-in
/// user's ids (the download page's count already does).

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
  );
}

void main() {
  Future<Map<String, dynamic>> load(
    WidgetTester tester,
    List<UniqueIdPoolModel> rows,
  ) async {
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
    final result = await tester.runAsync(() => LoadUniqueIdPoolExecutor().execute(
          ActionConfig(
            action: 'test',
            actionType: 'LOAD_UNIQUE_ID_POOL',
            properties: const {},
          ),
          context,
          {'_compositeKey': 'loadUniqueIdPoolUserFilterTest'},
        ));
    return result!;
  }

  final shared = [
    _row('A-OLD', 'user-a', 1),
    _row('A-2', 'user-a', 2),
    _row('B-1', 'user-b', 5),
  ];

  testWidgets("offers and counts only the logged-in user's ids",
      (tester) async {
    _login('user-b');
    final out = await load(tester, shared);
    expect(out['latestBeneficiaryId'], 'B-1');
    expect(out['uniqueIdPoolCount'], 1);
  });

  testWidgets("a user with no ids of their own gets none (must download)",
      (tester) async {
    _login('user-c');
    final out = await load(tester, shared);
    expect(out['latestBeneficiaryId'], isNull);
    expect(out['uniqueIdPoolCount'], 0);
  });

  testWidgets('with no logged-in uuid the pool is not filtered (as before)',
      (tester) async {
    _login('');
    final out = await load(tester, shared);
    expect(out['latestBeneficiaryId'], 'A-OLD');
    expect(out['uniqueIdPoolCount'], 3);
  });
}
