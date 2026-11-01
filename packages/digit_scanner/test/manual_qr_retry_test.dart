import 'package:digit_scanner/blocs/scanner.dart';
import 'package:digit_scanner/utils/scanner_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pattern = r'^[A-Z0-9]{8}$';
  test('rejected manual code leaves slot available for corrected entry', () {
    final codes = <String>[];
    void submit(String value) {
      if (!DigitScannerUtils.acceptsManualQrCode(value, pattern)) return;
      if (codes.isEmpty) codes.add(value.trim());
    }
    submit('wrong');
    expect(codes, isEmpty);
    submit('ABCD1234');
    expect(codes, ['ABCD1234']);
  });
  test('empty codes fail and optional patterns allow nonempty codes', () {
    expect(DigitScannerUtils.acceptsManualQrCode('  ', null), false);
    expect(DigitScannerUtils.acceptsManualQrCode('ABC', null), true);
    expect(DigitScannerUtils.acceptsManualQrCode('ABCD1234', ''), true);
    expect(DigitScannerUtils.acceptsManualQrCode(' ABCD1234 ', pattern), true);
  });
  test('error recovery preserves accepted scans and permits corrected code', () async {
    final bloc = DigitScannerBloc(const DigitScannerState(qrCodes: ['ABCD1234']));
    addTearDown(bloc.close);
    final rejected = bloc.stream.firstWhere((state) => state.error != null);
    bloc.add(const DigitScannerEvent.handleScanner(
      qrCode: ['ABCD1234', 'wrong'], regex: pattern,
    ));
    final errorState = await rejected;
    expect(errorState.qrCodes, ['ABCD1234']);
    final recovered = bloc.stream.firstWhere((state) => state.error == null);
    bloc.add(DigitScannerEvent.handleScanner(qrCode: errorState.qrCodes));
    expect((await recovered).qrCodes, ['ABCD1234']);
    final corrected = bloc.stream.firstWhere((state) => state.qrCodes.length == 2);
    bloc.add(const DigitScannerEvent.handleScanner(
      qrCode: ['ABCD1234', 'EFGH5678'], regex: pattern,
    ));
    expect((await corrected).qrCodes, ['ABCD1234', 'EFGH5678']);
    expect(bloc.state.error, isNull);
  });
}
