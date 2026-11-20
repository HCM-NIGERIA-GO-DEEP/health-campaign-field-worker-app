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

  // The bales row is hidden for a registrar or distributor, who type the
  // pieces received instead. The visibility condition needs the forms bloc,
  // which this test has no use for, so it is left off here; when the row
  // shows is covered in test/config/stock_quantity_in_pieces_test.dart.
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
            schema: (schema ?? balesSchema).copyWith(visibilityCondition: null),
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

  /// The Quantity Received (Pieces) row of the stock product details page: a
  /// warehouse manager types the received quantity in bales, and this row
  /// shows it in pieces (3 bales → 150), greyed out.
  group('Quantity Received (Pieces) on product details', () {
    Map<String, dynamic> productDetailsPage(Map flows) =>
        ((flows['flows'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((f) => f['name'] == 'RECORDSTOCK')['pages'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['page'] == 'stockProductDetails');

    Map<String, dynamic> property(Map<String, dynamic> page, String name) =>
        (page['properties'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['fieldName'] == name);

    late PropertySchema piecesSchema;

    setUpAll(() {
      piecesSchema = PropertySchema.fromJson(property(
          productDetailsPage(sampleInventoryFlows as Map),
          'quantityReceivedPieces'));
    });

    test('is worked out from the bales received, 50 pieces per bale', () {
      expect(piecesSchema.type, PropertySchemaType.string);
      expect(
          piecesSchema.computedValue,
          const ComputedValueConfig(
              sourceField: 'quantityReceived', multiplyBy: 50, decimals: 0));
      expect(piecesSchema.readOnly, isFalse,
          reason: 'true would make every product tab share one value');
      expect(piecesSchema.validations, isEmpty);
    });

    test('sits right under the received quantity', () {
      final page = productDetailsPage(sampleInventoryFlows as Map);
      final received = property(page, 'quantityReceived')['order'] as num;
      final comment = property(page, 'comment')['order'] as num;
      expect(piecesSchema.order, greaterThan(received));
      expect(piecesSchema.order, lessThan(comment));
    });

    Future<FormGroup> pumpPieces(WidgetTester tester, int? bales) async {
      // Product details is a multi-product page, so its controls carry the
      // product suffix. The visibility condition needs the forms bloc, which
      // this test has no use for, so it is left off here; when the row shows
      // is covered in test/config/stock_quantity_in_pieces_test.dart.
      final form = FormGroup({
        'quantityReceived_item_0': FormControl<int>(value: bales),
        'quantityReceivedPieces_item_0': FormControl<String>(),
      });
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: [_FormDelegate()],
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: JsonFormBuilder(
              formControlName: 'quantityReceivedPieces_item_0',
              schema: piecesSchema.copyWith(visibilityCondition: null),
              pageName: 'stockProductDetails',
              currentSchemaKey: 'RECORDSTOCK',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return form;
    }

    testWidgets('shows the bales received in pieces, read-only',
        (tester) async {
      final form = await pumpPieces(tester, 3);

      expect(input(tester).controller.text, '150');
      expect(input(tester).readOnly, isTrue);
      expect(form.control('quantityReceivedPieces_item_0').value, '150');
    });

    testWidgets('follows the bales as they are typed, and clears with them',
        (tester) async {
      final form = await pumpPieces(tester, null);
      expect(input(tester).controller.text, '');

      form.control('quantityReceived_item_0').value = 12;
      await tester.pumpAndSettle();
      expect(input(tester).controller.text, '600');

      form.control('quantityReceived_item_0').value = null;
      await tester.pumpAndSettle();
      expect(input(tester).controller.text, '');
    });
  });
}
