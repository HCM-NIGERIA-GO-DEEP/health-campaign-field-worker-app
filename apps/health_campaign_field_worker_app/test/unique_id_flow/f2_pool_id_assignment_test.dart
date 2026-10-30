// F2 (pure logic): which pool row each individual gets at save time.
// Fixes R0, RC-01, RC-02 (b), RC-03, RC-04; reports RC-05/RC-06 as exhausted.
import 'package:digit_data_model/data_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/beneficiary_id/pool_id_assignment.dart';

import 'support/unique_id_test_support.dart';

IdentifierModel idf(String type, String? id,
        {String crid = 'IND-1', String ref = 'IDF-1', String? tenant}) =>
    IdentifierModel(
      individualClientReferenceId: crid,
      clientReferenceId: ref,
      identifierType: type,
      identifierId: id,
      tenantId: tenant,
    );

IndividualModel person(String crid, List<IdentifierModel>? ids) =>
    IndividualModel(clientReferenceId: crid, identifiers: ids);

int _gen = 0;
String nextRef() => 'NEW-${++_gen}';

PoolIdAssignmentResult run(List<IndividualModel> people, List<UniqueIdPoolModel> rows) =>
    assignPoolIds(
      individuals: people,
      unassignedRows: rows,
      userUuid: 'U1',
      newClientReferenceId: nextRef,
    );

void main() {
  setUpAll(initTestEnv);
  setUp(() => _gen = 0);

  test('keeps an identifier that points to a free row of the user', () {
    final p = person('IND-1', [idf(uniqueBeneficiaryIdType, 'SMC-0005')]);
    final r = run([p], [poolRow('SMC-0001', createdTime: 1), poolRow('SMC-0005', createdTime: 5)]);

    final a = r.assignments.single;
    expect(a.outcome, PoolIdOutcome.kept);
    expect(a.row!.id, 'SMC-0005');
    expect(identical(a.individual, p), isTrue);
    expect(r.anyExhausted, isFalse);
  });

  test('replaces DEFAULT with the oldest free row', () {
    final p = person('IND-1', [idf('DEFAULT', '1f0b-uuid')]);
    final r = run([p], [poolRow('SMC-0009', createdTime: 9), poolRow('SMC-0002', createdTime: 2)]);

    final a = r.assignments.single;
    expect(a.outcome, PoolIdOutcome.reassigned);
    expect(a.row!.id, 'SMC-0002');
    final id = a.individual.identifiers!.single;
    expect(id.identifierType, uniqueBeneficiaryIdType);
    expect(id.identifierId, 'SMC-0002');
    expect(a.replaced!.identifierType, 'DEFAULT');
    expect(a.replaced!.identifierId, '1f0b-uuid');
  });

  test('keeps the identifier object fields when it replaces the value', () {
    final p = person('IND-7', [idf('DEFAULT', 'u', crid: 'IND-7', ref: 'IDF-77', tenant: 'ng')]);
    final id = run([p], [poolRow('SMC-0001')]).assignments.single.individual.identifiers!.single;

    expect(id.clientReferenceId, 'IDF-77');
    expect(id.individualClientReferenceId, 'IND-7');
    expect(id.tenantId, 'ng');
  });

  test('replaces the pool-type identifier and leaves another identifier alone', () {
    final other = idf('NATIONAL_ID', 'N-1', ref: 'IDF-A');
    final p = person('IND-1', [other, idf('DEFAULT', 'u', ref: 'IDF-B')]);
    final ids = run([p], [poolRow('SMC-0001')]).assignments.single.individual.identifiers!;

    expect(ids[0].identifierType, 'NATIONAL_ID');
    expect(ids[0].identifierId, 'N-1');
    expect(ids[1].identifierType, uniqueBeneficiaryIdType);
    expect(ids[1].identifierId, 'SMC-0001');
  });

  test('replaces an ID that is used, belongs to another user, or is unknown', () {
    for (final stale in ['SMC-USED', 'SMC-OTHER', 'SMC-UNKNOWN']) {
      final p = person('IND-1', [idf(uniqueBeneficiaryIdType, stale)]);
      final rows = [
        poolRow('SMC-USED', status: 'ASSIGNED'),
        poolRow('SMC-OTHER', userUuid: 'U2'),
        poolRow('SMC-0003', createdTime: 3),
      ];
      final a = run([p], rows).assignments.single;
      expect(a.outcome, PoolIdOutcome.reassigned, reason: stale);
      expect(a.individual.identifiers!.single.identifierId, 'SMC-0003', reason: stale);
    }
  });

  test('never gives one row to two individuals', () {
    final both = [
      person('IND-1', [idf(uniqueBeneficiaryIdType, 'SMC-0001', crid: 'IND-1')]),
      person('IND-2', [idf(uniqueBeneficiaryIdType, 'SMC-0001', crid: 'IND-2')]),
      person('IND-3', [idf('DEFAULT', 'u', crid: 'IND-3')]),
    ];
    final r = run(both, [poolRow('SMC-0001', createdTime: 1), poolRow('SMC-0002', createdTime: 2), poolRow('SMC-0003', createdTime: 3)]);

    expect(r.assignments.map((a) => a.row!.id), ['SMC-0001', 'SMC-0002', 'SMC-0003']);
    expect(r.assignments.map((a) => a.outcome),
        [PoolIdOutcome.kept, PoolIdOutcome.reassigned, PoolIdOutcome.reassigned]);
  });

  test('an empty pool leaves the individual unchanged and reports it', () {
    final p = person('IND-1', [idf('DEFAULT', 'u')]);
    final r = run([p], []);

    expect(r.assignments.single.outcome, PoolIdOutcome.exhausted);
    expect(r.assignments.single.row, isNull);
    expect(identical(r.assignments.single.individual, p), isTrue);
    expect(r.anyExhausted, isTrue);
  });

  test('adds an identifier when the individual has none', () {
    final ids = run([person('IND-9', null)], [poolRow('SMC-0001')])
        .assignments
        .single
        .individual
        .identifiers!;

    expect(ids, hasLength(1));
    expect(ids.single.identifierType, uniqueBeneficiaryIdType);
    expect(ids.single.identifierId, 'SMC-0001');
    expect(ids.single.individualClientReferenceId, 'IND-9');
    expect(ids.single.clientReferenceId, 'NEW-1');
  });

  test('markPoolRowAssigned sets ASSIGNED and the client audit', () {
    final row = markPoolRowAssigned(poolRow('SMC-0001', createdTime: 10),
        userUuid: 'U1', nowMillis: 99);

    expect(row.status, poolStatusAssigned);
    expect(row.id, 'SMC-0001');
    expect(row.clientAuditDetails!.lastModifiedBy, 'U1');
    expect(row.clientAuditDetails!.lastModifiedTime, 99);
    expect(row.clientAuditDetails!.createdTime, 10);
  });

  test('sortOldestFirst orders by createdTime, then by id', () {
    final sorted = sortOldestFirst([
      poolRow('B', createdTime: 5),
      poolRow('A', createdTime: 5),
      poolRow('C', createdTime: 1),
    ]);
    expect(sorted.map((r) => r.id), ['C', 'A', 'B']);
  });

  test('replaceIdentifierInFormData swaps only the matching identifiers value', () {
    final form = {
      'beneficiaryDetails': {'identifiers': 'DEFAULT, 1f0b-uuid', 'name': 'Ada'},
      'other': {'identifiers': 'DEFAULT, another'},
    };
    final out = replaceIdentifierInFormData(
      form,
      fromType: 'DEFAULT',
      fromId: '1f0b-uuid',
      toType: uniqueBeneficiaryIdType,
      toId: 'SMC-0001',
    )!;

    expect((out['beneficiaryDetails'] as Map)['identifiers'], 'UNIQUE_BENEFICIARY_ID, SMC-0001');
    expect((out['beneficiaryDetails'] as Map)['name'], 'Ada');
    expect((out['other'] as Map)['identifiers'], 'DEFAULT, another');
    expect((form['beneficiaryDetails'] as Map)['identifiers'], 'DEFAULT, 1f0b-uuid',
        reason: 'the input map is not mutated');
  });

  test('withoutPoolId turns the pool ID into DEFAULT with a new UUID', () {
    final p = person('IND-1', [
      idf('NATIONAL_ID', 'N-1', ref: 'IDF-A'),
      idf(uniqueBeneficiaryIdType, 'SMC-0001', ref: 'IDF-B', tenant: 'ng'),
    ]);
    final out = withoutPoolId(p, identifierType: uniqueBeneficiaryIdType, uuid: 'new-uuid')!;

    expect(out.identifiers![0].identifierId, 'N-1');
    final id = out.identifiers![1];
    expect(id.identifierType, defaultIdentifierType);
    expect(id.identifierId, 'new-uuid');
    expect(id.clientReferenceId, 'IDF-B');
    expect(id.tenantId, 'ng');
  });

  test('withoutPoolId returns null when there is no pool ID to remove', () {
    expect(
        withoutPoolId(person('IND-1', [idf('DEFAULT', 'u')]),
            identifierType: uniqueBeneficiaryIdType, uuid: 'x'),
        isNull);
    expect(withoutPoolId(person('IND-1', null), identifierType: uniqueBeneficiaryIdType, uuid: 'x'),
        isNull);
  });
}
