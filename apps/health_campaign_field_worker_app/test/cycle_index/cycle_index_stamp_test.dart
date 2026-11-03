// Every record the flow transformer creates carries the campaign cycle it was
// saved in, under its own key `cycleIndexStamp` (additionalFields; complaints:
// `additionalDetail`). The existing `cycleIndex` key is saved exactly as
// before: only where a screen passes one.
//
// Decisions (Amit, 2026-11-02): stamp in every state built from this branch;
// the stamp is the cycle that started most recently, so a day between two
// cycles belongs to the cycle that just ended (5-9 Nov after a cycle ending
// 4 Nov -> that cycle) and a day before the first cycle to the first cycle;
// complaints carry it in the same additionalDetail text as their other extras.
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;
import 'package:digit_data_model/models/entities/hf_referral.dart';
// ignore: implementation_imports
import 'package:digit_data_converter/src/reverse_transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget_app.dart';

const _day = Duration.millisecondsPerDay;

/// Attendance records belong to the attendance register, not to a cycle.
const _attendanceConfigs = {
  'markAttendancePresent',
  'attendanceLogSave',
  'attendanceLogSubmit',
  'attendanceAttendeeStatusReset',
};

/// Cycle 1 has ended, cycle 2 is running now, cycle 3 has not started.
List<ProjectCycle> _cyclesWithCycle2Running() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    ProjectCycle(id: 1, startDate: now - 30 * _day, endDate: now - 20 * _day),
    ProjectCycle(id: 2, startDate: now - 5 * _day, endDate: now + 5 * _day),
    ProjectCycle(id: 3, startDate: now + 20 * _day, endDate: now + 30 * _day),
  ];
}

/// Cycles 1 and 2 have ended and cycle 3 has not started: today is a gap day.
List<ProjectCycle> _cyclesWithGapToday() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    ProjectCycle(id: 1, startDate: now - 30 * _day, endDate: now - 20 * _day),
    ProjectCycle(id: 2, startDate: now - 15 * _day, endDate: now - 5 * _day),
    ProjectCycle(id: 3, startDate: now + 20 * _day, endDate: now + 30 * _day),
  ];
}

/// No cycle has started yet.
List<ProjectCycle> _cyclesNotStartedYet() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    ProjectCycle(id: 1, startDate: now + 5 * _day, endDate: now + 15 * _day),
    ProjectCycle(id: 2, startDate: now + 20 * _day, endDate: now + 30 * _day),
  ];
}

/// Both cycles have ended.
List<ProjectCycle> _cyclesAllEnded() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    ProjectCycle(id: 1, startDate: now - 30 * _day, endDate: now - 20 * _day),
    ProjectCycle(id: 2, startDate: now - 15 * _day, endDate: now - 5 * _day),
  ];
}

void _setProject(List<ProjectCycle>? cycles) {
  FlowBuilderSingleton().setInitialData(
    loggedInUserUuid: 'U1',
    maxRadius: 0,
    projectId: 'P1',
    selectedBeneficiaryType: BeneficiaryType.individual,
    projectType: cycles == null
        ? null
        : ProjectTypeModel(id: 'PT1', code: 'AZM', cycles: cycles),
    selectedProject: ProjectModel(id: 'P1', name: 'Project', tenantId: 'kb'),
    loggedInUser: UserModel(uuid: 'U1'),
  );
  // Addresses require a locality code.
  FlowBuilderSingleton()
      .setBoundary(boundary: BoundaryModel(code: 'KB_WARD_1', name: 'Ward 1'));
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(WidgetApp(
    child: Builder(builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    }),
  ));
  return captured;
}

/// The least the screens put in the action context so every config's records
/// decode (required model fields, switch keys, list sources). A config
/// ignores the keys it does not map.
const _screenData = [
  {
    'key': 'individuals',
    'value': [
      {'clientReferenceId': 'ind-1'},
      {'clientReferenceId': 'ind-2'},
    ],
  },
  {
    'key': 'futureDoses',
    'value': [
      {'id': 2, 'deliveryStrategy': 'INDIRECT'},
    ],
  },
  {'key': 'sourceFlow', 'value': 'CHECKLIST'},
  // ISSUED is the entry type every stock `__switch` has a case for.
  {'key': 'stockEntryType', 'value': 'ISSUED'},
  {'key': 'HouseholdClientReferenceId', 'value': 'hh-1'},
  {'key': 'ProjectBeneficiaryClientReferenceId', 'value': 'pb-1'},
];

/// The least the forms submit so every config's records decode.
const _screenForm = <String, dynamic>{
  'householdDetails': {'dateOfRegistration': 1767225600000, 'memberCount': 1},
  'beneficiaryDetails': {'isHeadOfFamily': true},
  'complaintType': {'complaintType': 'SYNC_NOT_WORKING'},
  'complaintDetails': {'complaintDescription': 'Sync fails'},
};

Future<List<EntityModel>> _run(
  BuildContext context,
  String configName, {
  List<Map<String, dynamic>> data = const [],
  Map<String, dynamic> formData = const {},
  Map<String, dynamic>? navigation,
  List<EntityModel>? existingModels,
}) async {
  final out = await TransformerExecutor().execute(
    ActionConfig(
      action: '',
      actionType: 'FETCH_TRANSFORMER_CONFIG',
      properties: {
        'configName': configName,
        'data': [..._screenData, ...data],
      },
    ),
    context,
    {
      // What the layout renderer injects; the executor keys its state on it.
      '_compositeKey': 'cycleIndexTest::A',
      'formData': {..._screenForm, ...formData},
      if (navigation != null) 'navigation': navigation,
      if (existingModels != null) 'existingModels': existingModels,
    },
  );
  return (out['entities'] as List).cast<EntityModel>();
}

/// The value of extra [key] stored on [entity], or null when it has none.
///
/// Complaints keep their extras in the `additionalDetail` text, written as
/// Dart map text (`{supervisorName: Sani, ..., cycleIndexStamp: 2}`), where an
/// empty extra reads `null` like `supervisorContactNumber: null` does.
Object? _extraOf(EntityModel entity, String key) {
  final map = entity.toMap();
  if (entity is PgrServiceModel) {
    final value = RegExp('[{ ]$key: ([^,}]+)')
        .firstMatch(map['additionalDetail']?.toString() ?? '')
        ?.group(1);
    return value == null || value == 'null' ? null : int.tryParse(value);
  }
  final additional = map['additionalFields'];
  final fields = additional is Map ? additional['fields'] : null;
  if (fields is! List) return null;
  for (final field in fields) {
    if (field is Map && field['key'] == key) return field['value'];
  }
  return null;
}

Object? _stampOf(EntityModel entity) => _extraOf(entity, 'cycleIndexStamp');

String _typeOf(EntityModel entity) => entity.runtimeType.toString();

/// [entity] decoded back from its own JSON, as the sync queue does.
EntityModel _fromOwnJson(EntityModel entity) => switch (entity) {
      HouseholdModel() => HouseholdModelMapper.fromJson(entity.toJson()),
      IndividualModel() => IndividualModelMapper.fromJson(entity.toJson()),
      HouseholdMemberModel() =>
        HouseholdMemberModelMapper.fromJson(entity.toJson()),
      ProjectBeneficiaryModel() =>
        ProjectBeneficiaryModelMapper.fromJson(entity.toJson()),
      TaskModel() => TaskModelMapper.fromJson(entity.toJson()),
      StockModel() => StockModelMapper.fromJson(entity.toJson()),
      StockReconciliationModel() =>
        StockReconciliationModelMapper.fromJson(entity.toJson()),
      HFReferralModel() => HFReferralModelMapper.fromJson(entity.toJson()),
      PgrServiceModel() => PgrServiceModelMapper.fromJson(entity.toJson()),
      _ => throw UnsupportedError('no decoder for ${_typeOf(entity)}'),
    };

T? _decodeColumn<T>(String? stored, T Function(String) decode) =>
    stored == null ? null : decode(stored);

/// HFReferralLocalRepository builds each field from the decoded column map.
HFReferralAdditionalFields _hfReferralFieldsFromColumn(String stored) {
  final decoded = jsonDecode(stored) as Map<String, dynamic>;
  return HFReferralAdditionalFields(
    version: 1,
    fields: [
      for (final field
          in (decoded['fields'] as List).cast<Map<String, dynamic>>())
        AdditionalField(field['key'] as String, field['value']),
    ],
  );
}

/// The `fields` of [entity]'s additionalFields after a trip through its local
/// table: written by `companion` as JSON text, read back the way the local
/// repository reads it. Members and project beneficiaries are written but
/// not read back by their repositories, so their model mapper reads them.
List<Map<String, dynamic>>? _fieldsAfterLocalTable(EntityModel entity) {
  final AdditionalFields? fields = switch (entity) {
    HouseholdModel() => _decodeColumn(entity.companion.additionalFields.value,
        HouseholdAdditionalFieldsMapper.fromJson),
    IndividualModel() => _decodeColumn(entity.companion.additionalFields.value,
        IndividualAdditionalFieldsMapper.fromJson),
    HouseholdMemberModel() => _decodeColumn(
        entity.companion.additionalFields.value,
        HouseholdMemberAdditionalFieldsMapper.fromJson),
    ProjectBeneficiaryModel() => _decodeColumn(
        entity.companion.additionalFields.value,
        ProjectBeneficiaryAdditionalFieldsMapper.fromJson),
    TaskModel() => _decodeColumn(entity.companion.additionalFields.value,
        TaskAdditionalFieldsMapper.fromJson),
    // StockLocalRepository decodes the text first, then maps it.
    StockModel() => _decodeColumn(
        entity.companion.additionalFields.value,
        (stored) => StockAdditionalFieldsMapper.fromMap(
            jsonDecode(stored) as Map<String, dynamic>)),
    StockReconciliationModel() => _decodeColumn(
        entity.companion.additionalFields.value,
        StockReconciliationAdditionalFieldsMapper.fromJson),
    HFReferralModel() => _decodeColumn(
        entity.companion.additionalFields.value, _hfReferralFieldsFromColumn),
    _ => throw UnsupportedError('no table reader for ${_typeOf(entity)}'),
  };
  return fields?.fields.map((f) => {'key': f.key, 'value': f.value}).toList();
}

List<Map<String, dynamic>>? _fieldsOf(EntityModel entity) {
  final additional = entity.toMap()['additionalFields'];
  final fields = additional is Map ? additional['fields'] : null;
  return fields is List
      ? [
          for (final f in fields.whereType<Map>())
            {'key': f['key'], 'value': f['value']},
        ]
      : null;
}

Iterable<String> get _stampedConfigs =>
    jsonConfig.keys.where((name) => !_attendanceConfigs.contains(name));

/// `config/Model` for every model of [configName] missing from [entities].
Iterable<String> _notCreated(String configName, List<EntityModel> entities) {
  final created = entities.map(_typeOf).toSet();
  return (jsonConfig[configName]!['models'] as Map<String, dynamic>)
      .keys
      .where((model) => !created.contains(model))
      .map((model) => '$configName/$model');
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    data_model_mappers.initializeMappers();
    initializeFunctionRegistry();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });
  setUp(() => FlowCrudStateRegistry().disposeAll());
  tearDown(() => FlowCrudStateRegistry().disposeAll());

  for (final scenario in {
    'while cycle 2 runs: 2': (_cyclesWithCycle2Running, 2),
    'on a day between cycle 2 and 3: 2, the cycle that ended': (
      _cyclesWithGapToday,
      2
    ),
    'before any cycle has started: 1, the first cycle': (
      _cyclesNotStartedYet,
      1
    ),
    'after the last cycle has ended: 2, the last cycle': (_cyclesAllEnded, 2),
  }.entries) {
    testWidgets('every non-attendance config stamps every record it creates '
        '${scenario.key}', (tester) async {
      _setProject(scenario.value.$1());
      final context = await _pumpContext(tester);

      final notCreated = <String>[];
      final wrong = <String>[];
      for (final configName in _stampedConfigs) {
        final entities = await _run(context, configName);
        notCreated.addAll(_notCreated(configName, entities));
        for (final entity in entities) {
          final stamp = _stampOf(entity);
          if (stamp != scenario.value.$2) {
            wrong.add('$configName/${_typeOf(entity)} -> $stamp');
          }
        }
      }
      expect(notCreated, isEmpty,
          reason: 'every config still creates its records');
      expect(wrong, isEmpty);
    });
  }

  for (final scenario in {
    'when the project type has no cycles': () => <ProjectCycle>[],
    'when there is no project type': () => null,
  }.entries) {
    testWidgets('no cycleIndexStamp is saved ${scenario.key}, and every config '
        'still creates its records', (tester) async {
      _setProject(scenario.value());
      final context = await _pumpContext(tester);

      final notCreated = <String>[];
      final stamped = <String>[];
      for (final configName in _stampedConfigs) {
        final entities = await _run(context, configName);
        notCreated.addAll(_notCreated(configName, entities));
        stamped.addAll(entities
            .where((e) => _stampOf(e) != null)
            .map((e) => '$configName/${_typeOf(e)}'));
      }
      expect(notCreated, isEmpty,
          reason: 'every config still creates its records');
      expect(stamped, isEmpty);
    });
  }

  group('the existing cycleIndex key is saved as before', () {
    testWidgets('no record gets a cycleIndex when the screen passes none',
        (tester) async {
      _setProject(_cyclesWithCycle2Running());
      final context = await _pumpContext(tester);

      final withCycleIndex = <String>[];
      for (final configName in _stampedConfigs) {
        final entities = await _run(context, configName);
        withCycleIndex.addAll(entities
            .where((e) => _extraOf(e, 'cycleIndex') != null)
            .map((e) => '$configName/${_typeOf(e)}'));
      }
      expect(withCycleIndex, isEmpty);
    });

    testWidgets('a cycleIndex the screen passes is saved unchanged, next to '
        'the stamp', (tester) async {
      _setProject(_cyclesWithCycle2Running());
      final context = await _pumpContext(tester);

      final entities = await _run(
        context,
        'delivery',
        data: [
          {'key': 'cycleIndex', 'value': '{{navigation.cycleIndex}}'},
        ],
        navigation: {'cycleIndex': 3},
      );

      final task = entities.whereType<TaskModel>().single;
      expect(_extraOf(task, 'cycleIndex'), 3);
      expect(_stampOf(task), 2);
    });

    testWidgets('HF referral keeps referralCycle as passed and adds only the '
        'stamp', (tester) async {
      _setProject(_cyclesWithGapToday());
      final context = await _pumpContext(tester);

      final entities = await _run(
        context,
        'referralBeneficaryCreate',
        data: [
          {'key': 'cycleIndex', 'value': '{{navigation.cycleIndex}}'},
        ],
        navigation: {'cycleIndex': 2},
      );

      final referral = entities.whereType<HFReferralModel>().single;
      expect(_extraOf(referral, 'referralCycle'), 2);
      expect(_extraOf(referral, 'cycleIndex'), isNull);
      expect(_stampOf(referral), 2, reason: 'the cycle that ended');
    });
  });

  testWidgets('a complaint carries cycleIndexStamp next to its other extras',
      (tester) async {
    _setProject(_cyclesWithCycle2Running());
    final context = await _pumpContext(tester);

    final entities = await _run(
      context,
      'complaintRegistration',
      formData: {
        'complaintDetails': {
          'complaintDescription': 'Sync fails',
          'supervisorName': 'Sani',
        },
      },
    );

    final detail = entities.whereType<PgrServiceModel>().single.additionalDetail;
    expect(detail, contains('supervisorName: Sani'));
    expect(detail, contains('cycleIndexStamp: 2'));
  });

  group('editing a record keeps the cycle it was saved in', () {
    HouseholdModel household(List<AdditionalField> fields) => HouseholdModel(
          clientReferenceId: 'hh-1',
          tenantId: 'kb',
          memberCount: 3,
          additionalFields: HouseholdAdditionalFields(version: 1, fields: fields),
        );

    testWidgets('a cycle-1 household edited in cycle 2 stays cycle 1',
        (tester) async {
      _setProject(_cyclesWithCycle2Running());
      final context = await _pumpContext(tester);

      final entities = await _run(
        context,
        'householdConsentRegistration',
        formData: {
          'householdDetails': {'memberCount': 4},
        },
        navigation: {'isEdit': true},
        existingModels: [
          household(const [AdditionalField('cycleIndexStamp', 1)])
        ],
      );

      final updated = entities.whereType<HouseholdModel>().single;
      expect(updated.memberCount, 4, reason: 'the edit itself is applied');
      expect(_stampOf(updated), 1);
    });

    testWidgets('a household saved before this change gets no stamp on edit',
        (tester) async {
      _setProject(_cyclesWithCycle2Running());
      final context = await _pumpContext(tester);

      final entities = await _run(
        context,
        'householdConsentRegistration',
        formData: {
          'householdDetails': {'memberCount': 4},
        },
        navigation: {'isEdit': true},
        existingModels: [
          household(const [AdditionalField('memberCount', 3)])
        ],
      );

      expect(_stampOf(entities.whereType<HouseholdModel>().single), isNull);
    });
  });

  group('saving and reading the stamp back', () {
    testWidgets('every record keeps its stamp and all its other fields through '
        'the local table and the sync JSON', (tester) async {
      _setProject(_cyclesWithCycle2Running());
      final context = await _pumpContext(tester);

      final problems = <String>[];
      var checked = 0;
      for (final configName in _stampedConfigs) {
        for (final entity in await _run(context, configName)) {
          final label = '$configName/${_typeOf(entity)}';
          checked++;
          try {
            jsonEncode(entity.toMap());
            final decoded = _fromOwnJson(entity);
            if (!const DeepCollectionEquality()
                .equals(decoded.toMap(), entity.toMap())) {
              problems.add('$label: sync JSON round trip changed the record');
            }
            if (_stampOf(decoded) != 2) {
              problems.add('$label: sync JSON stamp ${_stampOf(decoded)}');
            }
            if (entity is PgrServiceModel) {
              final stored = entity.companion.additionalFields.value;
              if (!(stored ?? '').contains('cycleIndexStamp: 2')) {
                problems.add('$label: table text $stored');
              }
              continue;
            }
            final afterTable = _fieldsAfterLocalTable(entity);
            if (!const DeepCollectionEquality()
                .equals(afterTable, _fieldsOf(entity))) {
              problems.add('$label: table gave $afterTable');
            }
            if (!(afterTable ?? []).any((f) =>
                f['key'] == 'cycleIndexStamp' && f['value'] == 2)) {
              problems.add('$label: no stamp after the table');
            }
          } catch (e) {
            problems.add('$label: $e');
          }
        }
      }
      expect(problems, isEmpty);
      expect(checked, greaterThanOrEqualTo(_stampedConfigs.length),
          reason: 'every config saved at least one record');
    });

    // Edit screens are prefilled by REVERSE_TRANSFORM, which copies every
    // additionalFields key (the stamp too) into the form data; saving the
    // edit then maps that form data again, including the fallback model's
    // "unmapped fields" merge.
    for (final configName in [
      'householdConsentRegistration',
      'individualRegistration',
    ]) {
      testWidgets('an edit in a later cycle reads the stamp back into the form '
          'and saves the same cycle once ($configName)', (tester) async {
        _setProject(_cyclesNotStartedYet()); // saved before cycle 1: stamp 1
        final context = await _pumpContext(tester);
        final created = await _run(context, configName);

        final prefill = ReverseFormMapper(
          formConfig: jsonConfig[configName]!,
          modelInstances: created,
        ).buildFormData();
        expect(prefill['cycleIndexStamp'], 1);

        _setProject(_cyclesWithCycle2Running()); // edited in cycle 2
        final edited = await _run(
          context,
          configName,
          formData: prefill,
          navigation: {'isEdit': true},
          existingModels: created,
        );

        expect(edited, isNotEmpty);
        for (final entity in edited) {
          final stamps = (_fieldsOf(entity) ?? [])
              .where((f) => f['key'] == 'cycleIndexStamp')
              .map((f) => f['value'].toString())
              .toList();
          final before = created
              .where((e) => e.runtimeType == entity.runtimeType)
              .map(_stampOf)
              .firstOrNull;
          expect(stamps, before == null ? isEmpty : ['$before'],
              reason: _typeOf(entity));
        }
      });
    }
  });

  // `fn:disableEdit` decides the member card's Edit button from the tasks'
  // `cycleIndex`. The stamp lives in its own key, so the button must behave
  // as before (Amit, 2026-11-02). No AZM REGISTRATION.json passes cycleIndex
  // to ineligibleConfig, and vasIneligibleConfig never maps it.
  group('the Edit button for a child with an ineligible task', () {
    Future<bool> editDisabledAfter(
      WidgetTester tester,
      String configName, {
      List<Map<String, dynamic>> data = const [],
      Map<String, dynamic> formData = const {},
      Map<String, dynamic>? navigation,
    }) async {
      final context = await _pumpContext(tester);
      final tasks = (await _run(context, configName,
              data: data, formData: formData, navigation: navigation))
          .whereType<TaskModel>()
          .toList();
      expect(tasks, isNotEmpty, reason: '$configName saves a task');
      return FunctionRegistry.invokeBool(
          'disableEdit', [tasks, null], CrudStateData({}, []));
    }

    for (final configName in ['ineligibleConfig', 'vasIneligibleConfig']) {
      testWidgets('stays enabled while a cycle runs ($configName)',
          (tester) async {
        _setProject(_cyclesWithCycle2Running());

        expect(await editDisabledAfter(tester, configName), isFalse);
      });
    }

    testWidgets('is disabled on a day outside every cycle, as before',
        (tester) async {
      _setProject(_cyclesWithGapToday());

      expect(await editDisabledAfter(tester, 'ineligibleConfig'), isTrue);
    });

    testWidgets('other not-delivered verdicts still disable it while a cycle '
        'runs', (tester) async {
      _setProject(_cyclesWithCycle2Running());

      expect(
        await editDisabledAfter(
          tester,
          'unableToDeliverConfig',
          data: [
            {'key': 'cycleIndex', 'value': '{{navigation.cycleIndex}}'},
          ],
          formData: {
            'unableToDeliver': {'reason': 'BENEFICIARY_ABSENT'},
          },
          // As REGISTRATION.json does: the running cycle, via navigation.
          navigation: {'cycleIndex': 2},
        ),
        isTrue,
      );
    });
  });
}
