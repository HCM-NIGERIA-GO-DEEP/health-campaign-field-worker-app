import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/widgets/json_schema_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
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

/// The Bales row of the stock Accept screen, built from the shipped config:
/// greyed out, filled from the dispatched quantity (60 pieces → 1.20).
void main() {
  late PropertySchema balesSchema;

  setUpAll(() {
    final flows =
        ((sampleInventoryFlows as Map)['flows'] as List).cast<Map<String, dynamic>>();
    final page = ((flows.firstWhere(
                (f) => f['name'] == 'stockReceiptDetails')['pages'] as List)
            .cast<Map<String, dynamic>>())
        .firstWhere((p) => p['page'] == 'stockReceiptDetails');
    balesSchema = PropertySchema.fromJson((page['properties'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['fieldName'] == 'bales'));
  });

  Future<FormGroup> pumpBales(WidgetTester tester, int? quantity,
      {PropertySchema? schema}) async {
    final form = FormGroup({
      'quantity': FormControl<int>(value: quantity),
      'bales': FormControl<String>(),
    });
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: [_FormDelegate()],
      home: Scaffold(
        body: ReactiveForm(
          formGroup: form,
          child: JsonFormBuilder(
            formControlName: 'bales',
            schema: schema ?? balesSchema,
            pageName: 'stockReceiptDetails',
            currentSchemaKey: 'stockReceiptDetails',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return form;
  }

  EditableText input(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  testWidgets('shows the dispatched pieces in bales', (tester) async {
    final form = await pumpBales(tester, 60);

    expect(input(tester).controller.text, '1.20');
    expect(form.control('bales').value, '1.20');
  });

  testWidgets('cannot be typed into', (tester) async {
    await pumpBales(tester, 60);

    expect(input(tester).readOnly, isTrue);
  });

  testWidgets('stays read-only even if the config forgets readOnly',
      (tester) async {
    await pumpBales(tester, 60, schema: balesSchema.copyWith(readOnly: false));

    expect(input(tester).readOnly, isTrue);
    expect(input(tester).controller.text, '1.20');
  });

  testWidgets('follows the quantity if it changes, and clears with it',
      (tester) async {
    final form = await pumpBales(tester, 60);

    form.control('quantity').value = 125;
    await tester.pumpAndSettle();
    expect(input(tester).controller.text, '2.50');

    form.control('quantity').value = null;
    await tester.pumpAndSettle();
    expect(input(tester).controller.text, '');
  });
}
