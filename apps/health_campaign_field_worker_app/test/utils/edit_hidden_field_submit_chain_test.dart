// The links between the forms engine and the edit merge for the hidden-height
// fix (QA 2026-11-13; see edit_hidden_field_clears_additional_field_test.dart
// for the merge itself):
//   1. FormSubmissionRegistry reads the fields the user saw and then hid
//      from the submitted schema and hands them to the screen, per submit.
//   2. TransformerExecutor passes the screen's `hiddenFormPaths` to the edit
//      merge, and without them saves exactly as before.

import 'dart:convert';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/transformer_executor.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/blocs/form_submission_registry.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/screen_builder.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_forms_engine/helper/visibility_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../widget_app.dart';

const _schemaKey = 'ADD_MEMBER';

final _schemaJson = jsonEncode({
  'name': _schemaKey,
  'version': 1,
  'pages': {
    'beneficiaryDetails': {
      'type': 'object',
      'label': 'DETAILS',
      'order': 1,
      'properties': {
        'height': {
          'type': 'string',
          'format': 'text',
          'label': 'HEIGHT',
          'order': 1,
          'value': '',
          'visibilityCondition': {
            'expression': [
              {'condition': 'beneficiaryDetails.isOlder==YES'},
            ],
          },
        },
      },
    },
  },
});

/// Submits the loaded form through [bloc], with the page saved the way
/// FormsRenderPage saves it. Height is shown first; when [heightHidden], the
/// user's edit then hides it, as the DOB change did in QA's report.
void _saveAndSubmit(FormsBloc bloc, {required bool heightHidden}) {
  final schema = bloc.state.cachedSchemas[_schemaKey]!;
  final page = schema.pages['beneficiaryDetails']!;
  final form = FormGroup({'height': FormControl<String>(value: '85')});
  final visibility =
      VisibilityManager(schemaMap: const {}, form: form, formData: const {});
  visibility.toggleControlVisibility(
      'height', true, page.properties!['height']!);
  if (heightHidden) {
    visibility.toggleControlVisibility(
        'height', false, page.properties!['height']!);
  }
  // Saving changes no value here, so the bloc keeps [page] (FormsRenderPage
  // passes the page it holds as `current` for exactly this case).
  final saved = page.copyWith();
  recordHiddenFields(saved, form, current: page);

  bloc
    ..add(FormsEvent.update(
      schemaKey: _schemaKey,
      schema: schema
          .copyWith(pages: {...schema.pages, 'beneficiaryDetails': saved}),
    ))
    ..add(const FormsEvent.submit(schemaKey: _schemaKey, isEdit: true));
}

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
    selectedProject: ProjectModel(id: 'P1', name: 'Project', tenantId: 'ng'),
    loggedInUser: UserModel(uuid: 'U1'),
  );
  FlowBuilderSingleton()
      .setBoundary(boundary: BoundaryModel(code: 'NG_WARD_1', name: 'Ward 1'));
}

IndividualModel _child() => IndividualModel(
      clientReferenceId: 'ind-1',
      tenantId: 'ng',
      name: NameModel(givenName: 'Amina', familyName: 'Bello'),
      dateOfBirth: '01/03/2025',
      gender: Gender.female,
      additionalFields: IndividualAdditionalFields(version: 1, fields: const [
        AdditionalField('height', '85'),
        AdditionalField('cycleIndexStamp', '1'),
      ]),
    );

/// The ADD_MEMBER edit submit, run through the real TransformerExecutor.
Future<Map<String, dynamic>?> _saveEdit(
  WidgetTester tester, {
  Set<String>? hiddenFormPaths,
}) async {
  late BuildContext context;
  await tester.pumpWidget(WidgetApp(
    child: Builder(builder: (c) {
      context = c;
      return const SizedBox.shrink();
    }),
  ));

  final out = await TransformerExecutor().execute(
    ActionConfig(
      action: '',
      actionType: 'FETCH_TRANSFORMER_CONFIG',
      properties: {'configName': 'individualRegistration'},
    ),
    context,
    {
      '_compositeKey': 'hiddenHeightTest::A',
      'formData': {
        'beneficiaryDetails': {
          'nameOfIndividual': 'Amina',
          'familyname': 'Bello',
          'dobPicker': '01/03/2026',
          'gender': 'FEMALE',
          'height': null,
          'phone': null,
        },
      },
      'navigation': {'isEdit': 'true'},
      'existingModels': <EntityModel>[_child()],
      if (hiddenFormPaths != null) 'hiddenFormPaths': hiddenFormPaths,
    },
  );
  final individual =
      (out['entities'] as List).whereType<IndividualModel>().single;
  return {
    for (final f
        in individual.additionalFields?.fields ?? const <AdditionalField>[])
      f.key: f.value,
  };
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    data_model_mappers.initializeMappers();
    initializeFunctionRegistry();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
    _setProject();
  });
  setUp(() => FlowCrudStateRegistry().disposeAll());
  tearDown(() => FlowCrudStateRegistry().disposeAll());

  group('FormSubmissionRegistry', () {
    late FormsBloc bloc;
    final seen = <Set<String>>[];

    setUp(() async {
      seen.clear();
      bloc = FormsBloc()..add(FormsEvent.load(schemas: [_schemaJson]));
      await bloc.stream
          .firstWhere((s) => s.cachedSchemas.containsKey(_schemaKey));
      FormSubmissionRegistry().initialize(bloc);
      FormSubmissionRegistry().register(
        schemaKey: _schemaKey,
        instanceId: 'test',
        handler: (_) async =>
            seen.add(FormSubmissionRegistry().hiddenFieldsOfSubmit(_schemaKey)),
      );
    });
    tearDown(() async {
      FormSubmissionRegistry()
          .unregister(schemaKey: _schemaKey, instanceId: 'test');
      await bloc.close();
    });

    Future<void> submitted(int count) async {
      while (seen.length < count) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('hands the screen the fields the user saw and then hid', () async {
      _saveAndSubmit(bloc, heightHidden: true);
      await submitted(1);

      expect(seen.single, {'beneficiaryDetails.height'});
    });

    test('reports nothing for a submit where Height was visible', () async {
      _saveAndSubmit(bloc, heightHidden: false);
      await submitted(1);

      expect(seen.single, isEmpty);
    });

    test('does not carry hidden fields over to the next submit', () async {
      _saveAndSubmit(bloc, heightHidden: true);
      await submitted(1);
      bloc.add(const FormsEvent.clearForm(schemaKey: _schemaKey));
      _saveAndSubmit(bloc, heightHidden: false);
      await submitted(2);

      expect(seen, [
        {'beneficiaryDetails.height'},
        <String>{},
      ]);
    });
  });

  group('FORM submit context', () {
    final formData = <String, dynamic>{
      'beneficiaryDetails': <String, dynamic>{}
    };
    final navigation = <String, dynamic>{'isEdit': 'true'};

    test('is unchanged when no field was hidden', () {
      expect(
        formSubmitContext(
          formData: formData,
          navigation: navigation,
          entities: const [],
          hiddenFormPaths: const {},
        ),
        {'formData': formData, 'navigation': navigation},
      );
    });

    test('carries the hidden fields when there are any', () {
      expect(
        formSubmitContext(
          formData: formData,
          navigation: navigation,
          entities: const ['e'],
          hiddenFormPaths: const {'beneficiaryDetails.height'},
        ),
        {
          'formData': formData,
          'navigation': navigation,
          'entities': ['e'],
          'hiddenFormPaths': {'beneficiaryDetails.height'},
        },
      );
    });
  });

  group('TransformerExecutor edit merge', () {
    testWidgets('drops the stored height the user saw and then hid',
        (tester) async {
      final fields = await _saveEdit(tester,
          hiddenFormPaths: {'beneficiaryDetails.height'});

      expect(fields, {'cycleIndexStamp': '1'});
    });

    testWidgets('keeps the stored height when no field was hidden',
        (tester) async {
      final fields = await _saveEdit(tester);

      expect(fields, {'height': '85', 'cycleIndexStamp': '1'});
    });
  });
}
