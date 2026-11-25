import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/utils/typedefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/app_initialization/app_initialization.dart';
import 'package:health_campaign_field_worker_app/blocs/auth/auth.dart';
import 'package:health_campaign_field_worker_app/blocs/hf_referral_downsync/hf_referral_downsync.dart';
import 'package:health_campaign_field_worker_app/blocs/localization/app_localization.dart';
import 'package:health_campaign_field_worker_app/blocs/localization/localization.dart';
import 'package:health_campaign_field_worker_app/blocs/project/project.dart';
import 'package:health_campaign_field_worker_app/blocs/projects_beneficiary_downsync/project_beneficiaries_downsync.dart';
import 'package:health_campaign_field_worker_app/data/local_store/app_shared_preferences.dart';
import 'package:health_campaign_field_worker_app/data/local_store/no_sql/schema/app_configuration.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/models/role_actions/role_actions_model.dart';
import 'package:health_campaign_field_worker_app/pages/boundary_selection.dart';
import 'package:health_campaign_field_worker_app/utils/app_theme.dart';
import 'package:health_campaign_field_worker_app/utils/environment_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_service/blocs/sync/sync.dart';

class _Repo extends Mock implements BoundaryDataRepository {}

class _FakeSearch extends Fake implements BoundarySearchModel {}

class _Sql extends Mock implements LocalSqlDataStore {}

class _Auth extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _Project extends MockBloc<ProjectEvent, ProjectState>
    implements ProjectBloc {}

class _Sync extends MockBloc<SyncEvent, SyncState> implements SyncBloc {}

class _DownSync
    extends MockBloc<BeneficiaryDownSyncEvent, BeneficiaryDownSyncState>
    implements BeneficiaryDownSyncBloc {}

class _HfDownSync
    extends MockBloc<HFReferralDownSyncEvent, HFReferralDownSyncState>
    implements HFReferralDownSyncBloc {}

class _AppInit extends MockBloc<AppInitializationEvent, AppInitializationState>
    implements AppInitializationBloc {}

class _Localization extends MockBloc<LocalizationEvent, LocalizationState>
    implements LocalizationBloc {}

/// QA (Liberia): the District dropdown froze 15-20 s after a selection because
/// the page asked for a full text reload on every BoundaryBloc state.
/// This mounts the real page and counts the reloads it asks for.
void main() {
  final district = BoundaryModel(
      code: 'D1', label: 'District', boundaryNum: 2, materializedPath: 'C.D1');
  final facility = BoundaryModel(
      code: 'F1',
      label: 'Health Facility',
      boundaryNum: 3,
      materializedPath: 'C.D1.F1');

  setUpAll(() async {
    registerFallbackValue(_FakeSearch());
    registerFallbackValue(const LocalizationEvent.onUpdateLocalizationIndex(
        index: 0, code: 'en_LR'));
    SharedPreferences.setMockInitialValues(
        {AppSharedPreferences.userSelectedLocale: 'en_LR'});
    await AppSharedPreferences().init();
    await envConfig.initialize();
  });

  testWidgets(
      'the page asks for one text reload on entry and none after a selection',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final auth = _Auth();
    whenListen(auth, const Stream<AuthState>.empty(),
        initialState: const AuthState.authenticated(
          accessToken: 'a',
          refreshToken: 'r',
          userModel: UserRequestModel(
              uuid: 'u1', roles: [UserRoleModel(code: 'SUPERVISOR')]),
          actionsWrapper: RoleActionsWrapperModel(),
        ));
    final project = _Project();
    whenListen(project, const Stream<ProjectState>.empty(),
        initialState: const ProjectState());
    final sync = _Sync();
    whenListen(sync, const Stream<SyncState>.empty(),
        initialState: const SyncState.loading());
    final downSync = _DownSync();
    whenListen(downSync, const Stream<BeneficiaryDownSyncState>.empty(),
        initialState: const BeneficiaryDownSyncState.resetState());
    final hfDownSync = _HfDownSync();
    whenListen(hfDownSync, const Stream<HFReferralDownSyncState>.empty(),
        initialState: const HFReferralDownSyncState.resetState());
    final appInit = _AppInit();
    whenListen(appInit, const Stream<AppInitializationState>.empty(),
        initialState: AppInitializationState.initialized(
          appConfiguration: AppConfiguration()
            ..boundaryLastLevelMaxSelection = 1
            ..languages = [
              Languages()
                ..label = 'English'
                ..value = 'en_LR'
            ],
        ));
    final localization = _Localization();
    whenListen(localization, const Stream<LocalizationState>.empty(),
        initialState: const LocalizationState());

    final repo = _Repo();
    // Held open so the page shows its spinner and then builds the form again,
    // as it does on a phone.
    final searchDone = Completer<List<BoundaryModel>>();
    when(() => repo.search(any())).thenAnswer((_) => searchDone.future);
    late BoundaryBloc boundary;
    // A bloc created in the fake-async zone only runs when time is pumped.
    await tester.runAsync(() async {
      boundary = BoundaryBloc(
        BoundaryState(
          boundaryList: [district],
          selectedBoundaryMap: const {
            'District': null,
            'Health Facility': null
          },
        ),
        boundaryRepository: repo,
      );
    });
    addTearDown(boundary.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<ProjectBloc>.value(value: project),
        BlocProvider<SyncBloc>.value(value: sync),
        BlocProvider<BeneficiaryDownSyncBloc>.value(value: downSync),
        BlocProvider<HFReferralDownSyncBloc>.value(value: hfDownSync),
        BlocProvider<AppInitializationBloc>.value(value: appInit),
        BlocProvider<LocalizationBloc>.value(value: localization),
        BlocProvider<BoundaryBloc>.value(value: boundary),
      ],
      child: MaterialApp(
        theme: appLightTheme,
        home: BoundarySelectionPage(
          appLocalizations: AppLocalizations(const Locale('en', 'LR'), _Sql()),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    int reloads() => verify(() => localization
            .add(any(that: isA<OnUpdateLocalizationIndexEvent>())))
        .callCount;

    expect(find.byType(ReactiveFormBuilder), findsOneWidget);
    expect(reloads(), 1, reason: 'one reload when the page opens');

    // The three events DigitDropdown.onSelect adds for a District selection.
    await tester.runAsync(() async {
      boundary
        ..add(const BoundarySearchEvent(code: 'D1', boundaryNum: 2))
        ..add(BoundarySelectEvent(label: 'District', selectedBoundary: district))
        ..add(const BoundaryMultiSelectEvent(
            label: 'Health Facility', selectedBoundaries: []));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ReactiveFormBuilder), findsNothing,
        reason: 'the spinner replaces the form while the search runs');

    await tester.runAsync(() async {
      searchDone.complete([facility]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ReactiveFormBuilder), findsOneWidget,
        reason: 'the form is built again after the search');

    expect(boundary.state.selectedBoundaryMap['District'], district);
    expect(boundary.state.boundaryList, contains(facility));
    verifyNever(() =>
        localization.add(any(that: isA<OnUpdateLocalizationIndexEvent>())));

    // Let the dropdown's visibility-detector timer (500 ms) finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
