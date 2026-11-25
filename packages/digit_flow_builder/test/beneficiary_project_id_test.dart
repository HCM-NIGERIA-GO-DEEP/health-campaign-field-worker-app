import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// A REGISTRAR is staffed on a health-facility project, but every NEW
/// ProjectBeneficiary they save must carry the project of the Distribution
/// Point above the boundary being saved. Every other model keeps the
/// selected project. Runs the real TransformerExecutor.execute over the real
/// transformer configs.

const selectedProjectId = 'hf-project';
const dpAProjectId = 'dp-a-project';
const dpBProjectId = 'dp-b-project';

class _EmptyIdPool extends Fake
    implements LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> {
  @override
  Future<List<UniqueIdPoolModel>> search(UniqueIdPoolSearchModel query) async =>
      [];
}

void setUpSingleton({
  required List<String> roles,
  String? materializedPath = 'LR.DIST_1.HF_1.DP_A.COMM_1',
  String boundaryCode = 'COMM_1',
  Map<String, String> boundaryProjectIds = const {
    'DP_A': dpAProjectId,
    'DP_B': dpBProjectId,
  },
}) {
  FlowBuilderSingleton().setInitialData(
    loggedInUserUuid: 'worker',
    maxRadius: 10,
    projectId: selectedProjectId,
    selectedBeneficiaryType: BeneficiaryType.household,
    projectType: null,
    selectedProject: ProjectModel(
      id: selectedProjectId,
      name: 'Health facility project',
      tenantId: 'lr',
    ),
    loggedInUser: UserModel(uuid: 'worker'),
    userRoles: roles.map((code) => {'code': code, 'name': code}).toList(),
  );
  FlowBuilderSingleton().setBoundary(
    boundary: BoundaryModel(
      code: boundaryCode,
      name: boundaryCode,
      materializedPath: materializedPath,
    ),
  );
  FlowBuilderSingleton().setBoundaryProjectIds(boundaryProjectIds);
}

const registrationForm = {
  'householdDetails': {
    'nameOfIndividual': 'Ama',
    'familyname': 'Kollie',
    'memberCount': 1,
    'isHeadOfFamily': true,
    'dateOfRegistration': 1763000000000,
  },
};

void main() {
  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  Future<List<EntityModel>> run(
    WidgetTester tester,
    String configName, {
    Map<String, dynamic> formData = registrationForm,
    Map<String, dynamic> extra = const {},
    List<Map<String, dynamic>>? actionData,
  }) async {
    late BuildContext context;
    await tester.pumpWidget(
      RepositoryProvider<
          LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>.value(
        value: _EmptyIdPool(),
        child: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ),
    );
    final result = await tester.runAsync(() => TransformerExecutor().execute(
          ActionConfig(
            action: 'test',
            actionType: 'FETCH_TRANSFORMER_CONFIG',
            properties: {
              'configName': configName,
              if (actionData != null) 'data': actionData,
            },
          ),
          context,
          {
            'formData': formData,
            '_compositeKey': 'beneficiaryProjectIdTest',
            ...extra,
          },
        ));
    return (result!['entities'] as List).cast<EntityModel>();
  }

  /// Every entity other than the ProjectBeneficiary that carries a projectId
  /// must carry the selected one.
  void expectOthersKeepSelectedProject(List<EntityModel> entities) {
    for (final entity in entities) {
      if (entity is ProjectBeneficiaryModel) continue;
      final projectId = entity.toMap()['projectId'];
      if (projectId != null) {
        expect(projectId, selectedProjectId, reason: '${entity.runtimeType}');
      }
    }
  }

  group('beneficiaryRegistration', () {
    testWidgets('a REGISTRAR saves the PB under the DP above the boundary',
        (tester) async {
      setUpSingleton(roles: ['REGISTRAR']);
      final entities = await run(tester, 'beneficiaryRegistration');

      expect(entities.whereType<HouseholdModel>(), hasLength(1));
      expect(entities.whereType<IndividualModel>(), hasLength(1));
      expect(entities.whereType<HouseholdMemberModel>(), hasLength(1));
      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          dpAProjectId);
      expectOthersKeepSelectedProject(entities);
    });

    testWidgets('a REGISTRAR who is also a DISTRIBUTOR gets the DP project',
        (tester) async {
      setUpSingleton(roles: ['DISTRIBUTOR', 'REGISTRAR']);
      final entities = await run(tester, 'beneficiaryRegistration');

      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          dpAProjectId);
    });

    testWidgets('picks DP_B when the boundary sits under DP_B', (tester) async {
      setUpSingleton(
        roles: ['REGISTRAR'],
        materializedPath: 'LR.DIST_1.HF_1.DP_B.COMM_9',
        boundaryCode: 'COMM_9',
      );
      final entities = await run(tester, 'beneficiaryRegistration');

      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          dpBProjectId);
    });

    testWidgets('without the REGISTRAR role the PB keeps the selected project',
        (tester) async {
      setUpSingleton(roles: ['DISTRIBUTOR']);
      final entities = await run(tester, 'beneficiaryRegistration');

      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          selectedProjectId);
    });

    testWidgets('a REGISTRAR with no DP match keeps the selected project',
        (tester) async {
      setUpSingleton(
        roles: ['REGISTRAR'],
        materializedPath: 'LR.DIST_1.HF_1.DP_C.COMM_5',
        boundaryCode: 'COMM_5',
      );
      final entities = await run(tester, 'beneficiaryRegistration');

      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          selectedProjectId);
    });

    testWidgets('a REGISTRAR with a null boundary path keeps the selected '
        'project', (tester) async {
      setUpSingleton(
        roles: ['REGISTRAR'],
        materializedPath: null,
        boundaryCode: 'COMM_1',
      );
      final entities = await run(tester, 'beneficiaryRegistration');

      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          selectedProjectId);
    });

    testWidgets('a REGISTRAR with no stored DP map keeps the selected project',
        (tester) async {
      setUpSingleton(roles: ['REGISTRAR'], boundaryProjectIds: const {});
      final entities = await run(tester, 'beneficiaryRegistration');

      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          selectedProjectId);
    });

    testWidgets('editing an existing beneficiary keeps its PB projectId',
        (tester) async {
      setUpSingleton(roles: ['REGISTRAR']);
      final existingPb = ProjectBeneficiaryModel(
        clientReferenceId: 'pb-1',
        projectId: 'old-project',
        beneficiaryClientReferenceId: 'household-1',
        tenantId: 'lr',
        dateOfRegistration: 1700000000000,
      );
      final entities = await run(
        tester,
        'beneficiaryRegistration',
        extra: {
          'navigation': {'isEdit': true},
          'existingModels': <EntityModel>[
            HouseholdModel(clientReferenceId: 'household-1', memberCount: 1),
            existingPb,
          ],
        },
      );

      final pb = entities.whereType<ProjectBeneficiaryModel>().single;
      expect(pb.clientReferenceId, 'pb-1');
      expect(pb.projectId, 'old-project');
    });
  });

  testWidgets('individualRegistration: a REGISTRAR gets the DP project',
      (tester) async {
    setUpSingleton(roles: ['REGISTRAR']);
    final entities = await run(
      tester,
      'individualRegistration',
      formData: {
        'beneficiaryDetails': {
          'nameOfIndividual': 'Kofi',
          'familyname': 'Kollie',
        },
      },
      extra: {
        'navigation': {'HouseholdClientReferenceId': 'household-1'},
      },
    );

    expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
        dpAProjectId);
    expectOthersKeepSelectedProject(entities);
  });

  testWidgets('bulkProjectBeneficiaryFromMembers: every PB gets the DP project',
      (tester) async {
    setUpSingleton(roles: ['REGISTRAR']);
    final entities = await run(
      tester,
      'bulkProjectBeneficiaryFromMembers',
      formData: const {},
      actionData: [
        {
          'key': 'individuals',
          'value': [
            {'clientReferenceId': 'individual-1'},
            {'clientReferenceId': 'individual-2'},
          ],
        },
      ],
    );

    final pbs = entities.whereType<ProjectBeneficiaryModel>().toList();
    expect(pbs, hasLength(2));
    expect(pbs.map((pb) => pb.projectId), everyElement(dpAProjectId));
  });

  for (final entry in {
    'closeHouseholdRegistration': {
      'closeHouseholdDetails': {
        'headName': 'Captured first',
        'familyname': 'Captured last',
      },
    },
    'householdConsentDeclinedRegistration': {
      'caregiverConsent': {
        'firstName': 'Captured first',
        'lastName': 'Captured last',
      },
    },
  }.entries) {
    testWidgets(
        '${entry.key}: a REGISTRAR gets the DP project on the PB only, '
        'its CLOSED_HOUSEHOLD task keeps the selected project', (tester) async {
      setUpSingleton(roles: ['REGISTRAR']);
      final entities = await run(tester, entry.key, formData: entry.value);

      expect(entities.whereType<ProjectBeneficiaryModel>().single.projectId,
          dpAProjectId);
      final task = entities.whereType<TaskModel>().single;
      expect(task.projectId, selectedProjectId);
      expectOthersKeepSelectedProject(entities);
    });
  }
}
