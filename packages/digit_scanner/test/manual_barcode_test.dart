import 'package:digit_scanner/utils/scanner_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';

void main() {
  test('manual serial round trips without an expiry', () {
    final utils = DigitScannerUtils();
    final barcode = GS1BarcodeParser.defaultParser().parse(
      utils.generateGS1Barcode(
        batchNumber: 'MANUAL',
        gtin: '00000000000000',
        serialNumber: 'manual123',
      ),
    );
    final saved = utils.serializeGs1Barcodes([barcode]);
    final restored = DigitScannerUtils.deserializeGs1Barcodes(saved).single;
    expect(restored['21'], 'manual123');
    expect(restored['10'], 'MANUAL');
    expect(restored.containsKey('17'), isFalse);
  });

  test('an explicitly supplied barcode expiry is preserved', () {
    final utils = DigitScannerUtils();
    final barcode = GS1BarcodeParser.defaultParser().parse(
      utils.generateGS1Barcode(
        batchNumber: 'BATCH123',
        gtin: '00000000000000',
        serialNumber: 'serial123',
        expiryDate: DateTime(2027, 10, 23),
      ),
    );
    final restored = DigitScannerUtils.deserializeGs1Barcodes(
        utils.serializeGs1Barcodes([barcode])).single;
    expect(restored['17'], '23 Oct 2027');
    expect(restored['21'], 'serial123');
  });
}
