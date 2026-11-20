import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/widgets/json_schema_builder.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart'
    show ValueDropdownItem;
import 'package:reactive_forms/reactive_forms.dart';

class _FormDelegate extends LocalizationsDelegate<FormLocalization> {
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FormLocalization> load(Locale locale) async =>
      FormLocalization(locale, Future.value([]), []);

  @override
  bool shouldReload(_FormDelegate old) => false;
}

/// MultiSelectDropDown checks its preselected items against its options with
/// `contains`, and keeps its first build's options. Callers build both lists
/// fresh on every build, as the stock product selection card and boundary
/// selection do, so a plain DropdownItem never matches and the dropdown
/// throws "Cannot select options that are not in the options list".
void main() {
  Widget dropdown(DropdownItem Function(String code) item, String? selected) =>
      MaterialApp(
        home: Scaffold(
          body: MultiSelectDropDown(
            options: [item('ITN'), item('SPAQ')],
            initialOptions: selected == null ? null : [item(selected)],
            onOptionSelected: (_) {},
          ),
        ),
      );

  Future<Object?> preselectThenRebuild(
      WidgetTester tester, DropdownItem Function(String code) item) async {
    // First build with a preselected item, then a parent rebuild (e.g. the
    // form control being filled in) hands it fresh lists.
    await tester.pumpWidget(dropdown(item, 'ITN'));
    await tester.pump();
    final first = tester.takeException();
    await tester.pumpWidget(dropdown(item, 'ITN'));
    await tester.pumpAndSettle();
    return first ?? tester.takeException();
  }

  testWidgets('a plain DropdownItem preselection throws (the package bug)',
      (tester) async {
    final error = await preselectThenRebuild(
        tester, (code) => DropdownItem(code: code, name: code));

    expect(error.toString(),
        contains('Cannot select options that are not in the options list'));
  });

  testWidgets('a ValueDropdownItem preselection does not', (tester) async {
    final error = await preselectThenRebuild(
        tester, (code) => ValueDropdownItem(code: code, name: code));

    expect(error, isNull);
  });

  testWidgets('a forms multiselect with a saved value does not throw',
      (tester) async {
    // The forms engine keeps a multiselect's value as dot-separated codes.
    final form = FormGroup({'reasons': FormControl<String>(value: 'LOST.DAMAGED')});
    Widget build() => MaterialApp(
          localizationsDelegates: [_FormDelegate()],
          home: Scaffold(
            body: ReactiveForm(
              formGroup: form,
              child: JsonSchemaDropdownBuilder(
                formControlName: 'reasons',
                form: form,
                isMultiselect: true,
                enums: const [
                  Option(code: 'LOST', name: 'LOST'),
                  Option(code: 'DAMAGED', name: 'DAMAGED'),
                  Option(code: 'EXPIRED', name: 'EXPIRED'),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump();
    final first = tester.takeException();
    form.control('reasons').value = 'LOST';
    await tester.pumpAndSettle();

    expect(first ?? tester.takeException(), isNull);
  });

  test('ValueDropdownItems are equal by code', () {
    expect(const ValueDropdownItem(code: 'ITN', name: 'ITN'),
        const ValueDropdownItem(code: 'ITN', name: 'Nets'));
    expect(const ValueDropdownItem(code: 'ITN', name: 'ITN'),
        isNot(const ValueDropdownItem(code: 'SPAQ', name: 'ITN')));
    expect(
        {
          const ValueDropdownItem(code: 'ITN', name: 'a'),
          const ValueDropdownItem(code: 'ITN', name: 'b'),
        },
        hasLength(1));
  });
}
