import 'dart:convert';

import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_forms_engine/pages/forms_render.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show wrapWithMaterialApp;

void main() {
  // A parent question above a Yes/No sub-question, as on the eligibility
  // checklist ("Did the child receive any of the following interventions?").
  final pageJson = {
    'type': 'object',
    'label': 'Checklist',
    'properties': {
      'interventionsHeading': {
        'type': 'string',
        'format': 'heading',
        'label': 'PARENT_QUESTION',
        'order': 1,
      },
      'malariaVaccine': {
        'type': 'string',
        'format': 'radio',
        'label': 'MALARIA_VACCINE',
        'order': 2,
        'enums': [
          {'code': 'YES', 'name': 'YES'},
          {'code': 'NO', 'name': 'NO'},
        ],
        'validations': [
          {'type': 'required', 'value': true, 'message': 'Required'},
        ],
      },
    },
  };

  test('parses the heading format from config', () {
    final page = PropertySchema.fromJson(pageJson);

    expect(page.properties!['interventionsHeading']!.format,
        PropertySchemaFormat.heading);
  });

  test('creates no form control for a heading', () {
    final page = PropertySchema.fromJson(pageJson);

    final controls = JsonForms.getFormControls(page);

    expect(controls.keys, ['malariaVaccine']);
  });

  final schemaJson = jsonEncode({
    'name': 'CHECKLIST',
    'version': 1,
    'pages': {'eligibilityChecklist': pageJson},
  });

  testWidgets('renders the heading text above its sub-question',
      (tester) async {
    final bloc = FormsBloc()..add(FormsEvent.load(schemas: [schemaJson]));
    // Not awaited: bloc.close() never completes under the widget test's
    // fake-async clock (same as widget_test.dart's tearDown).
    addTearDown(() {
      bloc.close();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpWidget(wrapWithMaterialApp(
      BlocProvider<FormsBloc>.value(
        value: bloc,
        child: FormsRenderPage(
          pageName: 'eligibilityChecklist',
          currentSchemaKey: 'CHECKLIST',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final heading = find.text('PARENT_QUESTION');
    final question = find.text('MALARIA_VACCINE', findRichText: true);
    expect(heading, findsOneWidget);
    expect(question, findsOneWidget);
    expect(tester.getTopLeft(heading).dy,
        lessThan(tester.getTopLeft(question).dy));
  });

  test('leaves headings out of the submitted form data', () async {
    final bloc = FormsBloc()
      ..add(FormsEvent.load(schemas: [schemaJson]))
      ..add(const FormsEvent.submit(schemaKey: 'CHECKLIST'));

    final submitted = await bloc.stream.firstWhere(
            (state) => state is FormsSubmittedState) as FormsSubmittedState;
    final pageData = submitted.formData['eligibilityChecklist']!;

    expect(pageData.containsKey('interventionsHeading'), isFalse);
    expect(pageData.containsKey('malariaVaccine'), isTrue);

    await bloc.close();
  });
}
