// ignore_for_file: depend_on_referenced_packages
import 'dart:ui';

import 'package:digit_scanner/utils/scanned_stock.dart';
import 'package:digit_scanner/utils/scanner_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// A bale label carries two barcodes. With both in the camera's view, the
/// bale/piece scanner must take the SSCC (00) one - the other is the same on
/// every bale of a batch - whichever order the camera reports them in.
void main() {
  const gs = '\x1d';
  final rules = scanTypeRulesFrom([
    {'type': 'bale', 'ai': '00', 'saveKey': 'baleScannedStock'},
    {'type': 'piece', 'ai': '21', 'saveKey': 'piecesScannedStock'},
  ]);

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

  final contents =
      detected('020764021781161237' '50' '${gs}11250400' '10104925');
  final sscc = detected('00176402178112799276');

  test('picks the SSCC even when the contents barcode comes first', () {
    final pick =
        DigitScannerUtils.classifiedBarcode([contents, sscc], rules);
    expect(pick?.key, same(sscc));
    expect(pick?.value.getAIRawData('00'), '176402178112799276');
  });

  test('gives nothing when no code in view is a bale or a piece', () {
    expect(DigitScannerUtils.classifiedBarcode([contents], rules), isNull);
    expect(
        DigitScannerUtils.classifiedBarcode([detected('not gs1')], rules),
        isNull);
  });
}
