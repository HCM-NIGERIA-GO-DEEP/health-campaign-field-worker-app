// QA (Kebbi AZM, 2026-11-06): an HFReferral created from the eligibility
// CHECKLIST carried malariaVaccine/smc/polio/measlesRubella = YES but none of
// the four "last date received" values (malariaVaccineLastDate, ...).
//
// Cause: the CHECKLIST -> REFER_BENEFICIARY navigation passed
//   {{fn:toTimestamp(eligibilityChecklist.<x>Date)}}
// On FORM submit the page values sit under contextData['formData'].
// resolveNavigationDataValue retries a plain {{page.field}} as
// {{formData.page.field}}, but for a fn: it prefixes the whole expression, so
// the argument resolved to null, toTimestamp returned null and the
// transformer dropped the key. The config now passes
//   {{fn:toTimestamp(formData.eligibilityChecklist.<x>Date)}}
//
// Group 1 pins the resolver behaviour (no config needed). Group 2 runs the
// real chain from the local REGISTRATION.json (gitignored config clone; the
// group is skipped when the file is absent), once with the values as they
// were and once as they are now, and checks the only difference anywhere
// is the four dates.

import 'dart:convert';
import 'dart:io';

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
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

import '../widget_app.dart';

/// The flow config to check. Point it at a saved MDMS FormConfig record
/// before uploading one:
///   flutter test --dart-define=REGISTRATION_CONFIG=<path> <this file>
const _registrationPath = String.fromEnvironment('REGISTRATION_CONFIG',
    defaultValue: 'assets/configs/json/REGISTRATION.json');

const _interventions = ['malariaVaccine', 'smc', 'polio', 'measlesRubella'];

/// What each date value looked like before the fix.
String _oldValue(String intervention) =>
    '{{fn:toTimestamp(eligibilityChecklist.${intervention}Date)}}';

/// The dates a CDD picks on the checklist (date controls hold DateTime).
final _picked = {
  'malariaVaccine': DateTime(2026, 9, 1),
  'smc': DateTime(2026, 10, 1),
  'polio': DateTime(2026, 8, 15),
  'measlesRubella': DateTime(2026, 7, 20),
};

/// The eligibility checklist exactly as QA filled it: ec4 = YES (ADR), every
/// intervention YES with a date.
Map<String, dynamic> _checklistForm() => {
      'eligibilityChecklist': {
        'ec1': 'NO',
        'ec2': 'NO',
        'ec3': 'NO',
        'ec4': 'YES',
        'ec5': 'NO',
        for (final i in _interventions) ...{
          i: 'YES',
          '${i}Date': _picked[i],
        },
      },
    };

/// What the household overview hands to CHECKLIST.
const _checklistNavigation = <String, dynamic>{
  'selectedIndividualClientReferenceId': 'ind-1',
  'selectedIndividualIdentifierId': 'UBI-1',
  'HouseholdClientReferenceId': 'hh-1',
  'ProjectBeneficiaryClientReferenceId': 'pb-1',
  'selectedIndividualName': 'Child Kumar',
  'selectedIndividualGender': 'MALE',
  'selectedIndividualAgeInMonths': 24,
  'cycleIndex': 1,
  'memberCount': 3,
  'childName': 'Child Kumar',
  'ageInMonths': 24,
  'gender': 'MALE',
  'headName': 'Head Kumar',
  'latitude': 25.6230889,
  'longitude': 85.0173365,
  'headMobileNumber': '9999999999',
};

/// The context ScreenBuilder._handleFormSubmission builds on FORM submit.
Map<String, dynamic> _formSubmitContext() => {
      'formData': _checklistForm(),
      'navigation': Map<String, dynamic>.from(_checklistNavigation),
    };

Map<String, dynamic> _readRegistration() {
  var text = File(_registrationPath).readAsStringSync();
  if (text.startsWith('﻿')) text = text.substring(1);
  final config = jsonDecode(text) as Map<String, dynamic>;
  // An MDMS FormConfig record wraps the flow config in `data`.
  return config['flows'] == null && config['data'] is Map<String, dynamic>
      ? config['data'] as Map<String, dynamic>
      : config;
}

Map<String, dynamic> _flow(Map<String, dynamic> config, String name) =>
    (config['flows'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((f) => f['name'] == name);

Map<String, dynamic> _props(Map<String, dynamic> action) =>
    action['properties'] as Map<String, dynamic>;

/// The `data` entries of the CHECKLIST flow-level DEFAULT action: the
/// NAVIGATION to REFER_BENEFICIARY. Only the flow-level onAction runs on a
/// FORM screen.
List _checklistToReferralData(Map<String, dynamic> config) {
  final onAction = (_flow(config, 'CHECKLIST')['onAction'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere(
          (a) => (a['condition'] as Map?)?['expression'] == 'DEFAULT');
  final navigation = (onAction['actions'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((a) =>
          a['actionType'] == 'NAVIGATION' &&
          _props(a)['name'] == 'REFER_BENEFICIARY');
  return _props(navigation)['data'] as List;
}

/// The `data` entries of the REFER_BENEFICIARY flow-level
/// FETCH_TRANSFORMER_CONFIG action.
List _referralTransformData(Map<String, dynamic> config) {
  final transform = (_flow(config, 'REFER_BENEFICIARY')['onAction'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((a) =>
          a['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
          _props(a)['configName'] == 'referralBeneficaryCreate');
  return _props(transform)['data'] as List;
}

/// [entries] with the four date values put back as they were before the fix.
List<Map<String, dynamic>> _withOldDateValues(List entries) => [
      for (final e in entries.cast<Map<String, dynamic>>())
        {
          ...e,
          if (_interventions.any((i) => e['key'] == '${i}Date'))
            'value': _oldValue((e['key'] as String).replaceAll('Date', '')),
        },
    ];

/// NavigationExecutor + NavigationRegistry: every data entry resolved with
/// resolveNavigationDataValue, then turned into the next screen's params.
Map<String, dynamic> _navigate(List entries) => {
      for (final e in entries.cast<Map<String, dynamic>>())
        e['key'] as String: resolveNavigationDataValue(
          rawValue: e['value'],
          stateFormData: const {},
          stateWrapperFirst: null,
          contextData: _formSubmitContext(),
        ),
    };

void _setProject() {
  FlowBuilderSingleton().setInitialData(
    loggedInUserUuid: 'U1',
    maxRadius: 0,
    projectId: 'P1',
    selectedBeneficiaryType: BeneficiaryType.individual,
    projectType: ProjectTypeModel(id: 'PT1', code: 'AZM', cycles: [
      ProjectCycle(
        id: 1,
        startDate: DateTime.now()
            .subtract(const Duration(days: 5))
            .millisecondsSinceEpoch,
        endDate:
            DateTime.now().add(const Duration(days: 5)).millisecondsSinceEpoch,
      ),
    ]),
    selectedProject: ProjectModel(id: 'P1', name: 'Project', tenantId: 'kb'),
    loggedInUser: UserModel(uuid: 'U1'),
  );
  FlowBuilderSingleton().setBoundary(
      boundary: BoundaryModel(code: 'KB_WARD_1', name: 'Unguwar Kaduna'));
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(WidgetApp(
    child: Builder(builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    }),
  ));
  // The app registers toTimestamp here (FunctionRegistries.registerAll).
  FunctionRegistries(captured).registerAll();
  return captured;
}

Future<List<EntityModel>> _transform(
  BuildContext context,
  String configName, {
  List data = const [],
  Map<String, dynamic> formData = const {},
  Map<String, dynamic>? navigation,
  List<EntityModel>? existingModels,
}) async {
  final out = await TransformerExecutor().execute(
    ActionConfig(
      action: '',
      actionType: 'FETCH_TRANSFORMER_CONFIG',
      properties: {'configName': configName, 'data': data},
    ),
    context,
    {
      '_compositeKey': 'referralDatesTest::A',
      'formData': formData,
      if (navigation != null) 'navigation': navigation,
      if (existingModels != null) 'existingModels': existingModels,
    },
  );
  return (out['entities'] as List).cast<EntityModel>();
}

/// additionalFields as key -> value, failing on a repeated key.
Map<String, dynamic> _fields(EntityModel entity) {
  final additional = entity.toMap()['additionalFields'];
  final list = additional is Map ? additional['fields'] as List? : null;
  final result = <String, dynamic>{};
  for (final f in (list ?? const []).cast<Map>()) {
    final key = f['key'] as String;
    expect(result.containsKey(key), isFalse, reason: 'duplicate key $key');
    result[key] = f['value'];
  }
  return result;
}

/// Everything on the referral except values generated per run.
Map<String, dynamic> _stable(EntityModel entity) {
  final map = Map<String, dynamic>.from(entity.toMap())
    ..remove('clientReferenceId')
    ..remove('clientAuditDetails')
    ..remove('auditDetails')
    ..remove('additionalFields');
  return {
    ...map,
    'fields': {..._fields(entity)}..remove('dateOfEvaluation'),
  };
}

/// [after] minus [before]: keys added or whose value changed.
Map<String, dynamic> _diff(
    Map<String, dynamic> before, Map<String, dynamic> after) {
  final result = <String, dynamic>{};
  for (final key in {...before.keys, ...after.keys}) {
    if (!const DeepCollectionEquality().equals(before[key], after[key])) {
      result[key] = '${before[key]} -> ${after[key]}';
    }
  }
  return result;
}

void main() {
  final picked = DateTime(2026, 10, 1);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    data_model_mappers.initializeMappers();
    initializeFunctionRegistry();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });
  setUp(() => FlowCrudStateRegistry().disposeAll());
  tearDown(() => FlowCrudStateRegistry().disposeAll());

  group('resolveNavigationDataValue on FORM submit', () {
    Map<String, dynamic> ctx() => {
          'formData': {
            'eligibilityChecklist': {
              'malariaVaccine': 'YES',
              'malariaVaccineDate': picked,
            },
          },
          'navigation': <String, dynamic>{'cycleIndex': '1'},
        };

    dynamic resolve(String rawValue, Map<String, dynamic>? stateFormData) =>
        resolveNavigationDataValue(
          rawValue: rawValue,
          stateFormData: stateFormData,
          stateWrapperFirst: null,
          contextData: ctx(),
        );

    testWidgets('register the app functions', (tester) async {
      await _pumpContext(tester);
    });

    for (final stateFormData in <Map<String, dynamic>?>[null, {}]) {
      final label = stateFormData == null ? 'null' : '{}';

      test('a plain page path resolves (state formData $label)', () {
        expect(resolve('{{eligibilityChecklist.malariaVaccine}}', stateFormData),
            'YES');
      });

      test('fn:toTimestamp(page path) resolves to null - the QA bug '
          '(state formData $label)', () {
        expect(
            resolve('{{fn:toTimestamp(eligibilityChecklist.malariaVaccineDate)}}',
                stateFormData),
            isNull);
      });

      test('fn:toTimestamp(formData.page path) gives epoch millis - the fix '
          '(state formData $label)', () {
        expect(
            resolve(
                '{{fn:toTimestamp(formData.eligibilityChecklist.malariaVaccineDate)}}',
                stateFormData),
            picked.millisecondsSinceEpoch);
      });

      test('a plain date page path gives DateTime text '
          '(state formData $label)', () {
        expect(resolve('{{eligibilityChecklist.malariaVaccineDate}}',
                stateFormData),
            picked.toString());
      });
    }

    // beneficiaryDetails (TEMPLATE) -> DELIVERY, same config commit: TEMPLATE
    // actions put `navigation` at the context root.
    test('beneficiaryDetails -> DELIVERY fn:toTimestamp(navigation.x) resolves',
        () {
      expect(
        resolveNavigationDataValue(
          rawValue: '{{fn:toTimestamp(navigation.malariaVaccineDate)}}',
          stateFormData: const {},
          stateWrapperFirst: null,
          contextData: {
            'wrappers': const [],
            'navigation': {'malariaVaccineDate': picked.toString()},
          },
        ),
        picked.millisecondsSinceEpoch,
      );
    });
  });

  final hasConfig = File(_registrationPath).existsSync();
  group('REGISTRATION.json CHECKLIST -> REFER_BENEFICIARY -> HFReferral', () {
    late Map<String, dynamic> config;
    setUpAll(() => config = _readRegistration());

    test('no FORM fn: argument starts with a page name of its own flow', () {
      final problems = <String>[];
      final fnArgs = RegExp(r'fn:\w+\(([^)]*)\)');
      for (final flow in (config['flows'] as List).cast<Map>()) {
        if (flow['screenType'] != 'FORM') continue;
        final pages = {
          for (final p in (flow['pages'] as List? ?? const []).cast<Map>())
            if (p['page'] is String) p['page'] as String,
        };
        final text = jsonEncode(flow['onAction'] ?? const []);
        for (final m in fnArgs.allMatches(text)) {
          for (final arg in m.group(1)!.split(',')) {
            if (pages.contains(arg.trim().split('.').first)) {
              problems.add('${flow['name']}: ${m.group(0)}');
            }
          }
        }
      }
      expect(problems, isEmpty,
          reason: 'on FORM submit page values sit under formData; write '
              'fn arguments as formData.<page>.<field>');
    });

    test('the CHECKLIST navigation hands REFER_BENEFICIARY the four dates as '
        'epoch millis, and nothing else changes', () {
      final entries = _checklistToReferralData(config);
      final before = _navigate(_withOldDateValues(entries));
      final after = _navigate(entries);

      expect(_diff(before, after), {
        for (final i in _interventions)
          '${i}Date': 'null -> ${_picked[i]!.millisecondsSinceEpoch}',
      });
      for (final i in _interventions) {
        expect(after[i], 'YES');
      }
    });

    testWidgets('the referral record gains exactly the four LastDate keys, '
        'kept through the local table and the sync JSON', (tester) async {
      _setProject();
      final context = await _pumpContext(tester);
      final entries = _checklistToReferralData(config);
      final transformData =
          _referralTransformData(config);
      const referForm = {
        'referBeneficiary': {
          'administrativeArea': 'Unguwar Kaduna',
          'referredBy': 'U1',
          'healthFacility': 'HF-1',
        },
      };

      Future<HFReferralModel> refer(List navEntries) async {
        final entities = await _transform(
          context,
          'referralBeneficaryCreate',
          data: transformData,
          formData: referForm,
          navigation: _navigate(navEntries),
        );
        return entities.whereType<HFReferralModel>().single;
      }

      final before = await refer(_withOldDateValues(entries));
      final after = await refer(entries);

      final diff = _diff(_stable(before), _stable(after));
      expect(diff.keys, ['fields'], reason: 'only additionalFields changes');
      expect(
        _diff(_fields(before)..remove('dateOfEvaluation'),
            _fields(after)..remove('dateOfEvaluation')),
        {
          for (final i in _interventions)
            '${i}LastDate': 'null -> ${_picked[i]!.millisecondsSinceEpoch}',
        },
      );
      // QA's record, unchanged: answers, reasons and flow.
      final fields = _fields(after);
      for (final key in [
        'malariaVaccineReceived',
        'smcReceived',
        'polioReceived',
        'measlesRubellaReceived',
      ]) {
        expect(fields[key], 'YES', reason: key);
      }
      expect(fields['referralReasons'], 'DRUG_SE_PC');
      expect(fields['referralSymptom'], 'DRUG_SE_PC');
      expect(fields['flow'], 'smcDone');
      expect(after.symptom, 'DRUG_SE_PC');

      // The sync queue decodes the record from its own JSON.
      final synced = HFReferralModelMapper.fromJson(after.toJson());
      expect(_fields(synced), _fields(after));

      // HFReferralLocalRepository reads the companion column back.
      final stored = jsonDecode(after.companion.additionalFields.value!)
          as Map<String, dynamic>;
      final fromTable = {
        for (final f in (stored['fields'] as List).cast<Map>())
          f['key']: f['value'],
      };
      for (final i in _interventions) {
        expect(fromTable['${i}LastDate'], _picked[i]!.millisecondsSinceEpoch,
            reason: '${i}LastDate after the local table');
      }
    });

    // HFREFERRAL referralInbox "Continue": REVERSE_TRANSFORM (referralCreation)
    // prefills the HF form from the CDD referral, then the edit is saved with
    // referralCreation in edit mode.
    testWidgets('an HF "Continue" edit keeps the four dates once and changes '
        'nothing else', (tester) async {
      _setProject();
      final context = await _pumpContext(tester);
      final entries = _checklistToReferralData(config);
      final transformData =
          _referralTransformData(config);

      Future<HFReferralModel> referThenContinue(List navEntries) async {
        final created = (await _transform(
          context,
          'referralBeneficaryCreate',
          data: transformData,
          formData: const {
            'referBeneficiary': {'healthFacility': 'HF-1'},
          },
          navigation: _navigate(navEntries),
        ))
            .whereType<HFReferralModel>()
            .single;

        final prefill = ReverseFormMapper(
          formConfig: jsonConfig['referralCreation']!,
          modelInstances: [created],
        ).buildFormData();

        final edited = await _transform(
          context,
          'referralCreation',
          formData: prefill,
          navigation: {
            'isEdit': 'true',
            'clientReferenceId': created.clientReferenceId,
            'referralSymptom': created.symptom,
            'rowVersion': created.rowVersion,
          },
          existingModels: [created],
        );
        return edited.whereType<HFReferralModel>().single;
      }

      final before = await referThenContinue(_withOldDateValues(entries));
      final after = await referThenContinue(entries);

      final added = _diff(_fields(before)..remove('dateOfEvaluation'),
          _fields(after)..remove('dateOfEvaluation'));
      expect(added.keys.toSet(),
          {for (final i in _interventions) '${i}LastDate'});
      for (final i in _interventions) {
        expect(_fields(after)['${i}LastDate'].toString(),
            '${_picked[i]!.millisecondsSinceEpoch}',
            reason: '${i}LastDate after the edit');
      }
      final rest = _diff(_stable(before)..remove('fields'),
          _stable(after)..remove('fields'));
      expect(rest, isEmpty);
    });
  }, skip: hasConfig ? false : '$_registrationPath not present (gitignored)');
}
