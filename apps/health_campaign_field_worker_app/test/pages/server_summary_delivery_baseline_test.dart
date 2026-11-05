import 'package:digit_data_model/models/entities/project_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/local_store/server_summary_report_storage.dart';
import 'package:health_campaign_field_worker_app/data/repositories/summary_report_remote_repository.dart';
import 'package:health_campaign_field_worker_app/data/services/server_summary_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const date = '2026-11-05';
  final cycle = ProjectCycle(id: 1, startDate: 0, endDate: 1);
  late ServerSummaryReportService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = ServerSummaryReportService(
      storage: ServerSummaryReportStorage.instance,
    );
    await service.initializeForContext(
      userUuid: 'user',
      projectId: 'project',
      currentCycle: cycle,
    );
  });

  Future<void> sync(int children, int itns) => service.syncSummaryReports(
        userUuid: 'user',
        projectId: 'project',
        currentCycle: cycle,
        reports: [
          ServerSummaryReport(
            date: date,
            createdBy: 'user',
            householdsRegistered: 1,
            peopleInHouseholds: 2,
            individualRegistered: 2,
            beneficiariesRegistered: children,
            childrenTreated: 0,
            itnsDistributed: itns,
            stockConsumedMap: const {},
          ),
        ],
      );

  Future<({int households, int people, int childrenUnder5, int itns})> read({
    int households = 0,
    int closedChildren = 0,
    int syncedChildren = 0,
    int localItns = 0,
    int syncedItns = 0,
  }) =>
      service.baselineFor(
        date: date,
        localHouseholdCount: households,
        delivery: (
          syncedChildrenUnder5: syncedChildren,
          closedChildrenUnder5: closedChildren,
          localItns: localItns,
          syncedItns: syncedItns,
        ),
      );

  test('saved child and ITN baselines survive a sync with local rows', () async {
    await sync(2, 3);
    final before = await read();
    expect((before.childrenUnder5, before.itns), (2, 3));

    await sync(4, 8);
    final after = await read(
      households: 1,
      syncedChildren: 2,
      localItns: 5,
      syncedItns: 5,
    );
    expect((after.childrenUnder5, after.itns), (2, 3));
  });

  test('older dates subtract synced local overlap from the live fallback',
      () async {
    await sync(7, 8);
    final baseline = await read(
      households: 2,
      closedChildren: 1,
      syncedChildren: 2,
      localItns: 6,
      syncedItns: 5,
    );
    expect((baseline.childrenUnder5, baseline.itns), (4, 3));
  });

  test('ITNs seed only after a server report and independently of households',
      () async {
    await read();
    await sync(2, 3);
    await read(households: 1);

    await sync(4, 8);
    final baseline =
        await read(households: 1, localItns: 5, syncedItns: 5);
    expect(baseline.itns, 3);
  });
}
