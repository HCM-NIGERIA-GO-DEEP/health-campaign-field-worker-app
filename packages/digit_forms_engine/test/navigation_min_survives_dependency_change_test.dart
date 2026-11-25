import 'dart:convert';

import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_forms_engine/pages/forms_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

class _Localization extends LocalizationsDelegate<FormLocalization> {
  const _Localization();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FormLocalization> load(Locale locale) async =>
      FormLocalization(locale, Future.value([]), []);

  @override
  bool shouldReload(covariant LocalizationsDelegate<FormLocalization> old) =>
      false;
}

/// A `min` rule whose value is `navigation.x` needs the form's schema key to
/// look the navigation value up. The form page re-builds a field's validators
/// whenever a field it depends on changes (ValidationContextManager:
/// childrenCount depends on memberCount through `maxField`). That re-build
/// passed no schema key, so the navigation rule was dropped the first time
/// the user touched memberCount - and the children-count floor on household
/// edit (Liberia QA, 2026-11-25) with it.
///
/// Mounts the real form page and changes the two fields the way the user
/// does: member count first, then children count.
void main() {
  final schema = jsonEncode({
    'name': 'HOUSEHOLD',
    'version': 1,
    'pages': {
      'householdDetails': {
        'type': 'object',
        'order': 1,
        'label': 'Household details',
        'properties': {
          'memberCount': {
            'type': 'integer',
            'format': 'numeric',
            'label': 'Members',
            'order': 1,
            'value': '3',
            'validations': [
              {'type': 'min', 'value': '1', 'message': 'min members'},
            ],
          },
          'childrenCount': {
            'type': 'integer',
            'format': 'numeric',
            'label': 'Children',
            'order': 2,
            'value': '2',
            'validations': [
              {'type': 'min', 'value': '0', 'message': 'min children'},
              {'type': 'maxField', 'value': 'memberCount', 'message': 'max'},
              {
                'type': 'min',
                'value': 'navigation.registeredChildCount',
                'message': 'registered children',
              },
            ],
          },
        },
      },
    },
  });

  Future<FormGroup> mountPage(
    WidgetTester tester,
    Map<String, dynamic> navigationParams,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final bloc = FormsBloc();
    addTearDown(bloc.close);
    bloc.add(FormsEvent.load(schemas: [schema]));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [_Localization()],
      supportedLocales: const [Locale('en', 'US')],
      home: BlocProvider<FormsBloc>.value(
        value: bloc,
        child: FormsRenderPage(
          pageName: 'householdDetails',
          currentSchemaKey: 'HOUSEHOLD',
          isEdit: true,
          navigationParams: navigationParams,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final formElement = tester.element(find.byType(ReactiveFormConsumer).first);
    return ReactiveForm.of(formElement, listen: false) as FormGroup;
  }

  testWidgets('the floor holds before any other field is touched',
      (tester) async {
    final form = await mountPage(tester, {'registeredChildCount': 2});

    form.control('childrenCount').value = 1;
    await tester.pump();

    expect(form.control('childrenCount').errors.keys, contains('min'));
  });

  testWidgets('the floor still holds after the member count is changed',
      (tester) async {
    final form = await mountPage(tester, {'registeredChildCount': 2});

    // QA's order: members first, then children.
    form.control('memberCount').value = 4;
    await tester.pump();
    form.control('childrenCount').value = 0;
    await tester.pump();

    expect(form.control('childrenCount').errors.keys, contains('min'),
        reason: '2 children are registered; 0 is below them');

    // Children must stay below the member count (maxField is strict).
    form.control('childrenCount').value = 2;
    await tester.pump();
    expect(form.control('childrenCount').hasErrors, isFalse);

    form.control('memberCount').value = 2;
    await tester.pump();
    expect(form.control('childrenCount').errors.keys, ['maxField'],
        reason: '2 registered children need at least 3 members');
  });

  testWidgets('a floor error shown first is not cleared by a member change',
      (tester) async {
    final form = await mountPage(tester, {'registeredChildCount': 2});

    form.control('childrenCount').value = 1;
    await tester.pump();
    expect(form.control('childrenCount').errors.keys, contains('min'));

    form.control('memberCount').value = 4;
    await tester.pump();

    expect(form.control('childrenCount').errors.keys, contains('min'));
  });

  testWidgets('the member-count dependency itself keeps working',
      (tester) async {
    final form = await mountPage(tester, {'registeredChildCount': 0});

    form.control('memberCount').value = 1;
    await tester.pump();

    // children (2) > members (1)
    expect(form.control('childrenCount').hasErrors, isTrue);
    expect(form.control('childrenCount').errors.keys, isNot(contains('min')));
  });

  testWidgets('without the navigation value there is no floor', (tester) async {
    final form = await mountPage(tester, {'startPage': 'householdDetails'});

    form.control('memberCount').value = 2;
    await tester.pump();
    form.control('childrenCount').value = 0;
    await tester.pump();

    expect(form.control('childrenCount').hasErrors, isFalse);
  });
}
