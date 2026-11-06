// Regression tests for search-screen paging (Kaduna QA, 2026-11-06: after
// downloading data, a newly registered household could not be reached in
// proximity search).
//
// Cause: FlowCrudBloc advanced the paging window by wrapper items, while
// LIMIT/OFFSET runs on the primary model's DB rows. WrapperBuilder drops
// households with no active member (consent refused, deleted), so a page with
// one such household produced 4 cards < limit 5 -> hasMoreDown = false and
// scrolling stopped for good. Trimming the 15-item window also counted items,
// so scrolling back up could skip or repeat rows.
//
// These tests drive the REAL SearchExecutor (proximity switched on),
// RefreshSearchExecutor (each scroll), FlowCrudBloc + WrapperBuilder and
// SearchStateManager. Only the data source is faked: a CrudService that
// serves LIMIT/OFFSET pages from an in-memory list, so no database is needed.
import 'dart:math';

import 'package:digit_crud_bloc/bloc/crud_bloc.dart';
import 'package:digit_crud_bloc/models/global_search_params.dart';
import 'package:digit_crud_bloc/service/crud_service.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;
import 'package:digit_flow_builder/action_handler/executors/refresh_search_executor.dart';
import 'package:digit_flow_builder/action_handler/executors/search_executor.dart';
import 'package:digit_flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = 'searchBeneficiary';
const _instance = 'paging-test';
const _compositeKey = '$_screen::$_instance';
const _limit = 5;
const _maxItems = 15;

/// Serves pages of [households] (DB order) the way SearchEntityRepository
/// does: LIMIT/OFFSET on the primary model, plus related members.
class _PagedHouseholds extends CrudService {
  _PagedHouseholds(this.households, this.members) {
    init();
  }

  final List<HouseholdModel> households;
  final Map<String, List<HouseholdMemberModel>> members;

  @override
  Future<(Map<String, List<EntityModel>>, int)> searchEntities({
    required GlobalSearchParameters query,
  }) async {
    final p = query.pagination;
    final page = p == null
        ? households
        : households.skip(p.offset).take(p.limit).toList();
    final results = <String, List<EntityModel>>{'household': page};
    if (query.select.contains('householdMember')) {
      results['householdMember'] = [
        for (final h in page) ...?members[h.clientReferenceId],
      ];
    }
    return (results, households.length);
  }
}

/// searchBeneficiary as configured for Kaduna (wrapper filter + relations),
/// or the grouped shape the referral inbox uses.
Map<String, dynamic> _screenConfig({required bool grouped}) => {
      'name': _screen,
      'wrapperConfig': grouped
          ? {
              'rootEntity': 'HouseholdModel',
              'groupByType': true,
              'searchConfig': {
                'select': ['household'],
                'primary': 'household',
                'pagination': {'limit': _limit, 'maxItems': _maxItems},
              },
            }
          : {
              'rootEntity': 'HouseholdModel',
              'wrapperName': 'HouseholdWrapper',
              'filters': [
                {
                  'entity': 'HouseholdMemberModel',
                  'condition': {'field': 'isDeleted', 'equals': false},
                  'join': {
                    'sourceField': 'householdClientReferenceId',
                    'targetField': 'clientReferenceId',
                  },
                },
              ],
              'relations': [
                {
                  'name': 'members',
                  'match': {
                    'field': 'householdClientReferenceId',
                    'equalsFrom': 'clientReferenceId',
                  },
                  'entity': 'HouseholdMemberModel',
                },
              ],
              'searchConfig': {
                'select': [
                  'household',
                  'individual',
                  'householdMember',
                  'projectBeneficiary',
                  'task',
                ],
                'primary': 'household',
                'pagination': {'limit': _limit, 'maxItems': _maxItems},
              },
            },
      'scrollListener': {
        'triggerMode': 'bidirectional',
        'onScrollDown': [
          {
            'actionType': 'REFRESH_SEARCH',
            'properties': {
              'pagination': {'limit': _limit, 'maxItems': _maxItems},
            },
          },
        ],
      },
    };

class _Screen {
  _Screen(this.service, this.bloc, this.context);

  final _PagedHouseholds service;
  final FlowCrudBloc bloc;
  final BuildContext context;

  static Future<_Screen> mount(
    WidgetTester tester,
    _PagedHouseholds service, {
    bool grouped = false,
  }) async {
    final config = _screenConfig(grouped: grouped);
    FlowRegistry.setConfig([config]);
    FlowCrudStateRegistry().registerInstance(_screen, _instance);
    // Create the bloc in the real-async zone: a bloc built in the widget
    // test's fake-async zone only processes events when fake time is pumped.
    final bloc = (await tester.runAsync(() async => FlowCrudBloc(
          flowConfig: config,
          service: service,
          instanceId: _instance,
        )))!;
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<CrudBloc>.value(
        value: bloc,
        child: CrudItemContext(
          screenKey: _screen,
          compositeKey: _compositeKey,
          child: Builder(builder: (c) {
            captured = c;
            return const SizedBox();
          }),
        ),
      ),
    ));
    return _Screen(service, bloc, captured);
  }

  /// Runs one executor action; returns false when it loaded nothing.
  Future<bool> _run(
      Future<Map<String, dynamic>> Function(ActionConfig, BuildContext,
              Map<String, dynamic>)
          execute,
      Map<String, dynamic> json) async {
    final settled = bloc.stream
        .firstWhere((s) => s is CrudStateLoaded || s is CrudStateError)
        .timeout(const Duration(milliseconds: 300),
            onTimeout: () => const CrudState.initial());
    await execute(ActionConfig.fromJson(json), context, <String, dynamic>{});
    final state = await settled;
    if (state is CrudStateError) fail('search failed: ${state.message}');
    await Future<void>.delayed(Duration.zero);
    return state is CrudStateLoaded;
  }

  /// Proximity switched ON (SEARCH_EVENT with a `within` filter).
  Future<void> toggleProximityOn() => _run(SearchExecutor().execute, {
        'actionType': 'SEARCH_EVENT',
        'properties': {
          'name': 'address',
          'data': [
            {
              'key': 'proximitySearch',
              'value': 5,
              'lat': '10.52',
              'long': '7.44',
              'operation': 'within',
            },
          ],
        },
      });

  /// scrollListener onScrollDown / onScrollUp (REFRESH_SEARCH).
  Future<bool> scroll(String direction) => _run(RefreshSearchExecutor().execute, {
        'actionType': 'REFRESH_SEARCH',
        'properties': {
          'direction': direction,
          'pagination': {'limit': _limit, 'maxItems': _maxItems},
        },
      });

  /// Household ids held in the list window, in order.
  List<String> get windowIds {
    final wrapper =
        FlowCrudStateRegistry().getByCompositeKey(_compositeKey)?.stateWrapper ??
            const [];
    return wrapper.whereType<Map>().expand((w) {
      final v = w['HouseholdModel'];
      final list = v is List ? v : [v];
      return list.whereType<HouseholdModel>().map((h) => h.clientReferenceId);
    }).toList();
  }

  Future<void> dispose() async {
    await bloc.close();
    SearchStateManager().disposeAll();
    FlowCrudStateRegistry().disposeByCompositeKey(_compositeKey);
  }
}

/// [n] households in DB order; those at [hidden] have no member (consent
/// refused), so WrapperBuilder drops them.
_PagedHouseholds _data(int n, Set<int> hidden) {
  final households = <HouseholdModel>[];
  final members = <String, List<HouseholdMemberModel>>{};
  for (var i = 0; i < n; i++) {
    final id = 'hh-${i.toString().padLeft(3, '0')}';
    households.add(HouseholdModel(clientReferenceId: id, tenantId: 'kd'));
    if (!hidden.contains(i)) {
      members[id] = [
        HouseholdMemberModel(
          clientReferenceId: 'hm-$id',
          householdClientReferenceId: id,
          individualClientReferenceId: 'ind-$id',
          isHeadOfHousehold: true,
          tenantId: 'kd',
        ),
      ];
    }
  }
  return _PagedHouseholds(households, members);
}

class _Traversal {
  int missingGoingDown = 0;
  int gapWindows = 0;
  int dupWindows = 0;
  int downLoads = 0;
  int upLoads = 0;

  @override
  String toString() => 'missing=$missingGoingDown gaps=$gapWindows '
      'dups=$dupWindows down=$downLoads up=$upLoads';
}

/// Scrolls to the bottom, back to the top, and down again; checks that every
/// window is a gap-free, duplicate-free run of the visible households.
Future<_Traversal> _traverse(
  WidgetTester tester,
  int n,
  Set<int> hidden, {
  bool grouped = false,
}) async {
  final service = _data(n, grouped ? const {} : hidden);
  final screen = await _Screen.mount(tester, service, grouped: grouped);
  final result = _Traversal();
  await tester.runAsync(() async {
    final visible = [
      for (var i = 0; i < n; i++)
        if (grouped || !hidden.contains(i))
          'hh-${i.toString().padLeft(3, '0')}',
    ];
    final pos = {for (var i = 0; i < visible.length; i++) visible[i]: i};
    final windows = <List<String>>[];
    await screen.toggleProximityOn();
    windows.add(screen.windowIds);
    while (result.downLoads < 100 && await screen.scroll('down')) {
      result.downLoads++;
      windows.add(screen.windowIds);
    }
    final seenDown = windows.expand((w) => w).toSet();
    result.missingGoingDown = visible.where((id) => !seenDown.contains(id)).length;
    while (result.upLoads < 100 && await screen.scroll('up')) {
      result.upLoads++;
      windows.add(screen.windowIds);
    }
    for (var again = 0; again < 100 && await screen.scroll('down'); again++) {
      windows.add(screen.windowIds);
    }
    for (final w in windows) {
      if (w.toSet().length != w.length) result.dupWindows++;
      final idx = w.map((id) => pos[id] ?? -1).toList();
      for (var i = 1; i < idx.length; i++) {
        if (idx[i] != idx[i - 1] + 1) {
          result.gapWindows++;
          break;
        }
      }
    }
    await screen.dispose();
  });
  return result;
}

void main() {
  setUpAll(data_model_mappers.initializeMappers);

  testWidgets(
      'QA case: a hidden household on page 1 no longer stops scrolling; the '
      'household registered last is reached', (tester) async {
    // 13 households in the search area: #0 consent-refused (no member),
    // #12 the one the user just registered.
    final service = _data(13, {0});
    final screen = await _Screen.mount(tester, service);
    await tester.runAsync(() async {
      await screen.toggleProximityOn();
      expect(screen.windowIds, hasLength(4), reason: '5 rows, 1 hidden');
      var scrolls = 0;
      while (!screen.windowIds.contains('hh-012') &&
          scrolls < 10 &&
          await screen.scroll('down')) {
        scrolls++;
      }
      expect(screen.windowIds, contains('hh-012'));
      expect(scrolls, 2);
      await screen.dispose();
    });
  });

  testWidgets('a page with only hidden households does not stop scrolling',
      (tester) async {
    final service = _data(12, {5, 6, 7, 8, 9});
    final screen = await _Screen.mount(tester, service);
    await tester.runAsync(() async {
      await screen.toggleProximityOn();
      expect(await screen.scroll('down'), isTrue);
      expect(screen.windowIds, isNot(contains('hh-010')));
      expect(await screen.scroll('down'), isTrue);
      expect(screen.windowIds, containsAll(['hh-010', 'hh-011']));
      await screen.dispose();
    });
  });

  group('down -> up -> down: every window is a gap-free, duplicate-free run',
      () {
    testWidgets('30 households, none hidden', (tester) async {
      final r = await _traverse(tester, 30, const {});
      expect(r.missingGoingDown, 0, reason: '$r');
      expect(r.gapWindows, 0, reason: '$r');
      expect(r.dupWindows, 0, reason: '$r');
      expect(r.downLoads, 6, reason: '$r');
      expect(r.upLoads, 3, reason: '$r');
    });

    testWidgets('33 households, none hidden, partial last page',
        (tester) async {
      final r = await _traverse(tester, 33, const {});
      expect(r.missingGoingDown, 0, reason: '$r');
      expect(r.gapWindows, 0, reason: '$r');
      expect(r.dupWindows, 0, reason: '$r');
    });

    testWidgets('30 households, 3 hidden spread out', (tester) async {
      final r = await _traverse(tester, 30, const {2, 13, 24});
      expect(r.missingGoingDown, 0, reason: '$r');
      expect(r.gapWindows, 0, reason: '$r');
      expect(r.dupWindows, 0, reason: '$r');
    });

    testWidgets('20 random layouts (hidden first, last and in between)',
        (tester) async {
      for (var seed = 1; seed <= 20; seed++) {
        final rnd = Random(seed);
        final n = 21 + rnd.nextInt(48);
        final hidden = <int>{0, n - 1};
        while (hidden.length < 2 + rnd.nextInt(n ~/ 5)) {
          hidden.add(rnd.nextInt(n));
        }
        final r = await _traverse(tester, n, hidden);
        expect(r.missingGoingDown, 0, reason: 'seed $seed n=$n $r');
        expect(r.gapWindows, 0, reason: 'seed $seed n=$n $r');
        expect(r.dupWindows, 0, reason: 'seed $seed n=$n $r');
      }
    });

    testWidgets('grouped screen (referral-inbox shape), partial last page',
        (tester) async {
      final r = await _traverse(tester, 33, const {}, grouped: true);
      expect(r.missingGoingDown, 0, reason: '$r');
      expect(r.gapWindows, 0, reason: '$r');
      expect(r.dupWindows, 0, reason: '$r');
    });
  });

  group('SearchStateManager', () {
    const key = 'unit::1';
    tearDown(SearchStateManager().disposeAll);

    test('loadUpLimit never fetches past the window start', () {
      final m = SearchStateManager()
        ..initPaginationWindow(key, '_pagination', limit: 5, maxItems: 15);
      m.setWindowOffsetsByCompositeKey(key, '_pagination', startOffset: 3);
      expect(m.loadUpLimit(key, '_pagination', offset: 0, limit: 5), 3);
      m.setWindowOffsetsByCompositeKey(key, '_pagination', startOffset: 10);
      expect(m.loadUpLimit(key, '_pagination', offset: 5, limit: 5), 5);
      m.setWindowOffsetsByCompositeKey(key, '_pagination', startOffset: 12);
      expect(m.loadUpLimit(key, '_pagination', offset: 7, limit: 5), 5);
    });

    test('setWindowOffsetsByCompositeKey sets offsets and hasMoreUp', () {
      final m = SearchStateManager()
        ..initPaginationWindow(key, '_pagination', limit: 5, maxItems: 15);
      m.setWindowOffsetsByCompositeKey(key, '_pagination',
          startOffset: 7, endOffset: 22);
      final w = m.getPaginationWindow(key, '_pagination')!;
      expect(w.startOffset, 7);
      expect(w.endOffset, 22);
      expect(w.hasMoreUp, isTrue);
      m.setWindowOffsetsByCompositeKey(key, '_pagination', startOffset: 0);
      expect(m.getPaginationWindow(key, '_pagination')!.hasMoreUp, isFalse);
    });
  });
}
