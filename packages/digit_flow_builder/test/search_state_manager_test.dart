import 'package:digit_flow_builder/blocs/search_state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the SearchStateManager behaviors the National/Voter/Beneficiary/
/// Phone-Number ID search toggles on the Search Households screen rely on:
/// each toggle shares filter keys (identifierId, identifierType) across
/// several search bars, so replace-not-merge semantics and cross-searchName
/// clearing must hold or switching modes leaks stale filters into the next
/// search (see REGISTRATION.json's searchBeneficiary screen).
void main() {
  const screenKey = 'searchBeneficiary::test-instance';

  setUp(() {
    // SearchStateManager is a singleton; isolate each test's state.
    SearchStateManager().disposeAll();
  });

  group('updateFilters', () {
    test('replaces all filters for a searchName instead of merging', () {
      final manager = SearchStateManager();

      manager.updateFilters(
        screenKey,
        'identifier',
        [
          {'key': 'identifierId', 'value': '123', 'operation': 'contains'},
        ],
        triggerSearch: false,
      );

      // Switching from Beneficiary ID mode to National ID mode re-sends a
      // full new filter set for the same "identifier" searchName.
      manager.updateFilters(
        screenKey,
        'identifier',
        [
          {
            'key': 'identifierId',
            'value': '98765432109',
            'operation': 'equals'
          },
          {
            'key': 'identifierType',
            'value': 'NATIONAL_ID',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );

      final filters = manager.getFilters(screenKey, 'identifier');

      expect(filters, hasLength(2));
      expect(
        filters.map((f) => f['key']),
        containsAll(['identifierId', 'identifierType']),
      );
      // The stale Beneficiary-ID-mode value must be gone, not merged in.
      expect(
        filters.firstWhere((f) => f['key'] == 'identifierId')['value'],
        '98765432109',
      );
    });
  });

  group('removeFiltersByKeysForScreen', () {
    test(
        'purges identifierId/identifierType across every searchName for the screen',
        () {
      final manager = SearchStateManager();

      // "identifier" searchName holds the active ID-mode filters.
      manager.updateFilters(
        screenKey,
        'identifier',
        [
          {
            'key': 'identifierId',
            'value': '11111111111',
            'operation': 'equals'
          },
          {
            'key': 'identifierType',
            'value': 'NATIONAL_ID',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );
      // A different searchName also happens to carry an identifierType key
      // (e.g. a stray filter from another widget) - it must be purged too.
      manager.updateFilters(
        screenKey,
        'name',
        [
          {'key': 'givenName', 'value': 'John', 'operation': 'contains'},
          {
            'key': 'identifierType',
            'value': 'NATIONAL_ID',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );

      manager.removeFiltersByKeysForScreen(
        screenKey,
        ['identifierId', 'identifierType'],
        triggerSearch: false,
      );

      final identifierFilters = manager.getFilters(screenKey, 'identifier');
      final nameFilters = manager.getFilters(screenKey, 'name');

      expect(identifierFilters, isEmpty);
      expect(nameFilters.map((f) => f['key']), ['givenName']);
    });

    test('does not touch other screens', () {
      final manager = SearchStateManager();
      const otherScreenKey = 'otherScreen::test-instance';

      manager.updateFilters(
        screenKey,
        'identifier',
        [
          {
            'key': 'identifierId',
            'value': '11111111111',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );
      manager.updateFilters(
        otherScreenKey,
        'identifier',
        [
          {
            'key': 'identifierId',
            'value': '22222222222',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );

      manager.removeFiltersByKeysForScreen(
        screenKey,
        ['identifierId'],
        triggerSearch: false,
      );

      expect(manager.getFilters(screenKey, 'identifier'), isEmpty);
      expect(manager.getFilters(otherScreenKey, 'identifier'), hasLength(1));
    });
  });

  group('getAllFilters', () {
    test(
        'deduplicates by filter key across searchNames, never yielding duplicate identifierId entries',
        () {
      final manager = SearchStateManager();

      manager.updateFilters(
        screenKey,
        'identifier',
        [
          {
            'key': 'identifierId',
            'value': '11111111111',
            'operation': 'equals'
          },
          {
            'key': 'identifierType',
            'value': 'NATIONAL_ID',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );
      manager.updateFilters(
        screenKey,
        'address',
        [
          {
            'key': 'localityBoundaryCode',
            'value': 'SL_KAMBIA',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );

      final all = manager.getAllFilters(screenKey);
      final identifierIdEntries =
          all.where((f) => f['key'] == 'identifierId').toList();

      expect(identifierIdEntries, hasLength(1));
      expect(all, hasLength(3));
    });

    test('a later searchName update for the same key overrides the earlier one',
        () {
      final manager = SearchStateManager();

      manager.updateFilters(
        screenKey,
        'identifier',
        [
          {
            'key': 'localityBoundaryCode',
            'value': 'FIRST',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );
      manager.updateFilters(
        screenKey,
        'address',
        [
          {
            'key': 'localityBoundaryCode',
            'value': 'SECOND',
            'operation': 'equals'
          },
        ],
        triggerSearch: false,
      );

      final all = manager.getAllFilters(screenKey);
      expect(all, hasLength(1));
      expect(all.first['value'], 'SECOND');
    });
  });

  group('refreshScreen', () {
    test('invokes registered callbacks for the current screen instance only',
        () {
      final manager = SearchStateManager();
      var currentScreenRefreshes = 0;
      var otherScreenRefreshes = 0;

      manager.registerInstance('searchBeneficiary', 'test-instance');
      manager.registerInstance('otherScreen', 'test-instance');
      manager.registerSearchCallback(
        'searchBeneficiary',
        'name',
        () => currentScreenRefreshes++,
      );
      manager.registerSearchCallback(
        'otherScreen',
        'name',
        () => otherScreenRefreshes++,
      );

      expect(manager.refreshScreen('searchBeneficiary'), isTrue);
      expect(currentScreenRefreshes, 1);
      expect(otherScreenRefreshes, 0);
      expect(manager.refreshScreen('missingScreen'), isFalse);
    });
  });
}
