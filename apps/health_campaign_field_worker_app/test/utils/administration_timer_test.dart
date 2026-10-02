import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/administration_timer.dart';

void main() {
  // The device wall clock, moved by hand. The stopwatch is real, so while a
  // test runs it measures only a few milliseconds - exactly what it would
  // see if the wall clock were changed rather than time actually passing.
  late DateTime wallClock;
  late AdministrationTimer timer;

  setUp(() {
    wallClock = DateTime(2026, 10, 2, 9);
    timer = AdministrationTimer(now: () => wallClock);
  });

  test('start and end are device-local epoch millis', () {
    final start = timer.start();
    wallClock = wallClock.add(const Duration(seconds: 20));

    expect(start, DateTime(2026, 10, 2, 9).millisecondsSinceEpoch);
    expect(timer.end(), start + 20000);
  });

  test('re-entering the delivery screen restarts the clock', () {
    timer.start();
    wallClock = wallClock.add(const Duration(minutes: 5));
    final secondStart = timer.start();

    expect(secondStart, wallClock.millisecondsSinceEpoch);
    expect(timer.flag(secondStart), isNull);
  });

  test('a clock moved backwards is flagged as a negative duration', () {
    final start = timer.start();
    wallClock = wallClock.subtract(const Duration(hours: 1));

    expect(timer.flag(start), AdministrationTimer.negativeDurationFlag);
  });

  test('a clock moved forwards is flagged as changed', () {
    final start = timer.start();
    wallClock = wallClock.add(const Duration(minutes: 10));

    expect(timer.flag(start), AdministrationTimer.clockChangedFlag);
  });

  test('a small gap within the tolerance is not flagged', () {
    final start = timer.start();
    wallClock = wallClock.add(const Duration(seconds: 30));

    expect(timer.flag(start), isNull);
  });

  test('without a matching stopwatch only a negative duration is caught', () {
    timer.start();
    final otherStart =
        wallClock.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;

    expect(timer.flag(otherStart), isNull);
    expect(
      timer.flag(wallClock.add(const Duration(minutes: 1)).millisecondsSinceEpoch),
      AdministrationTimer.negativeDurationFlag,
    );
  });

  group('flagFor', () {
    test('trusts a duration that matches the stopwatch', () {
      expect(
        AdministrationTimer.flagFor(
            startTime: 0, endTime: 90000, elapsedMillis: 89000),
        isNull,
      );
    });

    test('flags a duration the stopwatch disagrees with', () {
      expect(
        AdministrationTimer.flagFor(
            startTime: 0, endTime: 3600000, elapsedMillis: 90000),
        AdministrationTimer.clockChangedFlag,
      );
    });
  });
}
