// ignore_for_file: depend_on_referenced_packages
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:digit_scanner/blocs/app_localization.dart';
import 'package:digit_scanner/blocs/scanner.dart';
import 'package:digit_scanner/utils/scanned_stock.dart';
import 'package:digit_scanner/utils/scanner_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';

/// Sierra Leone ITN, QA 2026-11-16 (stock Accept screen, bale/piece scanner).
/// The strings are QA's own:
/// - the same bale scanned twice was saved as two bales,
///   146402178112799266 and 176402178112799276. Only the second has a valid
///   GS1 check digit (the first should end in 2), so the first was a camera
///   misread;
/// - typing "(00)15640217811279927" on manual entry gave "not a bale or net
///   code": the "(00)" was not accepted, and the number has 17 digits, not 18.
void main() {
  const gs = '\x1d';
  const realBale = '176402178112799276';
  const misreadBale = '146402178112799266';
  const qaTyped = '(00)15640217811279927';

  final rules = scanTypeRulesFrom([
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
  ]);
  ScanTypeRule rule(String type) => rules.firstWhere((r) => r.type == type);

  Barcode detected(String value) => Barcode(
        type: BarcodeType.text,
        format: BarcodeFormat.code128,
        displayValue: value,
        rawValue: value,
        rawBytes: null,
        boundingBox: Rect.zero,
        cornerPoints: const [],
        value: null,
      );

  final sscc = detected('00$realBale');
  final misread = detected('00$misreadBale');
  // Net code whose GTIN ends in 3 instead of 2: a misread of the net label.
  final netBadGtin =
      detected('010764021781161311250400' '10104925${gs}2132ABD3F11');
  final net = detected('010764021781161211250400' '10104925${gs}2132ABD3F11');
  final contents = detected('020764021781161237' '50' '${gs}11250400' '10104925');

  group('camera: a code that fails its check digit is never taken', () {
    test('the misread bale alone gives nothing', () {
      expect(DigitScannerUtils.classifiedBarcode([misread], rules), isNull);
    });

    test('with the misread and the real SSCC in view, the real one is taken',
        () {
      final pick = DigitScannerUtils.classifiedBarcode([misread, sscc], rules);
      expect(pick?.key, same(sscc));
    });

    test('a net with a wrong GTIN check digit gives nothing', () {
      expect(DigitScannerUtils.classifiedBarcode([netBadGtin], rules), isNull);
    });

    test('valid bale and net codes are still taken', () {
      expect(DigitScannerUtils.classifiedBarcode([sscc], rules)?.key,
          same(sscc));
      expect(
          DigitScannerUtils.classifiedBarcode([net], rules)?.key, same(net));
    });
  });

  group('manual entry: what QA typed', () {
    test('a bale number typed with its "(00)" or with spaces is accepted', () {
      for (final typed in [
        '(00)$realBale',
        ' (00) 1764 0217 8112 7992 76 ',
        '1764 0217 8112 7992 76',
      ]) {
        final code = typedManualCode(typed, rule('bale'), rules);
        expect(code, isNotNull, reason: typed);
        expect(gs1HumanReadable(code!), '(00)$realBale', reason: typed);
      }
    });

    test('a net serial typed with its "(21)" is accepted', () {
      final code = typedManualCode('(21)32ABD3F11', rule('piece'), rules);
      expect(gs1HumanReadable(code!), '(21)32ABD3F11');
    });

    test("QA's 17-digit entry and the misread number stay refused", () {
      expect(typedManualCode(qaTyped, rule('bale'), rules), isNull);
      expect(typedManualCode(misreadBale, rule('bale'), rules), isNull);
    });

    test('a net serial holding brackets is refused, not saved', () {
      // GS1 allows "(" and ")" in a serial, so "(00)123" would otherwise be
      // saved as net serial "(00)123".
      expect(typedManualCode('(00)123', rule('piece'), rules), isNull);
    });
  });

  group('manual entry: the error says what is wrong', () {
    // No localization loaded: translate gives the key back, as the scanner's
    // ScannerLocalization does, so the English defaults are shown.
    String untranslated(String key) => key;
    const translations = {
      'INVENTORY_SCAN_TYPE_BALE': 'Bale',
      'INVENTORY_SCAN_TYPE_PIECE': 'Piece',
    };
    String labelsOnly(String key) => translations[key] ?? key;

    String messageFor(String typed, String type,
        {String Function(String)? translate}) {
      final check = checkTypedManualCode(typed, rule(type), rules);
      expect(check.code, isNull, reason: '$typed must be refused');
      return manualCodeProblemMessage(
          check, rule(type), translate ?? untranslated,
          otherKindMessage: 'UNKNOWN');
    }

    test("QA's entry: says a bale number has 18 digits and 17 were typed",
        () {
      final check = checkTypedManualCode(qaTyped, rule('bale'), rules);
      expect(check.problem, ManualCodeProblem.wrongLength);
      expect(messageFor(qaTyped, 'bale', translate: labelsOnly),
          'Bale number must be 18 digits. You typed 17.');
    });

    test('the misread number: says a digit is wrong', () {
      expect(checkTypedManualCode(misreadBale, rule('bale'), rules).problem,
          ManualCodeProblem.wrongCheckDigit);
      expect(
          messageFor(misreadBale, 'bale', translate: labelsOnly),
          'Bale number 146402178112799266 is not valid: a digit is wrong or '
          'two digits are swapped. Check it against the label.');
    });

    test('letters in a bale number: says digits only', () {
      expect(
          checkTypedManualCode('1764021781127992X6', rule('bale'), rules)
              .problem,
          ManualCodeProblem.notDigits);
      expect(messageFor('1764021781127992X6', 'bale', translate: labelsOnly),
          'Bale number can only contain digits. Type the 18 digits printed '
          'after (00).');
    });

    test('a bad net serial: says what a serial may hold', () {
      for (final bad in ['(00)123', '(21)', '123456789012345678901']) {
        expect(checkTypedManualCode(bad, rule('piece'), rules).problem,
            ManualCodeProblem.invalidSerial,
            reason: bad);
      }
      expect(
          messageFor('(00)123', 'piece', translate: labelsOnly),
          'Piece serial must be 1 to 20 letters or digits, typed after (21), '
          'with no spaces or brackets.');
    });

    test('without a label translation the kind name comes from the rule', () {
      expect(messageFor(qaTyped, 'bale'),
          'Bale number must be 18 digits. You typed 17.');
    });

    test('a localized message replaces the English and fills placeholders',
        () {
      String localized(String key) => key == 'SCANNER_MANUAL_CODE_WRONG_LENGTH'
          ? '{kind}: {expected} required, {count} typed ({code})'
          : labelsOnly(key);
      expect(messageFor(qaTyped, 'bale', translate: localized),
          'Bale: 18 required, 17 typed (15640217811279927)');
    });

    test('an accepted code gives no message', () {
      final check = checkTypedManualCode(realBale, rule('bale'), rules);
      expect(check.problem, isNull);
      expect(
          manualCodeProblemMessage(check, rule('bale'), untranslated,
              otherKindMessage: 'UNKNOWN'),
          '');
    });
  });

  group('camera frame handling (processImage)', () {
    Future<_FrameOutcome> runFrame(
        WidgetTester tester, List<Barcode> inView) async {
      final outcome = _FrameOutcome();
      late BuildContext context;
      await tester.pumpWidget(BlocProvider(
        create: (_) => DigitScannerBloc(const DigitScannerState()),
        child: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ));
      await DigitScannerUtils().processImage(
        context: context,
        inputImage: InputImage.fromBytes(
          bytes: Uint8List(1),
          metadata: InputImageMetadata(
            size: const Size(1, 1),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: 1,
          ),
        ),
        canProcess: true,
        isBusy: false,
        setBusy: (bool busy) => outcome.busy = busy,
        setText: (_) {},
        updateCustomPaint: (_) {},
        isGS1code: true,
        quantity: typedScanNoLimit,
        result: const [],
        handleError: (String message) async => outcome.errors.add(message),
        storeValue: (GS1Barcode code) async => outcome.stored.add(code),
        storeCode: (_) async {},
        cameraLensDirection: CameraLensDirection.back,
        barcodeScanner: _FakeBarcodeScanner(inView),
        localizations:
            ScannerLocalization(const Locale('en', 'SL'), Future.value([]), []),
        scanTypeRules: rules,
        unknownCodeMessage: 'INVENTORY_SCAN_UNKNOWN_STOCK_CODE',
      );
      return outcome;
    }

    testWidgets('a misread frame is skipped quietly and scanning goes on',
        (tester) async {
      final outcome = await runFrame(tester, [misread]);
      expect(outcome.stored, isEmpty);
      expect(outcome.errors, isEmpty,
          reason: 'a misread is a bad frame, not a wrong label');
      expect(outcome.busy, isFalse, reason: 'the camera must not stay busy');
    });

    testWidgets('the real SSCC is stored', (tester) async {
      final outcome = await runFrame(tester, [sscc]);
      expect(outcome.stored.map(gs1HumanReadable), ['(00)$realBale']);
      expect(outcome.errors, isEmpty);
    });

    testWidgets("the bale's contents barcode alone still shows the error",
        (tester) async {
      final outcome = await runFrame(tester, [contents]);
      expect(outcome.stored, isEmpty);
      expect(outcome.errors, ['INVENTORY_SCAN_UNKNOWN_STOCK_CODE']);
    });
  });
}

class _FrameOutcome {
  bool? busy;
  final errors = <String>[];
  final stored = <GS1Barcode>[];
}

class _FakeBarcodeScanner extends BarcodeScanner {
  _FakeBarcodeScanner(this.inView);

  final List<Barcode> inView;

  @override
  Future<List<Barcode>> processImage(InputImage inputImage) async => inView;
}
