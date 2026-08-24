// Kit test — AttendanceDateTimeManagement session-window logic. The
// entry/exit epochs gate attendance capture windows; a wrong branch here
// stamps attendance at the wrong session time.
//
// isToday is deliberately NOT tested (kit rule: no wall-clock dependence).
//
// Scenario source: scenarios/dates/attendance-session-windows.md

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/date_util_attendance.dart';

void main() {
  final day = DateTime(2025, 6, 15);

  int at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute)
          .millisecondsSinceEpoch;

  group('getMillisecondEpoch session windows', () {
    test('morning session (0) entry is 09:00 local', () {
      expect(
        AttendanceDateTimeManagement.getMillisecondEpoch(day, 0, 'entryTime'),
        at(9),
      );
    });

    test('morning session (0) exit is 11:58 local', () {
      expect(
        AttendanceDateTimeManagement.getMillisecondEpoch(day, 0, 'exitTime'),
        at(11, 58),
      );
    });

    test('afternoon session (1) entry is 12:05 local', () {
      expect(
        AttendanceDateTimeManagement.getMillisecondEpoch(day, 1, 'entryTime'),
        at(12, 5),
      );
    });

    test('afternoon session (1) exit is 18:00 local', () {
      expect(
        AttendanceDateTimeManagement.getMillisecondEpoch(day, 1, 'exitTime'),
        at(18),
      );
    });

    test('any non-"entryTime" string falls to the exit branch', () {
      expect(
        AttendanceDateTimeManagement.getMillisecondEpoch(day, 0, 'anything'),
        at(11, 58),
      );
    });
  });

  group('date string round trip', () {
    test('getDateString formats dd MMM yyyy', () {
      expect(AttendanceDateTimeManagement.getDateString(day), '15 Jun 2025');
    });

    test('getFormattedDateToDateTime is its inverse', () {
      expect(
        AttendanceDateTimeManagement.getFormattedDateToDateTime('15 Jun 2025'),
        day,
      );
    });

    test('garbage returns null, never throws', () {
      expect(
        AttendanceDateTimeManagement.getFormattedDateToDateTime('nope'),
        isNull,
      );
    });
  });

  group('getFilteredDate / getDateFromTimestamp', () {
    test('local ISO input formats with the default pattern', () {
      expect(
        AttendanceDateTimeManagement.getFilteredDate('2025-06-15T10:00:00'),
        '15 Jun 2025',
      );
    });

    test('empty input returns empty string; garbage returns null', () {
      expect(AttendanceDateTimeManagement.getFilteredDate(''), '');
      expect(AttendanceDateTimeManagement.getFilteredDate('junk'), isNull);
    });

    test('getDateFromTimestamp formats a local timestamp', () {
      final ts = DateTime(2025, 6, 15, 12).millisecondsSinceEpoch;
      expect(
        AttendanceDateTimeManagement.getDateFromTimestamp(ts),
        '15/06/2025',
      );
    });
  });
}
