import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/clear_state_executor.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/blocs/search_state_manager.dart';
import 'package:digit_flow_builder/flow_builder.dart' show FlowRegistry;
import 'package:digit_flow_builder/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA (SL, 2026-11-18): search with "Search by National ID" on, then turn the
/// toggle off - the result cards stay. Same for the name and phone toggles.
///
/// The toggle's CLEAR_STATE removes the name/id/phone filters, but every
/// search also stores `localityBoundaryCode`, which is not in `filterKeys`.
/// The executor took that leftover as "filters remain" and fired a search
/// under the name `default`, for which the screen registers no callback - so
/// nothing ran and nothing emptied the list.
void main() {
  const compositeKey = 'searchBeneficiary::toggle-test';

  // The switch action exactly as the SL REGISTRATION config has it.
  ActionConfig toggleClear() => ActionConfig.fromJson({
        'actionType': 'CLEAR_STATE',
        'properties': {
          'filterKeys': [
            'givenName,familyName',
            'identifierId',
            'identifierType',
            'mobileNumber',
          ],
          'widgetKeys': [
            'searchBar',
            'idSearchBar',
            'nationalIdSearchBar',
            'phoneNumberSearchBar',
            'nameSearch',
            'beneficiaryIdSearch',
            'phoneNumberSearch',
          ],
          'triggerSearch': true,
        },
      });

  const boundaryFilter = {
    'key': 'localityBoundaryCode',
    'root': 'address',
    'value': 'B1',
    'operation': 'equals',
  };

  Future<void> runClear(
    WidgetTester tester,
    ActionConfig action, {
    String key = compositeKey,
  }) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      CrudItemContext(
        compositeKey: key,
        screenKey: key.split('::').first,
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await ClearStateExecutor().execute(action, ctx, <String, dynamic>{});
  }

  setUp(() {
    FlowRegistry.setConfig([
      {
        'name': 'searchBeneficiary',
        'wrapperConfig': {
          'searchConfig': {'primary': 'household'},
        },
      },
      {
        'name': 'complaintInbox',
        'wrapperConfig': {
          'searchConfig': {'primary': 'pgrService'},
        },
      },
    ]);
    SearchStateManager().disposeAll();
    FlowCrudStateRegistry().clearAll();
    FlowCrudStateRegistry().update(
      compositeKey,
      const FlowCrudState(
        stateWrapper: [
          {'HouseholdModel': 'stale result card'},
        ],
        widgetData: {
          'nationalIdSearch': false,
          'nationalIdSearchBar': 'AB123',
        },
      ),
    );
  });

  testWidgets(
      'toggle off after a national-id search empties the result list '
      '(only the boundary filter is left)', (tester) async {
    var searches = 0;
    SearchStateManager().updateFilters(
      compositeKey,
      'identifier',
      [
        {'key': 'identifierId', 'value': 'AB123', 'operation': 'equals'},
        {
          'key': 'identifierType',
          'value': ['NATIONAL_ID'],
          'operation': 'in',
        },
        boundaryFilter,
      ],
      triggerSearch: false,
    );
    SearchStateManager()
        .registerSearchCallback(compositeKey, 'identifier', () => searches++);

    await runClear(tester, toggleClear());

    final state = FlowCrudStateRegistry().get(compositeKey);
    expect(state?.stateWrapper, isEmpty,
        reason: 'stale cards must not stay on screen');
    expect(searches, 0,
        reason: 'a boundary-only search would list every household');
    expect(SearchStateManager().hasFiltersForScreen(compositeKey), isFalse,
        reason: 'a leftover boundary filter would let a scroll refresh '
            'list the whole boundary');
    expect(state?.widgetData?.containsKey('nationalIdSearchBar'), isFalse);
    expect(state?.widgetData?['nationalIdSearch'], false,
        reason: 'keys not listed in widgetKeys are kept');
  });

  testWidgets('same for the name and the phone searches', (tester) async {
    for (final entry in {
      'name': {
        'key': 'givenName,familyName',
        'value': 'ami',
        'operation': 'containsAll',
      },
      'phoneNumber': {
        'key': 'mobileNumber',
        'root': 'individual',
        'value': '23276000000',
        'operation': 'equals',
      },
    }.entries) {
      SearchStateManager().disposeAll();
      FlowCrudStateRegistry().update(
        compositeKey,
        const FlowCrudState(stateWrapper: [
          {'HouseholdModel': 'stale result card'},
        ], widgetData: {}),
      );
      var searches = 0;
      SearchStateManager().updateFilters(
        compositeKey,
        entry.key,
        [entry.value, boundaryFilter],
        triggerSearch: false,
      );
      SearchStateManager()
          .registerSearchCallback(compositeKey, entry.key, () => searches++);

      await runClear(tester, toggleClear());

      expect(FlowCrudStateRegistry().get(compositeKey)?.stateWrapper, isEmpty,
          reason: '${entry.key} search');
      expect(searches, 0, reason: '${entry.key} search');
    }
  });

  testWidgets(
      'with proximity search still on, the toggle re-runs the search '
      'instead of emptying the list', (tester) async {
    var proximitySearches = 0;
    var nameSearches = 0;
    SearchStateManager().updateFilters(
      compositeKey,
      'address',
      [
        {'key': '', 'root': 'address', 'value': 5, 'operation': 'within'},
        boundaryFilter,
      ],
      triggerSearch: false,
    );
    SearchStateManager().updateFilters(
      compositeKey,
      'name',
      [
        {
          'key': 'givenName,familyName',
          'value': 'ami',
          'operation': 'containsAll',
        },
        boundaryFilter,
      ],
      triggerSearch: false,
    );
    SearchStateManager().registerSearchCallback(
        compositeKey, 'address', () => proximitySearches++);
    SearchStateManager()
        .registerSearchCallback(compositeKey, 'name', () => nameSearches++);

    await runClear(tester, toggleClear());

    expect(proximitySearches + nameSearches, 1,
        reason: 'exactly one search with the remaining proximity filter');
    expect(
      FlowCrudStateRegistry().get(compositeKey)?.stateWrapper,
      isNotEmpty,
      reason: 'the list is replaced by the search result, not blanked first',
    );
  });

  testWidgets(
      'a clear that names its search and leaves user filters still re-runs '
      'that search (search bar path, unchanged)', (tester) async {
    var nameSearches = 0;
    SearchStateManager().updateFilters(
      compositeKey,
      'name',
      [
        {
          'key': 'givenName,familyName',
          'value': 'ami',
          'operation': 'containsAll',
        },
      ],
      triggerSearch: false,
    );
    SearchStateManager().updateFilters(
      compositeKey,
      'status',
      [
        {'key': 'status', 'value': 'CLOSED', 'operation': 'equals'},
      ],
      triggerSearch: false,
    );
    SearchStateManager()
        .registerSearchCallback(compositeKey, 'name', () => nameSearches++);

    await runClear(
      tester,
      ActionConfig.fromJson({
        'actionType': 'CLEAR_STATE',
        'properties': {
          'name': 'name',
          'filterKeys': ['givenName,familyName'],
          'triggerSearch': true,
        },
      }),
    );

    expect(nameSearches, 1);
    expect(
      FlowCrudStateRegistry().get(compositeKey)?.stateWrapper,
      isNotEmpty,
    );
  });

  testWidgets('without triggerSearch nothing is emptied or searched',
      (tester) async {
    var searches = 0;
    SearchStateManager().updateFilters(
      compositeKey,
      'identifier',
      [
        {'key': 'identifierId', 'value': 'AB123', 'operation': 'equals'},
        boundaryFilter,
      ],
      triggerSearch: false,
    );
    SearchStateManager()
        .registerSearchCallback(compositeKey, 'identifier', () => searches++);

    await runClear(
      tester,
      ActionConfig.fromJson({
        'actionType': 'CLEAR_STATE',
        'properties': {
          'filterKeys': ['identifierId'],
        },
      }),
    );

    expect(searches, 0);
    expect(
      FlowCrudStateRegistry().get(compositeKey)?.stateWrapper,
      isNotEmpty,
    );
  });

  testWidgets(
      'on a non-household screen the locality filter is the user\'s own: '
      'the list and the filter stay (complaints inbox)', (tester) async {
    const inbox = 'complaintInbox::toggle-test';
    FlowCrudStateRegistry().update(
      inbox,
      const FlowCrudState(stateWrapper: [
        {'PgrServiceModel': 'complaint card'},
      ], widgetData: {}),
    );
    SearchStateManager().updateFilters(
      inbox,
      'pgrService',
      [boundaryFilter],
      triggerSearch: false,
    );
    SearchStateManager().registerSearchCallback(inbox, 'pgrService', () {});

    await runClear(
      tester,
      ActionConfig.fromJson({
        'actionType': 'CLEAR_STATE',
        'properties': {
          'filterKeys': ['complaintNumber'],
          'triggerSearch': true,
        },
      }),
      key: inbox,
    );

    expect(FlowCrudStateRegistry().get(inbox)?.stateWrapper, isNotEmpty);
    expect(SearchStateManager().getAllFilters(inbox), hasLength(1));
  });
}
