import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart';

/// Covers the two pure date-grouping helpers the Summary Report's new
/// "Tokens Used" and "Tokens Redeemed" columns are built on
/// (pages/reports/summary/summary_report.dart). _SummaryReportPageState
/// itself has the same heavy repository/BuildContext dependency problem
/// ResourceCard and StockBalanceCard had, so the arithmetic is tested here
/// in isolation rather than through a full widget harness.
int epoch(String isoDate) =>
    DateTime.parse('${isoDate}T00:00:00Z').millisecondsSinceEpoch;

String toDateOnly(int epochMs) =>
    DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true)
        .toIso8601String()
        .substring(0, 10);

void main() {
  group('countByDate (Tokens Used)', () {
    test('counts one token per date it was assigned on', () {
      final result = countByDate(
        [epoch('2026-09-01'), epoch('2026-09-01'), epoch('2026-09-02')],
        toDateOnly,
      );

      expect(result, {'2026-09-01': 2, '2026-09-02': 1});
    });

    test('returns an empty map for no assigned tokens', () {
      expect(countByDate(const [], toDateOnly), isEmpty);
    });

    test('two tokens assigned at different times the same day count as one date', () {
      final morning = DateTime.parse('2026-09-01T08:00:00Z').millisecondsSinceEpoch;
      final evening = DateTime.parse('2026-09-01T20:00:00Z').millisecondsSinceEpoch;

      final result = countByDate([morning, evening], toDateOnly);

      expect(result, {'2026-09-01': 2});
    });
  });

  group('groupDistinctKeysByDate (Tokens Redeemed)', () {
    test('counts each distinct beneficiary once per date, regardless of unit count', () {
      final result = groupDistinctKeysByDate(
        [
          MapEntry('beneficiary-a', epoch('2026-09-01')),
          MapEntry('beneficiary-b', epoch('2026-09-01')),
        ],
        toDateOnly,
      );

      expect(result['2026-09-01'], {'beneficiary-a', 'beneficiary-b'});
    });

    test('the same beneficiary delivered to twice in one day is still one token redeemed', () {
      final result = groupDistinctKeysByDate(
        [
          MapEntry('beneficiary-a', epoch('2026-09-01')),
          MapEntry('beneficiary-a', epoch('2026-09-01')),
        ],
        toDateOnly,
      );

      expect(result['2026-09-01']!.length, 1);
    });

    test('the same beneficiary delivered to on two different days counts once per day', () {
      final result = groupDistinctKeysByDate(
        [
          MapEntry('beneficiary-a', epoch('2026-09-01')),
          MapEntry('beneficiary-a', epoch('2026-09-02')),
        ],
        toDateOnly,
      );

      expect(result['2026-09-01']!.length, 1);
      expect(result['2026-09-02']!.length, 1);
    });

    test('returns an empty map for no deliveries', () {
      expect(groupDistinctKeysByDate(const [], toDateOnly), isEmpty);
    });
  });
}
