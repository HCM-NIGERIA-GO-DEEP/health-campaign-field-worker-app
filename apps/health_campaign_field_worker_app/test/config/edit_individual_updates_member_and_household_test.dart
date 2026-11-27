// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

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

/// QA (Liberia): "when we are updating the details of head or beneficiary it
/// is not getting stored in db or elastic".
///
/// Edit Individual saved the Individual only. The same details are also kept
/// as copies: name, gender and date of birth in the HouseholdMember's
/// additional fields, and the head's family name in the Household's
/// familyName (this branch keeps no firstName on the household:
/// transformer_executor strips it). Those kept the old values.
///
/// Runs the Edit button's real REVERSE_TRANSFORM and then the ADD_MEMBER
/// form's real flow-level onAction (real transformer and UPDATE_EVENT), and
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

Map<String, dynamic>? _findByFieldName(dynamic node, String fieldName) {
  if (node is Map) {
    if (node['fieldName'] == fieldName) return node.cast<String, dynamic>();
    for (final v in node.values) {
      final hit = _findByFieldName(v, fieldName);
      if (hit != null) return hit;
    }
  } else if (node is List) {
    for (final v in node) {
      final hit = _findByFieldName(v, fieldName);
      if (hit != null) return hit;
    }
  }
  return null;
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
    ActionHandler.registry.register('NAVIGATION', _NoOp());
    ActionHandler.registry.register('SHOW_TOAST', _NoOp());
  });

  tearDown(ActionHandler.registry.registerDefaultExecutors);

  /// Presses Edit on the member's card, changes name and gender (and the date
  /// of birth of a child) and submits. Returns the records that were updated.
  Future<List<EntityModel>> edit(
    WidgetTester tester,
    List<Map<String, dynamic>> flows, {
    required bool head,
  }) async {
    final individual = IndividualModel(
      clientReferenceId: 'individual',
      id: 'server-individual',
      tenantId: 'lr',
      rowVersion: 1,
      gender: Gender.female,
      dateOfBirth: head ? null : '01/01/2024',
      name: NameModel(
        individualClientReferenceId: 'individual',
        givenName: 'Old given',
        familyName: 'Old family',
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
    final beneficiary = ProjectBeneficiaryModel(
      clientReferenceId: 'beneficiary',
      id: 'server-beneficiary',
      tenantId: 'lr',
      rowVersion: 1,
      projectId: 'project',
      beneficiaryClientReferenceId: 'household',
      dateOfRegistration: 1700000000000,
    );
    // A member left behind by an earlier edit: its copies are older than the
    // individual (gender MALE, the individual is FEMALE).
    final member = HouseholdMemberModel(
      clientReferenceId: 'member',
      id: 'server-member',
      tenantId: 'lr',
      rowVersion: 1,
      householdClientReferenceId: 'household',
      individualClientReferenceId: 'individual',
      isHeadOfHousehold: head,
      additionalFields: HouseholdMemberAdditionalFields(
        version: 1,
        fields: [
          const AdditionalField('name', 'Stale name'),
          const AdditionalField('gender', 'MALE'),
          if (!head) const AdditionalField('dateOfBirth', '01/01/2024'),
          const AdditionalField('individualClientReferenceId', 'individual'),
        ],
      ),
    );
    final household = HouseholdModel(
      clientReferenceId: 'household',
      id: 'server-household',
      tenantId: 'lr',
      rowVersion: 1,
      memberCount: 3,
      additionalFields: HouseholdAdditionalFields(
        version: 1,
        fields: [
          const AdditionalField('familyName', 'Old family'),
          const AdditionalField('childrenCount', '2'),
          const AdditionalField('caregiverConsent', 'TRUE'),
        ],
      ),
    );

    late BuildContext context;
    await tester.pumpWidget(
      RepositoryProvider<
          LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>.value(
        value: _EmptyPool(),
        child: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ),
    );

    // The member card's evaluation context (WidgetStateContext.evalContext).
    final item = <String, dynamic>{
      'individual': [individual],
      'projectBeneficiary': [beneficiary],
      'member': [member],
    };
    final evalContext = <String, dynamic>{
      'item': item,
      'itemData': item,
      'contextData': [
        // The relation holds the models themselves (wrapper_builder.dart).
        {
          'household': [household],
        },
      ],
    };

    final overview = flows.firstWhere((f) => f['name'] == 'householdOverview');
    final button = _findByFieldName(overview, 'editIndividualButton')!;
    final addMember = flows.firstWhere(
        (f) => f['name'] == 'ADD_MEMBER' && f['screenType'] == 'FORM');

    // Both branches of the button (with / without a beneficiary id) carry the
    // same REVERSE_TRANSFORM; run each one.
    final reverseActions = [
      for (final branch in button['onAction'] as List)
        ((branch as Map)['actions'] as List).cast<Map<String, dynamic>>()
            .firstWhere((a) => a['actionType'] == 'REVERSE_TRANSFORM'),
    ];
    expect(reverseActions, hasLength(2));

    late List<EntityModel> updated;
    for (final reverse in reverseActions) {
      service.updated.clear();
      // Resolved like ResolvedFlowWidget.resolveActionNavData.
      final properties = Map<String, dynamic>.from(reverse['properties'] as Map);
      // An APK without `updateOnlyEntities` reads the `entities` entries
      // only, so it must keep seeing exactly what it saw before.
      expect([
        for (final entry in properties['data'] as List)
          if ((entry as Map)['key'] == 'entities') entry['value'],
      ], ['{{item.individual}}', '{{item.projectBeneficiary}}']);
      properties['data'] = [
        for (final entry in properties['data'] as List)
          {
            ...(entry as Map).cast<String, dynamic>(),
            'value': resolveValue(entry['value'], evalContext),
          },
      ];
      final opened = await ReverseTransformerExecutor().execute(
        ActionConfig.fromJson({...reverse, 'properties': properties}),
        context,
        {},
      );
      final prefill = opened['formData'] as Map<String, dynamic>;
      expect(prefill['nameOfIndividual'], 'Old given');
      expect(prefill['gender'].toString().toUpperCase(), endsWith('FEMALE'),
          reason: 'the form shows the individual\'s gender, not the copy on '
              'the member');
      expect(prefill.containsKey('name'), isFalse,
          reason: 'the member\'s copies are not form values');

      await tester.runAsync(() => ActionHandler.executeActions(
            addMember['onAction'] as List<dynamic>,
            context,
            {
              'formData': {
                'beneficiaryDetails': {
                  ...prefill,
                  'nameOfIndividual': 'New given',
                  'familyname': 'New family',
                  'gender': 'MALE',
                  // Hidden for the head.
                  'dobPicker': head ? null : '02/02/2025',
                  'identifiers': 'UNIQUE_BENEFICIARY_ID, TOKEN',
                },
              },
              'navigation': {
                'HouseholdClientReferenceId': 'household',
                'isEdit': 'true',
                'isHead': head ? 'true' : 'false',
              },
              'existingModels': opened['existingModels'],
              '_compositeKey': 'ADD_MEMBER::test',
            },
          ));
      updated = List.of(service.updated);
      expect(service.created, isEmpty, reason: 'an edit creates nothing');
    }
    return updated;
  }

  for (final copy in copies.entries) {
    group(copy.key, () {
      testWidgets('editing a child also updates its HouseholdMember copies',
          (tester) async {
        final updated = await edit(tester, copy.value(), head: false);

        final individual = updated.whereType<IndividualModel>().single;
        expect(individual.clientReferenceId, 'individual');
        expect(individual.name?.givenName, 'New given');
        expect(individual.gender, Gender.male);

        final member = updated.whereType<HouseholdMemberModel>().single;
        expect(member.clientReferenceId, 'member');
        expect(member.id, 'server-member');
        expect(member.householdClientReferenceId, 'household');
        expect(member.individualClientReferenceId, 'individual');
        expect(member.isHeadOfHousehold, isFalse);
        final fields = _fields(member);
        expect(fields['name'], 'New given New family');
        expect(fields['gender'], 'MALE');
        expect(fields['dateOfBirth'], '02/02/2025');
        expect(fields['individualClientReferenceId'], 'individual');
        expect(fields.values.where((v) => v == null), isEmpty);

        expect(updated.whereType<HouseholdModel>(), isEmpty,
            reason: 'a child\'s name is not the household\'s name');
      });

      testWidgets(
          'editing the head also updates its HouseholdMember copies and the '
          'household\'s familyName', (tester) async {
        final updated = await edit(tester, copy.value(), head: true);

        expect(updated.whereType<IndividualModel>().single.name?.familyName,
            'New family');

        final member = updated.whereType<HouseholdMemberModel>().single;
        expect(member.clientReferenceId, 'member');
        expect(member.isHeadOfHousehold, isTrue,
            reason: 'the head stays the head');
        final fields = _fields(member);
        expect(fields['name'], 'New given New family');
        expect(fields['gender'], 'MALE');
        expect(fields.values.where((v) => v == null), isEmpty);

        final household = updated.whereType<HouseholdModel>().single;
        expect(household.clientReferenceId, 'household');
        expect(household.id, 'server-household');
        expect(household.memberCount, 3);
        expect(_fields(household), {
          'familyName': 'New family',
          'childrenCount': '2',
          'caregiverConsent': 'TRUE',
        });
      });
    });
  }
}
