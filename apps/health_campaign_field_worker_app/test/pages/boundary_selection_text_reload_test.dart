import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/utils/typedefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements BoundaryDataRepository {}

class _FakeSearch extends Fake implements BoundarySearchModel {}

/// QA (Liberia): after picking a District the dropdown froze for 15-20 s, and
/// Submit showed no loader. The boundary page asked for a full text reload
/// (every localization row, read on the UI thread, then a MaterialApp rebuild)
/// on every BoundaryBloc state and every down-sync state.
void main() {
  setUpAll(() => registerFallbackValue(_FakeSearch()));

  test('one dropdown selection makes BoundaryBloc emit 3 states with a list',
      () async {
    final district = BoundaryModel(
        code: 'D1', label: 'District', boundaryNum: 2, materializedPath: 'C.D1');
    final child = BoundaryModel(
        code: 'F1',
        label: 'Health Facility',
        boundaryNum: 3,
        materializedPath: 'C.D1.F1');
    final repo = _Repo();
    when(() => repo.search(any())).thenAnswer((_) async => [child]);
    final bloc = BoundaryBloc(
      BoundaryState(
        boundaryList: [district],
        selectedBoundaryMap: const {'District': null, 'Health Facility': null},
      ),
      boundaryRepository: repo,
    );
    // What the old page listener counted: states with a non-empty list.
    var statesWithList = 0;
    final sub = bloc.stream.listen((s) {
      if (s.boundaryList.isNotEmpty) statesWithList++;
    });

    // The three events the page adds in DigitDropdown.onSelect.
    bloc
      ..add(const BoundarySearchEvent(code: 'D1', boundaryNum: 2))
      ..add(BoundarySelectEvent(label: 'District', selectedBoundary: district))
      ..add(const BoundaryMultiSelectEvent(
          label: 'Health Facility', selectedBoundaries: []));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    await bloc.close();

    expect(statesWithList, 3);
  });

  group('boundary_selection.dart text reloads', () {
    const reload = 'onUpdateLocalizationIndex';
    late String source;

    String between(String from, String to) {
      final start = source.indexOf(from);
      final end = source.indexOf(to, start);
      expect(start, greaterThanOrEqualTo(0), reason: 'missing "$from"');
      expect(end, greaterThan(start), reason: 'missing "$to"');
      return source.substring(start, end);
    }

    setUpAll(() {
      source = File(
              '${Directory.current.path}/lib/pages/boundary_selection.dart')
          .readAsStringSync();
    });

    test('the BoundaryBloc listener asks for no reload', () {
      expect(
        between('BlocListener<BoundaryBloc, BoundaryState>(',
            'child: ReactiveFormBuilder('),
        isNot(contains(reload)),
      );
    });

    test('the down-sync listener asks for no reload', () {
      expect(
        between('BlocListener<BeneficiaryDownSyncBloc,', 'child: DigitCard('),
        isNot(contains(reload)),
      );
    });

    test('only entry (once) and Submit ask for a reload', () {
      expect(reload.allMatches(source).length, 2);
      expect(
        between('FormGroup buildForm(', 'for (int i = 0;'),
        allOf(contains('if (!_textsReloaded)'), contains(reload)),
      );
      expect(
        between('await runWithOverlayLoader(', 'if (isOnline &&'),
        allOf(contains(reload), contains("'boundary', true"),
            contains('void reloadTexts()')),
      );
    });

    test('Submit reloads in the two download branches, not on the way to Home',
        () {
      const call = 'reloadTexts();';
      expect(call.allMatches(source).length, 2);
      expect(
        between('isDistributor) {', 'DownSyncGetBatchSizeEvent('),
        contains(call),
      );
      expect(
        between('isHealthFacilityWorkerOnly) {', 'HFReferralDownSyncStartEvent('),
        contains(call),
      );
      // Home reloads the texts itself on entry.
      expect(
        between('HFReferralDownSyncStartEvent(', 'HomeRoute()'),
        isNot(contains(call)),
      );
    });

    // The loader itself is tested at runtime in
    // boundary_selection_loader_test.dart.
    test('Submit runs the connection check under the overlay loader', () {
      expect(
        between('const BoundarySubmitEvent()', 'if (isOnline &&')
            .replaceAll(RegExp(r'\s+'), ''),
        contains('awaitrunWithOverlayLoader(context,getIsConnected)'),
      );
    });
  });
}
