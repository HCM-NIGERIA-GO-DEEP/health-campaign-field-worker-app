import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/widgets/json_schema_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  testWidgets('counter taps and steppers leave the caret after the number',
      (tester) async {
    final form = FormGroup({'memberCount': FormControl<int>(value: 12)});
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: [
        _FormDelegate(),
      ],
      home: Scaffold(
        body: ReactiveForm(
          formGroup: form,
          child: JsonSchemaIntegerBuilder(
            form: form,
            formControlName: 'memberCount',
            label: 'Member count',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final input = find.byType(EditableText);
    final controller = tester.widget<EditableText>(input).controller;
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
    await tester.tapAt(tester.getCenter(input) - const Offset(15, 0));
    await tester.pumpAndSettle();
    expect(controller.selection, const TextSelection.collapsed(offset: 2));

    final increments = <TextEditingValue>[];
    void record() => increments.add(controller.value);
    controller.addListener(record);
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    controller.removeListener(record);
    expect(increments.where((value) => value.text == '13'), isNotEmpty);
    expect(increments.where((value) => value.text == '13')
        .every((value) => value.selection == const TextSelection.collapsed(offset: 2)), isTrue);
    expect(form.control('memberCount').value, 13);
    expect(controller.text, '13');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));

    await tester.tap(find.text('-'));
    await tester.pumpAndSettle();
    expect(form.control('memberCount').value, 12);
    expect(controller.selection, const TextSelection.collapsed(offset: 2));

    await tester.enterText(input, '125');
    await tester.pumpAndSettle();
    expect(form.control('memberCount').value, 125);
    expect(controller.selection, const TextSelection.collapsed(offset: 3));

    // Deliberate caret movement and editing must survive reactive rebuilds.
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pumpAndSettle();
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '15', selection: TextSelection.collapsed(offset: 1),
    ));
    await tester.pumpAndSettle();
    expect(form.control('memberCount').value, 15);
    expect(controller.selection, const TextSelection.collapsed(offset: 1));

    await tester.enterText(input, '');
    await tester.pumpAndSettle();
    expect(form.control('memberCount').value, isNull);
    expect(controller.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    form.dispose();
  });
}
