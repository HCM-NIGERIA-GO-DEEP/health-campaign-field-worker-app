// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:digit_crud_bloc/bloc/crud_bloc.dart';
import 'package:digit_crud_bloc/service/crud_service.dart';
import 'package:digit_crud_bloc/utils/utils.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/action_handler.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:digit_flow_builder/action_handler/executors/reverse_transformer_executor.dart';
import 'package:digit_flow_builder/data/digit_crud_service.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// Liberia CR (2026-11-27): "Household Information is not captured ... same
/// for household too", and an edit must keep it right.
///
/// The Household record carries its head's details: headName,
/// headMobileNumber, headGender, headIndividualClientReferenceId (the keys the
/// delivery task uses for the same values).
///
/// Runs the HOUSEHOLD form's real flow-level onAction (real transformer,
/// CREATE_EVENT and UPDATE_EVENT) over the Dart copy and REGISTRATION.json and
/// reads what reaches the repositories.
class _Capture extends CrudService {
  final updated = <EntityModel>[];
  final created = <EntityModel>[];

  @override
  bool get isInitialized => true;

  @override
  Future<void> createEntities(List<EntityModel> entities) async =>
      created.addAll(entities);

  @override
  Future<void> updateEntities(List<EntityModel> entities) async =>
      updated.addAll(entities);
}

class _NoOp extends ActionExecutor {
  @override
  bool canHandle(String actionType) => true;

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async =>
      contextData;
}

class _EmptyPool extends Fake
    implements LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> {
  @override
  Future<List<UniqueIdPoolModel>> search(UniqueIdPoolSearchModel query) async =>
      const [];
}

Map<String, dynamic> _fields(EntityModel model) => {
      for (final f
          in ((model.toMap()['additionalFields'] as Map?)?['fields'] as List?) ??
              const [])
        (f as Map)['key'] as String: f['value'],
    };

void main() {
  final copies = <String, List<Map<String, dynamic>> Function()>{
    'Dart copy': () =>
        ((sampleFlows as Map)['flows'] as List).cast<Map<String, dynamic>>(),
    'REGISTRATION.json': () => ((jsonDecode(
          File('assets/configs/json/REGISTRATION.json').readAsStringSync(),
        ) as Map)['flows'] as List)
            .cast<Map<String, dynamic>>(),
  };

  late _Capture service;

  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    FlowBuilderSingleton().setInitialData(
      loggedInUserUuid: 'user',
      maxRadius: 10,
      projectId: 'project',
      selectedBeneficiaryType: BeneficiaryType.household,
      projectType: null,
      selectedProject:
          ProjectModel(id: 'project', name: 'Project', tenantId: 'lr'),
      loggedInUser: UserModel(uuid: 'user'),
      userRoles: const [
        {'code': 'REGISTRAR', 'name': 'REGISTRAR'}
      ],
    );
    FlowBuilderSingleton().setBoundary(
      boundary: BoundaryModel(code: 'COMM_1', name: 'COMM_1'),
    );
  });

  setUp(() {
    service = _Capture();
    CrudBlocSingleton().setData(
      crudService: service,
      dynamicEntityModelListener: EntityModelMapMapper(),
    );
    for (final type in ['NAVIGATION', 'SHOW_TOAST', 'UPDATE_IDENTIFIER_STATUS']) {
      ActionHandler.registry.register(type, _NoOp());
    }
  });

  tearDown(() {
    ActionHandler.registry.unregister('UPDATE_IDENTIFIER_STATUS');
    ActionHandler.registry.registerDefaultExecutors();
  });

  /// Submits the HOUSEHOLD form. What the forms bloc hands over: one map per
  /// page, every page, opened or not.
  Future<void> submit(
    WidgetTester tester,
    List<Map<String, dynamic>> flows, {
    required Map<String, dynamic> navigation,
    required Map<String, dynamic> householdDetails,
    required Map<String, dynamic> caregiverConsent,
    List<EntityModel>? existingModels,
    Map<String, dynamic> beneficiaryLocation = const {
      'administrativeArea': 'COMM_1',
      'latLng': [6.3, -10.8],
    },
  }) async {
    late BuildContext context;
    final bloc = await tester.runAsync(() async => CrudBloc(service: service));
    addTearDown(bloc!.close);
    await tester.pumpWidget(
      RepositoryProvider<
          LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>.value(
        value: _EmptyPool(),
        child: BlocProvider<CrudBloc>.value(
          value: bloc,
          child: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          }),
        ),
      ),
    );

    final form = flows.firstWhere(
        (f) => f['name'] == 'HOUSEHOLD' && f['screenType'] == 'FORM');
    await tester.runAsync(() async {
      await ActionHandler.executeActions(
        form['onAction'] as List<dynamic>,
        context,
        {
          'formData': {
            'beneficiaryLocation': beneficiaryLocation,
            'caregiverConsent': caregiverConsent,
            'householdDetails': householdDetails,
          },
          'navigation': navigation,
          if (existingModels != null) 'existingModels': existingModels,
          '_compositeKey': 'HOUSEHOLD::test',
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }

  for (final copy in copies.entries) {
    group(copy.key, () {
      testWidgets('a new household is saved with its head\'s details',
          (tester) async {
        await submit(
          tester,
          copy.value(),
          navigation: {'startPage': 'beneficiaryLocation'},
          caregiverConsent: {
            'consentToParticipate': 'TRUE',
            'firstName': null,
            'lastName': null,
          },
          householdDetails: {
            'dateOfRegistration': 1795000000000,
            'nameOfIndividual': 'Mary',
            'familyname': 'Kollie',
            'phone': '0770000001',
            'gender': 'FEMALE',
            'memberCount': 4,
            'childrenCount': 2,
            'pregnantWomenCount': 0,
            'isHeadOfFamily': true,
            'identifiers': 'UNIQUE_BENEFICIARY_ID, TOKEN',
          },
        );

        expect(service.updated, isEmpty);
        final head = service.created.whereType<IndividualModel>().single;
        expect(head.name?.givenName, 'Mary');
        expect(head.mobileNumber, '0770000001');
        expect(head.gender, Gender.female);

        final household = service.created.whereType<HouseholdModel>().single;
        final fields = _fields(household);
        expect(fields['headName'], 'Mary Kollie');
        expect(fields['headMobileNumber'], '0770000001');
        expect(fields['headGender'], 'FEMALE');
        expect(fields['headIndividualClientReferenceId'],
            head.clientReferenceId);
        expect(fields['headIndividualClientReferenceId'], isNotEmpty);
        // What the household held before this change is still there.
        expect(fields['childrenCount'], 2);
        expect(fields['memberCount'], 4);
        expect(fields['caregiverConsent'], 'TRUE');
        expect(fields.containsKey('firstName'), isFalse);
        expect(fields.values.where((v) => v == null || v == ''), isEmpty);

        final member = service.created.whereType<HouseholdMemberModel>().single;
        expect(member.isHeadOfHousehold, isTrue);
        expect(member.individualClientReferenceId, head.clientReferenceId);
        expect(member.householdClientReferenceId, household.clientReferenceId);
      });

      testWidgets(
          'a household that declined consent is saved with the name given on '
          'the consent page', (tester) async {
        await submit(
          tester,
          copy.value(),
          navigation: {'startPage': 'beneficiaryLocation'},
          caregiverConsent: {
            'consentToParticipate': 'FALSE',
            'firstName': 'Joe',
            'lastName': 'Doe',
          },
          // Never opened: the raw defaults of the page.
          householdDetails: {
            'nameOfIndividual': '{{navigation.firstName}}',
            'familyname': '{{navigation.lastName}}',
            'phone': '',
            'gender': '',
            'memberCount': '1',
            'childrenCount': '0',
            'pregnantWomenCount': '0',
          },
        );

        final head = service.created.whereType<IndividualModel>().single;
        final household = service.created.whereType<HouseholdModel>().single;
        final fields = _fields(household);
        expect(fields['headName'], 'Joe Doe');
        expect(fields['headIndividualClientReferenceId'],
            head.clientReferenceId);
        expect(fields.containsKey('headMobileNumber'), isFalse,
            reason: 'no phone was given');
        expect(fields.containsKey('headGender'), isFalse);
        expect(fields.values.where((v) => v == null || v == ''), isEmpty);
        expect(fields.values.where((v) => v.toString().contains('{{')), isEmpty);
      });

      testWidgets(
          'editing the head from Household Details updates the details on the '
          'household', (tester) async {
        final head = IndividualModel(
          clientReferenceId: 'individual',
          id: 'server-individual',
          tenantId: 'lr',
          rowVersion: 1,
          gender: Gender.female,
          mobileNumber: '0770000001',
          name: NameModel(
            individualClientReferenceId: 'individual',
            givenName: 'Mary',
            familyName: 'Kollie',
          ),
        );
        final household = HouseholdModel(
          clientReferenceId: 'household',
          id: 'server-household',
          tenantId: 'lr',
          rowVersion: 1,
          memberCount: 4,
          additionalFields: HouseholdAdditionalFields(
            version: 1,
            fields: const [
              AdditionalField('childrenCount', 2),
              AdditionalField('memberCount', 4),
              AdditionalField('caregiverConsent', 'TRUE'),
              AdditionalField('headName', 'Mary Kollie'),
              AdditionalField('headMobileNumber', '0770000001'),
              AdditionalField('headGender', 'FEMALE'),
              AdditionalField('headIndividualClientReferenceId', 'individual'),
            ],
          ),
        );

        await submit(
          tester,
          copy.value(),
          navigation: {
            'HouseholdClientReferenceId': 'household',
            'isEdit': 'true',
            'startPage': 'householdDetails',
          },
          // Not shown on this edit.
          caregiverConsent: {
            'consentToParticipate': null,
            'firstName': null,
            'lastName': null,
          },
          householdDetails: {
            'nameOfIndividual': 'Martha',
            'familyname': 'Kollie',
            'phone': '0880000002',
            'gender': 'FEMALE',
            'memberCount': 4,
            'childrenCount': 2,
          },
          existingModels: [household, head],
        );

        expect(service.created, isEmpty, reason: 'an edit creates nothing');
        final savedHead = service.updated.whereType<IndividualModel>().single;
        expect(savedHead.name?.givenName, 'Martha');
        expect(savedHead.mobileNumber, '0880000002');

        final saved = service.updated.whereType<HouseholdModel>().single;
        expect(saved.clientReferenceId, 'household');
        expect(saved.id, 'server-household');
        final fields = _fields(saved);
        expect(fields['headName'], 'Martha Kollie');
        expect(fields['headMobileNumber'], '0880000002');
        expect(fields['headGender'], 'FEMALE');
        expect(fields['headIndividualClientReferenceId'], 'individual');
        expect(fields['childrenCount'], 2);
        expect(fields['caregiverConsent'], 'TRUE',
            reason: 'the stored consent stays');
        expect(fields.values.where((v) => v == null || v == ''), isEmpty);
      });

      testWidgets(
          'reopening a closed household through the edit prefill saves the '
          'new head details, not the stored ones', (tester) async {
        final head = IndividualModel(
          clientReferenceId: 'individual',
          id: 'server-individual',
          tenantId: 'lr',
          rowVersion: 1,
          name: NameModel(
            individualClientReferenceId: 'individual',
            givenName: 'Joe',
            familyName: 'Doe',
          ),
          identifiers: [
            IdentifierModel(
              clientReferenceId: 'identifier',
              individualClientReferenceId: 'individual',
              identifierType: 'UNIQUE_BENEFICIARY_ID',
              identifierId: 'TOKEN',
            ),
          ],
        );
        final household = HouseholdModel(
          clientReferenceId: 'household',
          id: 'server-household',
          tenantId: 'lr',
          rowVersion: 1,
          memberCount: 1,
          additionalFields: HouseholdAdditionalFields(
            version: 1,
            fields: const [
              AdditionalField('caregiverConsent', 'FALSE'),
              AdditionalField('headName', 'Joe Doe'),
              AdditionalField('headIndividualClientReferenceId', 'individual'),
            ],
          ),
        );
        final task = TaskModel(
          clientReferenceId: 'task',
          id: 'server-task',
          tenantId: 'lr',
          rowVersion: 1,
          projectId: 'project',
          status: 'CLOSED_HOUSEHOLD',
          additionalFields: TaskAdditionalFields(
            version: 1,
            fields: const [
              AdditionalField('householdClientReferenceId', 'household'),
            ],
          ),
        );

        late BuildContext context;
        await tester.pumpWidget(Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }));
        final opened = await ReverseTransformerExecutor().execute(
          ActionConfig.fromJson({
            'actionType': 'REVERSE_TRANSFORM',
            'properties': {
              'configName': 'beneficiaryRegistration',
              'data': [
                {'key': 'entities', 'value': household},
                {'key': 'entities', 'value': head},
                {'key': 'entities', 'value': task},
              ],
            },
          }),
          context,
          {},
        );
        final prefill = opened['formData'] as Map<String, dynamic>;
        expect(prefill['headName'], 'Joe Doe',
            reason: 'the prefill does carry the stored copy: the save must '
                'not trust it');

        await submit(
          tester,
          copy.value(),
          navigation: {
            'HouseholdClientReferenceId': 'household',
            'isEdit': 'true',
            'isClosedHousehold': 'true',
            'startPage': 'caregiverConsent',
          },
          caregiverConsent: {
            'consentToParticipate': 'TRUE',
            'firstName': null,
            'lastName': null,
          },
          householdDetails: {
            ...prefill,
            'dateOfRegistration': 1795000000000,
            'nameOfIndividual': 'Joseph',
            'familyname': 'Doe',
            'phone': '0770000003',
            'gender': 'MALE',
            'memberCount': 3,
            'childrenCount': 1,
            'pregnantWomenCount': 0,
            'isHeadOfFamily': true,
            'identifiers': 'UNIQUE_BENEFICIARY_ID, TOKEN',
          },
          existingModels: (opened['existingModels'] as List).cast<EntityModel>(),
          // The location page is not part of this route.
          beneficiaryLocation: const {'administrativeArea': 'COMM_1'},
        );

        final savedHead = service.updated.whereType<IndividualModel>().single;
        expect(savedHead.name?.givenName, 'Joseph');
        expect(_fields(savedHead).keys.where((k) => k.startsWith('head')),
            isEmpty,
            reason: 'the copy belongs to the household only');

        final saved = service.updated.whereType<HouseholdModel>().single;
        expect(saved.clientReferenceId, 'household');
        final fields = _fields(saved);
        expect(fields['headName'], 'Joseph Doe');
        expect(fields['headMobileNumber'], '0770000003');
        expect(fields['headGender'], 'MALE');
        expect(fields['headIndividualClientReferenceId'], 'individual');

        final savedTask = service.updated.whereType<TaskModel>().single;
        expect(savedTask.id, 'server-task');
        expect(savedTask.status, 'NOT_ADMINISTERED');
      });
    });
  }
}
