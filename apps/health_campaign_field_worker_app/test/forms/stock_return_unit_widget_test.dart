import 'dart:convert';

import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/widgets/json_schema_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// The return unit fields of the stock product details page, built from the
/// shipped config, for two product tabs: each tab's Bales/Pieces pick shows
/// or hides its own Pieces row and relabels its own quantity.
void main() {
  const fields = ['returnUnit', 'quantityReturned', 'quantityReturnedPieces'];
  const balesLabel = 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_BALES';
  const piecesLabel = 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_PIECES';

  late Map<String, Map<String, dynamic>> config;

  setUpAll(() {
    final page = (((sampleInventoryFlows as Map)['flows'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((f) => f['name'] == 'RECORDSTOCK')['pages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['page'] == 'stockProductDetails');
    config = {
      for (final p in (page['properties'] as List).cast<Map<String, dynamic>>())
        if (fields.contains(p['fieldName'])) p['fieldName'] as String: p,
    };
  });

  // Showing or hiding a field re-validates its control, which rebuilds the
  // form's fields again, so frames never settle; a few are enough here.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // Unmounts, and lets out any timer a field widget left running.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  Future<FormGroup> pumpTabs(WidgetTester tester) async {
    final bloc = FormsBloc()
      ..add(FormsEvent.load(schemas: [
        jsonEncode({
          'name': 'RECORDSTOCK',
          'version': 1,
          'pages': {
            'stockProductDetails': {
              'type': 'object',
              'order': 1,
              'properties': config,
            },
          },
        }),
      ]));
    await bloc.stream.first;

    final form = FormGroup({
      for (final tab in [0, 1]) ...{
        'returnUnit_item_$tab': FormControl<String>(value: 'PIECES'),
        'quantityReturned_item_$tab': FormControl<int>(),
        'quantityReturnedPieces_item_$tab': FormControl<String>(),
      },
    });

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: [_FormDelegate()],
      home: BlocProvider.value(
        value: bloc,
        child: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: ListView(children: [
              for (final tab in [0, 1])
                for (final name in fields)
                  JsonFormBuilder(
                    key: ValueKey('${name}_item_$tab'),
                    formControlName: '${name}_item_$tab',
                    schema: PropertySchema.fromJson(config[name]!),
                    pageName: 'stockProductDetails',
                    currentSchemaKey: 'RECORDSTOCK',
                    navigationParams: {
                      'stockEntryType': 'RETURNED',
                      'currentEntityIndex': tab,
                    },
                  ),
            ]),
          ),
        ),
      ),
    ));
    await settle(tester);
    return form;
  }

  Finder label(String code) => find.textContaining(code);

  testWidgets('Pieces by default: one quantity field, in pieces',
      (tester) async {
    final form = await pumpTabs(tester);

    expect(label(piecesLabel), findsNWidgets(2));
    expect(label(balesLabel), findsNothing);
    expect(form.control('quantityReturnedPieces_item_0').value, isNull);

    await finish(tester);
  });

  testWidgets('Bales on one product adds its own Pieces row, worked out',
      (tester) async {
    final form = await pumpTabs(tester);

    form.control('returnUnit_item_0').value = 'BALES';
    await settle(tester);
    form.control('quantityReturned_item_0').value = 3;
    await settle(tester);

    // Tab 0: quantity in bales plus its Pieces row; tab 1 still pieces.
    expect(label(balesLabel), findsOneWidget);
    expect(label(piecesLabel), findsNWidgets(2));
    expect(form.control('quantityReturnedPieces_item_0').value, '150');
    expect(form.control('quantityReturnedPieces_item_1').value, isNull);

    await finish(tester);
  });

  testWidgets('back to Pieces hides the Pieces row and clears it',
      (tester) async {
    final form = await pumpTabs(tester);

    form.control('returnUnit_item_0').value = 'BALES';
    await settle(tester);
    form.control('quantityReturned_item_0').value = 3;
    await settle(tester);
    form.control('returnUnit_item_0').value = 'PIECES';
    await settle(tester);

    expect(label(balesLabel), findsNothing);
    expect(label(piecesLabel), findsNWidgets(2));
    expect(form.control('quantityReturnedPieces_item_0').value, isNull);

    await finish(tester);
  });
}
