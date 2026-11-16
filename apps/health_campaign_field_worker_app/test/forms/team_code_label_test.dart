import 'package:digit_forms_engine/utils/team_code_label.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sierra Leone QA: after scanning a delivery team's QR on Warehouse Details,
/// the Team Code field read "si-dis-01 : f6088ef4-92f3-4286-8d16-40b0df3327ca".
/// The field should show the team member's username only. The saved value
/// stays "userName||uuid" - this is display text, nothing else.
void main() {
  const uuid = 'f6088ef4-92f3-4286-8d16-40b0df3327ca';
  const uuid2 = '0b1c2d3e-4f50-4617-8293-a4b5c6d7e8f9';

  group('teamCodeLabel', () {
    test('a team QR shows only the username', () {
      expect(teamCodeLabel('si-dis-01||$uuid'), 'si-dis-01');
    });

    test('spaces around either half are trimmed', () {
      expect(teamCodeLabel('  si-dis-01 || $uuid  '), 'si-dis-01');
    });

    test('a QR with no username falls back to the uuid', () {
      expect(teamCodeLabel('||$uuid'), uuid);
    });

    test('an old uuid-only QR is shown as it is', () {
      expect(teamCodeLabel(uuid), uuid);
    });

    test('a "||" value whose second half is not a uuid is shown as it is', () {
      expect(teamCodeLabel('VOUCHER||1234'), 'VOUCHER||1234');
      expect(teamCodeLabel('si-dis-01||'), 'si-dis-01||');
    });

    test('plain codes are shown as they are', () {
      expect(teamCodeLabel('ABC-123'), 'ABC-123');
      expect(teamCodeLabel(''), '');
    });
  });

  group('formatScannedCodes', () {
    test('one team QR shows the username', () {
      expect(formatScannedCodes(['si-dis-01||$uuid']), 'si-dis-01');
    });

    test('several codes are labelled one by one and joined with ", "', () {
      expect(
        formatScannedCodes(['si-dis-01||$uuid', 'si-dis-02||$uuid2', 'X1']),
        'si-dis-01, si-dis-02, X1',
      );
    });

    test('no codes gives empty text', () {
      expect(formatScannedCodes(const []), '');
    });

    test('non-string entries are labelled from their text', () {
      expect(formatScannedCodes([42]), '42');
    });
  });
}
