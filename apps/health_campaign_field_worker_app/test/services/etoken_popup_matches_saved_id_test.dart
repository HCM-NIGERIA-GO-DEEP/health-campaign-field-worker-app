import 'package:bloc_test/bloc_test.dart';
import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/auth/auth.dart';
import 'package:health_campaign_field_worker_app/data/local_store/app_shared_preferences.dart';
import 'package:health_campaign_field_worker_app/executors/load_unique_id_pool_executor.dart';
import 'package:health_campaign_field_worker_app/executors/update_identifier_status_executor.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/models/entities/roles_type.dart';
import 'package:health_campaign_field_worker_app/models/role_actions/role_actions_model.dart';
import 'package:health_campaign_field_worker_app/services/beneficiary_id_service.dart';
import 'package:health_campaign_field_worker_app/utils/environment_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Household details popup shows `beneficiaryId` from the next page's
/// navigation params, which the page interceptor (screen_builder.dart,
/// householdDetails -> registrationHealthTalkChecklist) takes from a
/// LOAD_UNIQUE_ID_POOL {allocate: true, silent: true} call. The HOUSEHOLD
/// flow's final onAction runs LOAD_UNIQUE_ID_POOL {allocate: true} again and
/// the transformer saves whatever that call leaves in
/// formData.householdDetails.identifiers. These tests run the real executor
/// with the inputs both call sites pass, to prove the two agree and that no
/// e-token is handed to two households.
class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MemoryPool extends Fake
    implements LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> {
  final rows = <String, UniqueIdPoolModel>{};

  @override
  Future<List<UniqueIdPoolModel>> search(UniqueIdPoolSearchModel query) async =>
      rows.values
          .where((r) =>
              (query.id == null || r.id == query.id) &&
              (query.userUuid == null || r.userUuid == query.userUuid) &&
              (query.status == null || r.status == query.status))
          .toList();

  @override
  Future<void> update(UniqueIdPoolModel entity,
      {bool createOpLog = true,
      DataOperation dataOperation = DataOperation.update}) async {
    rows[entity.id] = entity;
  }
}

class _MemoryBoundaries extends Fake
    implements LocalRepository<BoundaryModel, BoundarySearchModel> {
  final rows = [
    BoundaryModel(
        code: 'COMMUNITY',
        name: 'Community',
        label: 'Community',
        materializedPath: 'COUNTRY.DP.COMMUNITY'),
    BoundaryModel(
        code: 'DP',
        name: 'Yebaya MCHP',
        label: 'Distribution Point',
        materializedPath: 'COUNTRY.DP'),
  ];

  @override
  Future<List<BoundaryModel>> search(BoundarySearchModel query) async =>
      rows.where((r) => r.code == query.codes).toList();
}

const _user = 'registrar';
const _project = 'campaign';
const _prefix = '0042';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MemoryPool pool;
  late _MemoryBoundaries boundaries;
  late String tenant;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSharedPreferences().init();
    await envConfig.initialize();
    tenant = envConfig.variables.tenantId;
  });

  setUp(() async {
    pool = _MemoryPool();
    boundaries = _MemoryBoundaries();
    FlowBuilderSingleton().setInitialData(
        loggedInUserUuid: _user,
        maxRadius: 0,
        projectId: _project,
        selectedBeneficiaryType: BeneficiaryType.household,
        projectType: null,
        selectedProject:
            ProjectModel(id: _project, name: 'Campaign', tenantId: tenant),
        loggedInUser: null);
    FlowBuilderSingleton().setBoundary(boundary: boundaries.rows.first);
    // A cached numeric prefix means prepare() never calls the prefix API.
    await AppSharedPreferences().setBoundaryNumericId(
        '${envConfig.variables.baseUrl}|$tenant|$_project', 'DP', _prefix);
    for (var i = 1; i <= 4; i++) {
      final row = UniqueIdPoolModel(
          id: 'raw$i',
          status: IdStatus.unAssigned.toValue(),
          deviceUuid: 'device',
          userUuid: _user,
          tenantId: tenant,
          auditDetails: AuditDetails(createdBy: _user, createdTime: i));
      pool.rows[row.id] = row.copyWith(
          additionalFields: BeneficiaryIdService.metadata(
              row, {'beneficiaryIdSource': BeneficiaryIdService.serverSource}));
    }
  });

  Future<BuildContext> pumpApp(WidgetTester tester) async {
    final auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(AuthState.authenticated(
      accessToken: 'token',
      refreshToken: 'refresh',
      userModel: UserRequestModel(
          uuid: _user,
          roles: [UserRoleModel(code: RolesType.registrar.toValue())]),
      actionsWrapper: const RoleActionsWrapperModel(),
    ));
    late BuildContext context;
    // No CrudItemContext anywhere above, as for the HOUSEHOLD form screen and
    // its pushed form pages: both call sites fall back to _compositeKey.
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<
              LocalRepository<UniqueIdPoolModel,
                  UniqueIdPoolSearchModel>>.value(value: pool),
          RepositoryProvider<
                  LocalRepository<BoundaryModel, BoundarySearchModel>>.value(
              value: boundaries),
        ],
        child: MaterialApp(home: Scaffold(body: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }))),
      ),
    ));
    return context;
  }

  ActionConfig poolAction(Map<String, dynamic> properties) => ActionConfig(
      action: 'LOAD_UNIQUE_ID_POOL',
      actionType: 'LOAD_UNIQUE_ID_POOL',
      properties: properties);

  /// Search screen's Register button: the not-yet-reserved preview ID that
  /// reaches the form as navigation UNIQUE_BENEFICIARY_ID.
  Future<String> previewId(WidgetTester tester, BuildContext context) async {
    final result = (await tester.runAsync(() => LoadUniqueIdPoolExecutor()
        .execute(poolAction({'requireAvailable': true}), context,
            {'_compositeKey': 'searchBeneficiary::search_1'})))!;
    return result['latestBeneficiaryId'] as String;
  }

  /// screen_builder.dart's householdDetails -> checklist interceptor; its
  /// latestBeneficiaryId becomes the popup's {{navigation.beneficiaryId}}.
  Future<String> popupToken(WidgetTester tester, BuildContext context,
      String formKey, Map<String, dynamic> navigation, String preview) async {
    final result = (await tester.runAsync(() => LoadUniqueIdPoolExecutor()
            .execute(poolAction({'allocate': true, 'silent': true}), context, {
          'formData': {
            'householdDetails': {
              'memberCount': 3,
              'identifiers': 'UNIQUE_BENEFICIARY_ID,$preview',
            },
          },
          'navigation': navigation,
          '_compositeKey': formKey,
        })))!;
    expect(result['haltActionChain'], isNot(true));
    return result['latestBeneficiaryId'] as String;
  }

  /// The HOUSEHOLD flow's final onAction: the formData it hands on is what
  /// FETCH_TRANSFORMER_CONFIG maps into the head's identifiers.
  Future<Map<String, dynamic>> submit(
      WidgetTester tester,
      BuildContext context,
      String formKey,
      Map<String, dynamic> navigation,
      String preview) async {
    final result = (await tester.runAsync(() => LoadUniqueIdPoolExecutor()
            .execute(poolAction({'allocate': true, 'stopOnError': true}), context, {
          'formData': {
            'householdDetails': {
              'memberCount': 3,
              'identifiers': 'UNIQUE_BENEFICIARY_ID,$preview',
            },
            'registrationHealthTalkChecklist': {'ACTION1': true},
          },
          'navigation': navigation,
          '_compositeKey': formKey,
        })))!;
    expect(result['haltActionChain'], isNot(true));
    return Map<String, dynamic>.from(result['formData'] as Map);
  }

  /// UPDATE_IDENTIFIER_STATUS after CREATE_EVENT, on the saved head.
  Future<void> markSaved(WidgetTester tester, BuildContext context,
      List<Map<String, dynamic>> entries) async {
    final headId = 'head-${entries.first['identifierId']}';
    final head = IndividualModel(
        clientReferenceId: headId,
        tenantId: tenant,
        identifiers: [
          for (final e in entries)
            IdentifierModel(
                clientReferenceId: 'id-${e['identifierId']}',
                individualClientReferenceId: headId,
                identifierType: e['identifierType'] as String?,
                identifierId: e['identifierId'] as String?),
        ]);
    await tester.runAsync(() => UpdateIdentifierStatusExecutor().execute(
            ActionConfig(
                action: 'UPDATE_IDENTIFIER_STATUS',
                actionType: 'UPDATE_IDENTIFIER_STATUS',
                properties: {'identifierType': 'UNIQUE_BENEFICIARY_ID'}),
            context, {
          'entities': [head]
        }));
  }

  List<Map<String, dynamic>> savedIdentifiers(Map<String, dynamic> formData) =>
      TransformerExecutor.buildIdentifierEntries(
              formData, FormEntityMapper(config: {}))
          .where((e) => e['identifierType'] == 'UNIQUE_BENEFICIARY_ID')
          .toList();

  String rawIdOf(String token) => pool.rows.values
      .singleWhere((r) =>
          BeneficiaryIdService.field(r, 'composedBeneficiaryId') == token)
      .id;

  final newRegistration = <String, dynamic>{
    'nameOfIndividual': 'Fatu',
    'deferFormRoutePop': 'true',
  };

  testWidgets(
      'the popup e-token is the one the final submit maps to the head and marks assigned',
      (tester) async {
    final context = await pumpApp(tester);
    const form = 'HOUSEHOLD::HOUSEHOLD_1731220000001';
    final preview = await previewId(tester, context);
    final nav = {...newRegistration, 'UNIQUE_BENEFICIARY_ID': preview};

    // Another form reserves the preview's row first, so this form's hidden
    // identifiers field (the preview) and its e-token differ - the save must
    // follow the e-token, not the field.
    final other = await popupToken(tester, context,
        'HOUSEHOLD::HOUSEHOLD_1731220000002', nav, preview);
    expect(other, preview);

    final shown = await popupToken(tester, context, form, nav, preview);
    expect(shown, startsWith('${_prefix}_raw'));
    expect(shown, isNot(preview));

    // And one more form reserves a row before this one submits.
    await popupToken(tester, context, 'HOUSEHOLD::HOUSEHOLD_1731220000008',
        nav, preview);

    final formData = await submit(tester, context, form, nav, preview);
    final saved = savedIdentifiers(formData);
    expect(saved, hasLength(1));
    expect(saved.single['identifierId'], shown);
    expect((formData['householdDetails'] as Map)['identifiers'],
        'UNIQUE_BENEFICIARY_ID,$shown');

    await markSaved(tester, context, saved);
    expect(pool.rows[rawIdOf(shown)]!.status, IdStatus.assigned.toValue());
  });

  testWidgets(
      'Cancel then Next again shows the same e-token and holds only one row',
      (tester) async {
    final context = await pumpApp(tester);
    const form = 'HOUSEHOLD::HOUSEHOLD_1731220000003';
    final preview = await previewId(tester, context);
    final nav = {...newRegistration, 'UNIQUE_BENEFICIARY_ID': preview};

    final first = await popupToken(tester, context, form, nav, preview);
    final again = await popupToken(tester, context, form, nav, preview);
    final third = await popupToken(tester, context, form, nav, preview);

    expect(again, first);
    expect(third, first);
    final reserved = pool.rows.values
        .where((r) => BeneficiaryIdService.field(r, 'reservedFor') != null);
    expect(reserved.map((r) => r.id), [rawIdOf(first)]);
  });

  testWidgets(
      'households never share an e-token, and a saved one is never offered again',
      (tester) async {
    final context = await pumpApp(tester);
    final preview = await previewId(tester, context);
    final nav = {...newRegistration, 'UNIQUE_BENEFICIARY_ID': preview};
    const a = 'HOUSEHOLD::HOUSEHOLD_1731220000004';
    const b = 'HOUSEHOLD::HOUSEHOLD_1731220000005';
    const c = 'HOUSEHOLD::HOUSEHOLD_1731220000006';

    final tokenA = await popupToken(tester, context, a, nav, preview);
    final tokenB = await popupToken(tester, context, b, nav, preview);
    expect(tokenB, isNot(tokenA));

    final savedA = savedIdentifiers(
        await submit(tester, context, a, nav, preview));
    expect(savedA.single['identifierId'], tokenA);
    await markSaved(tester, context, savedA);

    final tokenC = await popupToken(tester, context, c, nav, preview);
    expect(tokenC, isNot(anyOf(tokenA, tokenB)));
    final savedB = savedIdentifiers(
        await submit(tester, context, b, nav, preview));
    expect(savedB.single['identifierId'], tokenB);

    // Every saved/shown e-token is a distinct pool row.
    expect({tokenA, tokenB, tokenC}.map(rawIdOf).toSet(), hasLength(3));
  });

  testWidgets(
      'a closed household being registered saves the e-token its popup showed',
      (tester) async {
    final context = await pumpApp(tester);
    const form = 'HOUSEHOLD::HOUSEHOLD_1731220000007';
    final nav = <String, dynamic>{
      'isEdit': 'true',
      'isClosedHousehold': 'true',
      'HouseholdClientReferenceId': 'closed-household',
    };
    // A closed household's head carries the DEFAULT uuid identifier.
    const oldIdentifier = 'DEFAULT,7c7f6a0e-uuid';

    final result = (await tester.runAsync(() => LoadUniqueIdPoolExecutor()
            .execute(poolAction({'allocate': true, 'silent': true}), context, {
          'formData': {
            'householdDetails': {'identifiers': oldIdentifier}
          },
          'navigation': nav,
          '_compositeKey': form,
        })))!;
    final shown = result['latestBeneficiaryId'] as String;
    expect(shown, startsWith('${_prefix}_raw'));

    final submitted = (await tester.runAsync(() => LoadUniqueIdPoolExecutor()
            .execute(poolAction({'allocate': true, 'stopOnError': true}), context, {
          'formData': {
            'householdDetails': {'identifiers': oldIdentifier}
          },
          'navigation': nav,
          '_compositeKey': form,
        })))!;
    final saved =
        savedIdentifiers(Map<String, dynamic>.from(submitted['formData']));
    expect(saved.single['identifierId'], shown);
  });
}
