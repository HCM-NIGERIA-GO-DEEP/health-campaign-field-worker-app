// ignore_for_file: depend_on_referenced_packages
import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:digit_forms_engine/widgets/json_schema_builder.dart';
import 'package:digit_scanner/blocs/scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// Sierra Leone QA (Warehouse Details): the scanned Team Code showed
/// "si-dis-01 : <uuid>". It now shows "si-dis-01", while the form still holds
/// "si-dis-01||<uuid>" for getStockTeamCode / getStockTeamName to save.
void main() {
  const field = 'teamCode';
  const uuid = 'f6088ef4-92f3-4286-8d16-40b0df3327ca';
  const teamQr = 'si-dis-01||$uuid';

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
                label: 'Team Code',
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

  Finder textContaining(String part) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(part));

  testWidgets('a scanned team QR shows the username, not the uuid',
      (tester) async {
    final (form, bloc) = await pump(tester);

    bloc.add(const DigitScannerEvent.handleScanner(
      qrCode: [teamQr],
      scannerId: field,
    ));
    await tester.pumpAndSettle();

    expect(find.text('si-dis-01'), findsOneWidget);
    expect(textContaining(uuid), findsNothing);
    expect(form.control(field).value, teamQr,
        reason: 'the saved value keeps the uuid for receiverId');
  });

  testWidgets('a team code already in the form (re-opened page) shows the '
      'username', (tester) async {
    final (form, _) = await pump(tester, value: teamQr);

    expect(find.text('si-dis-01'), findsOneWidget);
    expect(textContaining(uuid), findsNothing);
    expect(form.control(field).value, teamQr);
  });

  testWidgets('an old uuid-only QR still shows the uuid', (tester) async {
    await pump(tester, value: uuid);

    expect(find.text(uuid), findsOneWidget);
  });
}
