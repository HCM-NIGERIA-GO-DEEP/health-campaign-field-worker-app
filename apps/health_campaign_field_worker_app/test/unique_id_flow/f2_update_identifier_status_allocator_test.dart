// F2: UPDATE_IDENTIFIER_STATUS gives the pool ID at save time from the
// database. Fixes R0, RC-01, RC-02 (b), RC-03 and RC-04; warns on RC-05/RC-06.
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/executors/update_identifier_status_executor.dart';
import 'package:mocktail/mocktail.dart';

import 'support/unique_id_test_support.dart';

ActionConfig statusAction() => ActionConfig(
      action: '',
      actionType: 'UPDATE_IDENTIFIER_STATUS',
      properties: {'identifierType': 'UNIQUE_BENEFICIARY_ID'},
    );

final household = HouseholdModel(clientReferenceId: 'HH-1');

MockUniqueIdPoolRepo repoWith(List<UniqueIdPoolModel> freeRows) {
  final repo = MockUniqueIdPoolRepo();
  when(() => repo.search(any())).thenAnswer((_) async => freeRows);
  when(() => repo.update(any())).thenAnswer((_) async {});
  return repo;
}

List<UniqueIdPoolModel> writtenRows(MockUniqueIdPoolRepo repo) => verify(
        () => repo.update(captureAny()))
    .captured
    .cast<UniqueIdPoolModel>()
    .toList();

IndividualModel individualOf(Map<String, dynamic> out, String crid) =>
    (out['entities'] as List)
        .whereType<IndividualModel>()
        .firstWhere((i) => i.clientReferenceId == crid);

void main() {
  setUpAll(initTestEnv);
  setUp(() {
    resetRegistry();
    setSingleton(user: UserModel(uuid: 'U1'));
  });
  tearDown(() {
    resetRegistry();
    resetSingleton();
  });

  testWidgets('asks the database for the free rows of the logged-in user', (tester) async {
    final repo = repoWith([poolRow('SMC-0001')]);
    final ctx = await pumpContext(tester, repo: repo);

    await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [individualWith('UNIQUE_BENEFICIARY_ID', 'SMC-0001')],
    });

    final q = verify(() => repo.search(captureAny())).captured.single
        as UniqueIdPoolSearchModel;
    expect(q.status, 'UN_ASSIGNED');
    expect(q.userUuid, 'U1');
  });

  testWidgets('keeps a valid pool ID and marks its row ASSIGNED', (tester) async {
    final repo = repoWith([poolRow('SMC-0001', createdTime: 1), poolRow('SMC-0005', createdTime: 5)]);
    final ctx = await pumpContext(tester, repo: repo);
    final person = individualWith('UNIQUE_BENEFICIARY_ID', 'SMC-0005');

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [household, person],
    });

    final written = writtenRows(repo).single;
    expect(written.id, 'SMC-0005');
    expect(written.status, 'ASSIGNED');
    expect(identical(individualOf(out, 'IND-1'), person), isTrue);
  });

  testWidgets('replaces DEFAULT with the oldest free row and keeps the entity order', (tester) async {
    final repo = repoWith([poolRow('SMC-0007', createdTime: 7), poolRow('SMC-0002', createdTime: 2)]);
    final ctx = await pumpContext(tester, repo: repo);

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [household, individualWith('DEFAULT', '1f0b-uuid'), household],
    });

    final entities = out['entities'] as List;
    expect(entities, hasLength(3));
    expect(entities[0], same(household));
    expect(entities[2], same(household));
    final id = (entities[1] as IndividualModel).identifiers!.single;
    expect(id.identifierType, 'UNIQUE_BENEFICIARY_ID');
    expect(id.identifierId, 'SMC-0002');
    final row = writtenRows(repo).single;
    expect(row.id, 'SMC-0002');
    expect(row.status, 'ASSIGNED');
  });

  testWidgets('RC-03: an ID that is already used is replaced, not given twice', (tester) async {
    // SMC-0001 was used by the previous head; the free rows no longer contain it.
    final repo = repoWith([poolRow('SMC-0002', createdTime: 2)]);
    final ctx = await pumpContext(tester, repo: repo);

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [individualWith('UNIQUE_BENEFICIARY_ID', 'SMC-0001')],
    });

    expect(individualOf(out, 'IND-1').identifiers!.single.identifierId, 'SMC-0002');
    expect(writtenRows(repo).single.id, 'SMC-0002');
  });

  testWidgets('two individuals in one save get two rows', (tester) async {
    final repo = repoWith([poolRow('SMC-0001', createdTime: 1), poolRow('SMC-0002', createdTime: 2)]);
    final ctx = await pumpContext(tester, repo: repo);

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [
        individualWith('DEFAULT', 'u1', crid: 'IND-1'),
        individualWith('DEFAULT', 'u2', crid: 'IND-2'),
      ],
    });

    expect(individualOf(out, 'IND-1').identifiers!.single.identifierId, 'SMC-0001');
    expect(individualOf(out, 'IND-2').identifiers!.single.identifierId, 'SMC-0002');
    expect(writtenRows(repo).map((r) => r.id), ['SMC-0001', 'SMC-0002']);
  });

  testWidgets('empty pool: the UUID stays, nothing is written, nothing throws', (tester) async {
    final repo = repoWith([]);
    final ctx = await pumpContext(tester, repo: repo);
    final person = individualWith('DEFAULT', '1f0b-uuid');

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [person],
    });
    await tester.pump(const Duration(seconds: 6)); // let the warning toast finish

    expect(identical(individualOf(out, 'IND-1'), person), isTrue);
    verifyNever(() => repo.update(any()));
  });

  testWidgets('edit flow: the step does nothing, so an existing ID is never re-keyed',
      (tester) async {
    final repo = repoWith([poolRow('SMC-0009')]);
    final ctx = await pumpContext(tester, repo: repo);
    final existing = individualWith('UNIQUE_BENEFICIARY_ID', 'SMC-0001'); // ASSIGNED
    for (final edit in <Map<String, dynamic>>[
      {'navigation': {'isEdit': 'true'}},
      {'navigation': {'isEdit': true}},
      {'existingModels': [existing]},
    ]) {
      final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
        ...edit,
        'entities': [existing],
      });
      expect(identical(individualOf(out, 'IND-1'), existing), isTrue, reason: '$edit');
    }
    verifyNever(() => repo.search(any()));
  });

  testWidgets('a kept ID whose row cannot be marked is dropped, with a warning',
      (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any())).thenAnswer((_) async => [poolRow('SMC-0001')]);
    when(() => repo.update(any())).thenThrow(Exception('disk full'));
    final ctx = await pumpContext(tester, repo: repo);

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [individualWith('UNIQUE_BENEFICIARY_ID', 'SMC-0001')],
      'formData': {
        'beneficiaryDetails': {'identifiers': 'UNIQUE_BENEFICIARY_ID, SMC-0001'},
      },
    });
    await tester.pump();

    // The row stays free, so the person must not keep SMC-0001.
    final id = individualOf(out, 'IND-1').identifiers!.single;
    expect(id.identifierType, 'DEFAULT');
    expect(id.identifierId, isNot('SMC-0001'));
    final page = (out['formData'] as Map)['beneficiaryDetails'] as Map;
    expect(page['identifiers'], 'DEFAULT, ${id.identifierId}');
    // ToastExecutor shows 'Unknown error' when no localization is loaded.
    expect(find.text('Unknown error'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a stale ID whose replacement row cannot be marked is dropped, not kept',
      (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any())).thenAnswer((_) async => [poolRow('SMC-0002')]);
    when(() => repo.update(any())).thenThrow(Exception('disk full'));
    final ctx = await pumpContext(tester, repo: repo);

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [individualWith('UNIQUE_BENEFICIARY_ID', 'SMC-0001')], // used
    });
    await tester.pump(const Duration(seconds: 6));

    final id = individualOf(out, 'IND-1').identifiers!.single;
    expect(id.identifierType, 'DEFAULT', reason: 'SMC-0001 belongs to someone else');
  });

  testWidgets('a failed row update keeps the original identifier', (tester) async {
    final repo = MockUniqueIdPoolRepo();
    when(() => repo.search(any())).thenAnswer((_) async => [poolRow('SMC-0001')]);
    when(() => repo.update(any())).thenThrow(Exception('disk full'));
    final ctx = await pumpContext(tester, repo: repo);
    final person = individualWith('DEFAULT', '1f0b-uuid');

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [person],
    });
    await tester.pump(const Duration(seconds: 6)); // failed mark → warning toast

    expect(identical(individualOf(out, 'IND-1'), person), isTrue);
  });

  testWidgets('the snapshot drops by one per row marked ASSIGNED', (tester) async {
    FlowBuilderSingleton().setUniqueIdPoolSnapshot(userUuid: 'U1', count: 5);
    final repo = repoWith([poolRow('SMC-0001'), poolRow('SMC-0002')]);
    final ctx = await pumpContext(tester, repo: repo);

    await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [
        individualWith('DEFAULT', 'u1', crid: 'IND-1'),
        individualWith('DEFAULT', 'u2', crid: 'IND-2'),
      ],
    });

    expect(FlowBuilderSingleton().uniqueIdPoolCount, 3);
  });

  testWidgets('the replaced ID also reaches the form data for the acknowledgement', (tester) async {
    final repo = repoWith([poolRow('SMC-0001')]);
    final ctx = await pumpContext(tester, repo: repo);

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [individualWith('DEFAULT', '1f0b-uuid')],
      'formData': {
        'beneficiaryDetails': {'identifiers': 'DEFAULT, 1f0b-uuid'},
      },
    });

    final page = (out['formData'] as Map)['beneficiaryDetails'] as Map;
    expect(page['identifiers'], 'UNIQUE_BENEFICIARY_ID, SMC-0001');
  });

  testWidgets('no individual: no database call', (tester) async {
    final repo = repoWith([]);
    final ctx = await pumpContext(tester, repo: repo);

    await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [household],
    });

    verifyNever(() => repo.search(any()));
  });

  testWidgets('nobody logged in: no database call, entities unchanged', (tester) async {
    setSingleton(user: null, userUuid: '');
    final repo = repoWith([poolRow('SMC-0001')]);
    final ctx = await pumpContext(tester, repo: repo);
    final person = individualWith('DEFAULT', '1f0b-uuid');

    final out = await UpdateIdentifierStatusExecutor().execute(statusAction(), ctx, {
      'entities': [person],
    });

    verifyNever(() => repo.search(any()));
    expect(identical(individualOf(out, 'IND-1'), person), isTrue);
  });
}
