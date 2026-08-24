// Kit test — DateConversions branchy paths (format branching, garbage
// inputs, null paths). Assertions are timezone-robust (round-trips and
// local-to-local formatting only) so the kit passes on any dev machine.
//
// getYearsAndMonthsFromDateTime and any DateTime.now()-dependent behavior
// are deliberately NOT tested here (kit rule: no wall-clock dependence).
//
// Scenario source: scenarios/dates/date-conversions.md

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/date_conversions.dart';

void main() {
  group('getFilteredDate', () {
    test('formats a local ISO datetime with the default pattern', () {
      expect(DateConversions.getFilteredDate('2025-06-15T10:30:00'),
          '15/06/2025');
    });

    test('honours a custom pattern', () {
      expect(
        DateConversions.getFilteredDate(
          '2025-06-15T10:30:00',
          dateFormat: 'yyyy-MM-dd',
        ),
        '2025-06-15',
      );
    });

    test('empty and whitespace input return empty string', () {
      expect(DateConversions.getFilteredDate(''), '');
      expect(DateConversions.getFilteredDate('   '), '');
    });

    test('unparseable input returns null, never throws', () {
      expect(DateConversions.getFilteredDate('not-a-date'), isNull);
    });
  });

  group('getFormattedDateToDateTime', () {
    test('parses the dash format', () {
      expect(
        DateConversions.getFormattedDateToDateTime('31-01-2025'),
        DateTime(2025, 1, 31),
      );
    });

    test('parses the slash format', () {
      expect(
        DateConversions.getFormattedDateToDateTime('31/01/2025'),
        DateTime(2025, 1, 31),
      );
    });

    test('garbage returns null, never throws', () {
      expect(DateConversions.getFormattedDateToDateTime('garbage'), isNull);
    });
  });

  group('timestamp round trips', () {
    test('dateToTimeStamp is the inverse of getDateFromTimestamp', () {
      final ts = DateConversions.dateToTimeStamp('15/06/2025');
      expect(ts, isNonZero);
      expect(DateConversions.getDateFromTimestamp(ts), '15/06/2025');
    });

    test('dateToTimeStamp returns 0 on garbage, never throws', () {
      expect(DateConversions.dateToTimeStamp('garbage'), 0);
    });

    test('getDateFromTimestamp formats a local timestamp', () {
      final ts = DateTime(2025, 6, 15, 12).millisecondsSinceEpoch;
      expect(DateConversions.getDateFromTimestamp(ts), '15/06/2025');
      expect(
        DateConversions.getDateFromTimestamp(ts, dateFormat: 'dd MMM yyyy'),
        '15 Jun 2025',
      );
    });
  });

  group('timeStampToDate', () {
    test('null returns empty string', () {
      expect(DateConversions.timeStampToDate(null), '');
    });

    test('formats a local timestamp with default and custom patterns', () {
      final ts = DateTime(2025, 6, 15, 12).millisecondsSinceEpoch;
      expect(DateConversions.timeStampToDate(ts), '15/06/2025');
      expect(
        DateConversions.timeStampToDate(ts, format: 'yyyy'),
        '2025',
      );
    });
  });

  group('month and day labels', () {
    test('getMonth returns the month abbreviation', () {
      expect(DateConversions.getMonth(DateTime(2025, 3, 1)), 'Mar');
    });

    test('getDay returns the weekday abbreviation', () {
      // 2025-06-15 is a Sunday in every timezone at noon local.
      final ts = DateTime(2025, 6, 15, 12).millisecondsSinceEpoch;
      expect(DateConversions.getDay(ts), 'Sun');
    });
  });
}
