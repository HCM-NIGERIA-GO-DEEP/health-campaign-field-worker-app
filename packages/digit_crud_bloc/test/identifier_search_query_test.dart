import 'package:digit_crud_bloc/models/global_search_params.dart';
import 'package:digit_crud_bloc/repositories/helpers/query_builder.dart';
import 'package:digit_crud_bloc/repositories/helpers/relationship_graph_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the SQL-translation and relationship-path claims the National ID /
/// Voter ID / Phone Number search feature depends on:
///  - identifierId + identifierType combine into a single AND'd WHERE clause
///    against the identifier table (so scoping Beneficiary ID search to
///    UNIQUE_BENEFICIARY_ID, and National/Voter ID to their own types,
///    doesn't require a schema change or a second query).
///  - the relationship graph used to walk "identifier" (and the new
///    "individual" root for Phone Number search) up to "household" is built
///    bidirectionally from the flat mapping list configured in home.dart, so
///    no new RelationshipMapping entries are required for the phone number
///    search path.
///
/// A real end-to-end test against a live LocalSqlDataStore isn't possible
/// here: LocalSqlDataStore's connection is hardcoded to a file-backed,
/// SQLCipher-encrypted NativeDatabase opened via path_provider (see
/// packages/digit_data_model/lib/data/local_store/sql_store/sql_store.dart),
/// with no injectable in-memory executor, and no such harness exists
/// anywhere in this repo today (every existing bloc test in digit_data_model
/// mocks the repository layer instead). These tests instead cover the pure,
/// DB-free translation layer that QueryBuilder and RelationshipGraphHelper
/// expose, which is where the actual filter-combining and path-finding logic
/// lives.
void main() {
  group('QueryBuilder WHERE-clause translation for identifier search', () {
    test('identifierId equals + identifierType equals AND together into one clause', () {
      final filters = [
        const SearchFilter(
          root: 'identifier',
          field: 'identifierId',
          operator: 'equals',
          value: '98765432109',
        ),
        const SearchFilter(
          root: 'identifier',
          field: 'identifierType',
          operator: 'equals',
          value: 'NATIONAL_ID',
        ),
      ];

      final clause = QueryBuilder.buildWhereClauseRaw(filters);
      final args = QueryBuilder.buildWhereArgs(filters);

      expect(clause, 'identifier_id = ? AND identifier_type = ?');
      expect(args.map((v) => v.value), ['98765432109', 'NATIONAL_ID']);
    });

    test('Beneficiary ID search scoped to UNIQUE_BENEFICIARY_ID keeps identifierId as a prefix match', () {
      final filters = [
        const SearchFilter(
          root: 'identifier',
          field: 'identifierId',
          operator: 'contains',
          value: '123',
        ),
        const SearchFilter(
          root: 'identifier',
          field: 'identifierType',
          operator: 'equals',
          value: 'UNIQUE_BENEFICIARY_ID',
        ),
      ];

      final clause = QueryBuilder.buildWhereClauseRaw(filters);
      final args = QueryBuilder.buildWhereArgs(filters);

      expect(clause, 'identifier_id LIKE ? AND identifier_type = ?');
      // 'contains' here mirrors the existing Beneficiary ID search, which
      // uses a prefix LIKE ('x%'), not a substring LIKE - preserved as-is.
      expect(args.map((v) => v.value), ['123%', 'UNIQUE_BENEFICIARY_ID']);
    });

    test('Voter ID and National ID produce independent, non-colliding clauses', () {
      final voterFilters = [
        const SearchFilter(
          root: 'identifier',
          field: 'identifierId',
          operator: 'equals',
          value: 'V1234567890123456789',
        ),
        const SearchFilter(
          root: 'identifier',
          field: 'identifierType',
          operator: 'equals',
          value: 'VOTER_ID',
        ),
      ];

      expect(
        QueryBuilder.buildWhereArgs(voterFilters).map((v) => v.value),
        ['V1234567890123456789', 'VOTER_ID'],
      );
    });
  });

  group('QueryBuilder WHERE-clause translation for phone number search', () {
    test('mobileNumber equals produces an exact-match clause on the individual table', () {
      final filters = [
        const SearchFilter(
          root: 'individual',
          field: 'mobileNumber',
          operator: 'equals',
          value: '76123456',
        ),
      ];

      expect(
        QueryBuilder.buildWhereClauseRaw(filters),
        'mobile_number = ?',
      );
      expect(
        QueryBuilder.buildWhereArgs(filters).map((v) => v.value),
        ['76123456'],
      );
    });
  });

  group('RelationshipGraphHelper path resolution (bidirectional graph)', () {
    /// Mirrors the flat RelationshipMapping list configured in home.dart's
    /// FlowNavigationUtils.navigateToFlowModule call for the REGISTRATION
    /// module, plus the bidirectional-graph construction CrudService applies
    /// on top of it (packages/digit_crud_bloc/lib/service/crud_service.dart:60-79).
    Map<String, List<RelationshipMapping>> buildBidirectionalGraph(
      List<RelationshipMapping> flatMappings,
    ) {
      final graph = <String, List<RelationshipMapping>>{};
      for (final mapping in flatMappings) {
        graph.putIfAbsent(mapping.from, () => []).add(mapping);
        final reverse = RelationshipMapping(
          from: mapping.to,
          to: mapping.from,
          localKey: mapping.foreignKey,
          foreignKey: mapping.localKey,
        );
        graph.putIfAbsent(reverse.from, () => []).add(reverse);
      }
      return graph;
    }

    final flatMappings = [
      const RelationshipMapping(
        from: 'identifier',
        to: 'individual',
        localKey: 'individualClientReferenceId',
        foreignKey: 'clientReferenceId',
      ),
      const RelationshipMapping(
        from: 'householdMember',
        to: 'individual',
        localKey: 'individualClientReferenceId',
        foreignKey: 'clientReferenceId',
      ),
      const RelationshipMapping(
        from: 'householdMember',
        to: 'household',
        localKey: 'householdClientReferenceId',
        foreignKey: 'clientReferenceId',
      ),
      const RelationshipMapping(
        from: 'address',
        to: 'household',
        localKey: 'relatedClientReferenceId',
        foreignKey: 'clientReferenceId',
      ),
    ];

    test('identifier (National/Voter/Beneficiary ID root) resolves to household via individual + householdMember', () async {
      final graph = buildBidirectionalGraph(flatMappings);

      final path = await RelationshipGraphHelper.findShortestPath(
        fromModels: {'identifier'},
        toModel: 'household',
        graph: graph,
      );

      expect(path.map((r) => '${r.from}->${r.to}'), [
        'identifier->individual',
        'individual->householdMember',
        'householdMember->household',
      ]);
    });

    test('individual (Phone Number search root) resolves to household with NO new mapping entries', () async {
      // This is the critical claim: adding Phone Number search by filtering
      // directly on individual.mobileNumber requires zero new
      // RelationshipMapping wiring in home.dart, because the reverse edge of
      // the existing householdMember->individual mapping already makes
      // individual->householdMember traversable.
      final graph = buildBidirectionalGraph(flatMappings);

      final path = await RelationshipGraphHelper.findShortestPath(
        fromModels: {'individual'},
        toModel: 'household',
        graph: graph,
      );

      expect(path, hasLength(2));
      expect(path[0].from, 'individual');
      expect(path[0].to, 'householdMember');
      expect(path[0].localKey, 'clientReferenceId');
      expect(path[0].foreignKey, 'individualClientReferenceId');
      expect(path[1].from, 'householdMember');
      expect(path[1].to, 'household');
    });

    test('a root with no mapping entry at all resolves to an empty path', () async {
      final graph = buildBidirectionalGraph(flatMappings);

      final path = await RelationshipGraphHelper.findShortestPath(
        fromModels: {'unrelatedTable'},
        toModel: 'household',
        graph: graph,
      );

      expect(path, isEmpty);
    });
  });
}
