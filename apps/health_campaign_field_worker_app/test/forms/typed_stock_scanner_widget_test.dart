// ignore_for_file: depend_on_referenced_packages
import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/widgets/json_schema_builder.dart';
import 'package:digit_scanner/blocs/scanner.dart';
import 'package:digit_scanner/utils/scanned_stock.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';
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

/// The bale/piece scanner on the stock Accept screen, as configured: what it
/// keeps in the form and what it shows under the button.
void main() {
  const field = 'scannedStock';
  const gs = '\x1d';
  const baleSscc = '00176402178112799276';
  const baleContents = '020764021781161237' '50' '${gs}11250400' '10104925';
  const net1 = '010764021781161211250400' '10104925${gs}2132ABD3F11';
  const net2 = '010764021781161211250600' '10600725${gs}215EF6E92D5';

  final rulesJson = [
    {
      'type': 'bale',
      'ai': '00',
      'saveKey': 'baleScannedStock',
      'label': 'INVENTORY_SCAN_TYPE_BALE',
    },
    {
      'type': 'piece',
      'ai': '21',
      'saveKey': 'piecesScannedStock',
      'label': 'INVENTORY_SCAN_TYPE_PIECE',
    },
  ];
  final rules = scanTypeRulesFrom(rulesJson);
  final validations = [
    const ValidationRule(type: 'isGS1', value: true),
    ValidationRule(
        type: 'scanTypes',
        value: rulesJson,
        message: 'INVENTORY_SCAN_UNKNOWN_STOCK_CODE'),
  ];

  GS1Barcode parse(String code) => GS1BarcodeParser.defaultParser().parse(code);

  String valueOf(List<String> codes) => encodeScannedStock(
      codes.map((c) => scannedStockEntryFor(parse(c), rules)!).toList());

  Future<(FormGroup, DigitScannerBloc)> pump(WidgetTester tester,
      {String? value}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final form = FormGroup({field: FormControl<String>(value: value)});
    final bloc = DigitScannerBloc(const DigitScannerState());
    addTearDown(bloc.close);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: [_FormDelegate()],
      home: Scaffold(
        body: BlocProvider.value(
          value: bloc,
          child: SingleChildScrollView(
            child: ReactiveForm(
              formGroup: form,
              child: JsonSchemaScannerBuilder(
                form: form,
                formControlName: field,
                label: 'INVENTORY_SCAN_STOCK_LABEL',
                validations: validations,
                summaryData: true,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (form, bloc);
  }

  DigitButton scanButton(WidgetTester tester) =>
      tester.widget<DigitButton>(find.byType(DigitButton));

  testWidgets('lists each scanned bale and piece by its ID, with counts',
      (tester) async {
    await pump(tester, value: valueOf([baleSscc, net1, net2]));

    expect(find.text('176402178112799276'), findsOneWidget);
    expect(find.text('32ABD3F11'), findsOneWidget);
    expect(find.text('5EF6E92D5'), findsOneWidget);
    expect(find.text('INVENTORY_SCAN_TYPE_BALE'), findsOneWidget);
    expect(find.text('INVENTORY_SCAN_TYPE_PIECE'), findsNWidgets(2));
    expect(
        find.text('INVENTORY_SCAN_TYPE_BALE: 1   INVENTORY_SCAN_TYPE_PIECE: 2'),
        findsOneWidget);
    expect(scanButton(tester).isDisabled, isFalse,
        reason: 'no limit: more can always be scanned');
  });

  testWidgets('with nothing scanned the button is ready', (tester) async {
    await pump(tester);

    expect(scanButton(tester).isDisabled, isFalse);
  });

  testWidgets(
      'keeps what the scanner returns, as bales and pieces, in scan order',
      (tester) async {
    final (form, bloc) = await pump(tester);

    bloc.add(DigitScannerEvent.handleScanner(
      barCode: [parse(net1), parse(baleSscc), parse(baleContents)],
      scannerId: field,
    ));
    await tester.pumpAndSettle();

    final entries = decodeScannedStock(form.control(field).value as String?);
    expect(entries.map((e) => e.saveKey),
        ['piecesScannedStock', 'baleScannedStock'],
        reason: "the bale's contents barcode is neither, so it is dropped");
    expect(entries.map((e) => e.code), [
      '(01)07640217811612(11)250400(10)104925(21)32ABD3F11',
      '(00)176402178112799276',
    ]);
  });

  testWidgets('clears the value when every scan is removed', (tester) async {
    final (form, bloc) = await pump(tester, value: valueOf([baleSscc]));

    bloc.add(const DigitScannerEvent.handleScanner(scannerId: field));
    await tester.pumpAndSettle();

    expect(form.control(field).value, isNull);
  });
}
