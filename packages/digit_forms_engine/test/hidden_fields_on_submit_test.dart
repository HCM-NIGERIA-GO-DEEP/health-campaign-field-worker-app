// QA (2026-11-13): editing a child's DOB to under 12 months hid Height, but the
// old height stayed on the record. The edit merge cannot tell "the user's
// edit hid this field" from "the field came back empty", so the forms
// engine now records, on the page it saves, which fields the user saw and
// then hid through their visibilityCondition. These tests drive the real
// FormsRenderPage button and read the record from the submitted schema.

import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_forms_engine/helper/visibility_manager.dart';
import 'package:digit_forms_engine/router/forms_router.dart';
import 'package:digit_forms_engine/router/forms_router.gm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'widget_test.dart' show TestFormLocalizationDelegate;

const _schemaKey = 'ADD_MEMBER';

Map<String, dynamic> _textField(int order, {String? visibleWhen}) => {
      'type': 'string',
      'format': 'text',
      'label': 'FIELD_$order',
      'order': order,
      'value': '',
      if (visibleWhen != null)
        'visibilityCondition': {
          'expression': [
            {'condition': visibleWhen},
          ],
        },
    };

/// A page like ADD_MEMBER's beneficiaryDetails: Height shows only for older
/// children. Choosing "not older" submits straight away (submitCondition),
/// so the second page is never opened.
/// [isOlderDefault] is the config's own value for isOlder.
String _schema({String? isOlderDefault}) => jsonEncode({
      'name': _schemaKey,
      'version': 1,
      'pages': {
        'beneficiaryDetails': {
          'type': 'object',
          'label': 'DETAILS',
          'order': 1,
          'actionLabel': 'SAVE',
          'submitCondition': {
            'expression': [
              {'condition': 'beneficiaryDetails.isOlder==NO'},
            ],
          },
          'properties': {
            'isOlder': {
              'type': 'string',
              'format': 'radio',
              'label': 'IS_OLDER',
              'order': 1,
              if (isOlderDefault != null) 'value': isOlderDefault,
              'enums': [
                {'code': 'YES', 'name': 'YES'},
                {'code': 'NO', 'name': 'NO'},
              ],
            },
            'height': {
              ..._textField(2, visibleWhen: 'beneficiaryDetails.isOlder==YES'),
              'validations': [
                {'type': 'required', 'value': true, 'message': 'Required'},
              ],
            },
            'notes': _textField(3),
          },
        },
        'extraDetails': {
          'type': 'object',
          'label': 'EXTRA',
          'order': 2,
          'properties': {
            'muac':
                _textField(1, visibleWhen: 'beneficiaryDetails.isOlder==YES'),
          },
        },
      },
    });

/// This page keeps scheduling frames, so pumpAndSettle never returns; pump a
/// fixed second instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A blank home page with the forms engine's own render route on top.
class _TestRouter extends RootStackRouter {
  @override
  Map<String, PageFactory> get pagesMap => {
        'Home': (data) => AutoRoutePage<dynamic>(
              routeData: data,
              child: const SizedBox.shrink(),
            ),
        ...FormsRoute().pagesMap,
      };

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: const PageInfo('Home'), path: '/', initial: true),
        AutoRoute(page: FormsRenderRoute.page, path: '/forms-render/:pageName'),
      ];
}

void main() {
  late FormsBloc bloc;
  FormsSubmittedState? submitted;

  /// Opens the page in edit mode with [defaults], lets [edit] (and then
  /// [thenEdit], after the page rebuilt) change the live form, then presses
  /// SAVE.
  Future<void> editAndSave(
    WidgetTester tester, {
    required Map<String, dynamic> defaults,
    required void Function(FormGroup form) edit,
    void Function(FormGroup form)? thenEdit,
    String? isOlderDefault,
  }) async {
    bloc = FormsBloc()
      ..add(
          FormsEvent.load(schemas: [_schema(isOlderDefault: isOlderDefault)]));
    // Not awaited: bloc.close() never completes under the fake-async clock
    // (same as widget_test.dart's tearDown).
    addTearDown(() {
      bloc.close();
    });
    submitted = null;
    final sub = bloc.stream.listen((state) {
      if (state is FormsSubmittedState) submitted = state;
    });
    addTearDown(sub.cancel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The page pops its routes through auto_route after submitting, so it is
    // opened the way the app opens it: pushed on a router.
    final router = _TestRouter();
    await tester.pumpWidget(BlocProvider<FormsBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: router.config(),
        localizationsDelegates: const [TestFormLocalizationDelegate()],
        supportedLocales: const [Locale('en', 'US')],
      ),
    ));
    await _settle(tester);
    router.push(FormsRenderRoute(
      pageName: 'beneficiaryDetails',
      currentSchemaKey: _schemaKey,
      isEdit: true,
      defaultValues: defaults,
    ));
    await _settle(tester);

    FormGroup form() =>
        tester.widget<ReactiveForm>(find.byType(ReactiveForm).first).formGroup;
    edit(form());
    await _settle(tester);
    if (thenEdit != null) {
      thenEdit(form());
      await _settle(tester);
    }

    await tester.tap(find.text('Save'));
    await _settle(tester);
  }

  testWidgets('reports a field the user saw and then hid, with no value',
      (tester) async {
    await editAndSave(
      tester,
      defaults: {'isOlder': 'YES', 'height': '85', 'notes': 'n'},
      edit: (form) => form.control('isOlder').value = 'NO',
    );

    expect(submitted, isNotNull);
    expect(submitted!.formData['beneficiaryDetails']!['height'], isNull);
    expect(hiddenFieldPaths(submitted!.schema.pages),
        {'beneficiaryDetails.height'});
  });

  testWidgets('does not report a page the user never opened', (tester) async {
    await editAndSave(
      tester,
      defaults: {'isOlder': 'YES', 'height': '85'},
      edit: (form) => form.control('isOlder').value = 'NO',
    );

    // extraDetails.muac is hidden by the same rule but its page was skipped.
    expect(submitted!.formData['extraDetails']!['muac'], isNull);
    expect(hiddenFieldPaths(submitted!.schema.pages),
        isNot(contains('extraDetails.muac')));
  });

  testWidgets('does not report a visible optional field left empty',
      (tester) async {
    await editAndSave(
      tester,
      defaults: {'isOlder': 'NO', 'notes': 'n'},
      edit: (form) => form.control('notes').value = null,
    );

    expect(submitted!.formData['beneficiaryDetails']!['notes'], isNull);
    expect(hiddenFieldPaths(submitted!.schema.pages),
        isNot(contains('beneficiaryDetails.notes')));
  });

  testWidgets('does not report a field hidden from the start', (tester) async {
    // As for a head of household whose DOB field is hidden by
    // `navigation.isHead==false`: the user never saw it, so its stored value
    // is not theirs to clear.
    await editAndSave(
      tester,
      defaults: {'isOlder': 'NO', 'height': '85'},
      edit: (_) {},
    );

    expect(submitted, isNotNull);
    expect(hiddenFieldPaths(submitted!.schema.pages), isEmpty);
  });

  testWidgets('does not report a field hidden and then shown again',
      (tester) async {
    await editAndSave(
      tester,
      defaults: {'isOlder': 'YES', 'height': '85'},
      edit: (form) => form.control('isOlder').value = 'NO',
      thenEdit: (form) => form
        ..control('isOlder').value = 'YES'
        ..control('height').value = '90',
    );
    // isOlder is YES again, so SAVE moved on to the second page.
    await tester.tap(find.text('Submit'));
    await _settle(tester);

    expect(submitted!.formData['beneficiaryDetails']!['height'], '90');
    expect(hiddenFieldPaths(submitted!.schema.pages), isEmpty);
  });

  testWidgets('reports a hidden field even when saving changes no value',
      (tester) async {
    // The config's own isOlder is NO, so once the user picks NO the saved
    // page equals the one the form holds and the bloc keeps the one it has.
    await editAndSave(
      tester,
      isOlderDefault: 'NO',
      defaults: {'isOlder': 'YES', 'height': '85'},
      edit: (form) => form.control('isOlder').value = 'NO',
    );

    expect(submitted, isNotNull);
    expect(hiddenFieldPaths(submitted!.schema.pages),
        {'beneficiaryDetails.height'});
  });

  testWidgets('forgets the record once the form is cleared', (tester) async {
    await editAndSave(
      tester,
      defaults: {'isOlder': 'YES', 'height': '85'},
      edit: (form) => form.control('isOlder').value = 'NO',
    );
    expect(hiddenFieldPaths(submitted!.schema.pages), isNotEmpty);

    bloc.add(const FormsEvent.clearForm(schemaKey: _schemaKey));
    await tester.pump();

    expect(
        hiddenFieldPaths(bloc.state.cachedSchemas[_schemaKey]!.pages), isEmpty);
  });
}
