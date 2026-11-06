// QA (Kebbi AZM, 2026-11-03): editing a child born 22 Nov 2025 on
// 3 Nov 2026 showed the Height field. The DOB widget shows 0y 11m, but the
// Height rule `calculateAgeInMonths(dob)>=12` counted calendar months only
// (Nov -> Nov = 12). Every other age in the app (DigitDateUtils.calculateAge,
// the flow builder's calculateAgeInMonths, the converter's __ageInMonths)
// does not count a month whose day has not come yet.
//
// Decision (Amit, 2026-11-03): count the day; nothing else may change.
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  String ddMMyyyy(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  group('ageInMonthsOn', () {
    final today = DateTime(2026, 11, 3);

    test('QA case: born 22 Nov 2025 is 11 months on 3 Nov 2026', () {
      expect(ageInMonthsOn(DateTime(2025, 11, 22), today), 11);
    });

    test('typed "11 months" (born 3 Dec 2025) is 11, as before', () {
      expect(ageInMonthsOn(DateTime(2025, 12, 3), today), 11);
    });

    test('birthday today counts the month', () {
      expect(ageInMonthsOn(DateTime(2025, 11, 3), today), 12);
    });

    test('birthday already passed this month counts the month', () {
      expect(ageInMonthsOn(DateTime(2025, 11, 1), today), 12);
    });

    test('top end: born 22 Nov 2021 is 59 months, not 60', () {
      expect(ageInMonthsOn(DateTime(2021, 11, 22), today), 59);
    });

    test('born on the 31st: a month counts once its day is passed', () {
      expect(ageInMonthsOn(DateTime(2026, 1, 31), DateTime(2026, 2, 28)), 0);
      expect(ageInMonthsOn(DateTime(2026, 1, 31), DateTime(2026, 3, 1)), 1);
    });

    test('born on 29 Feb', () {
      expect(ageInMonthsOn(DateTime(2024, 2, 29), DateTime(2025, 2, 28)), 11);
      expect(ageInMonthsOn(DateTime(2024, 2, 29), DateTime(2025, 3, 1)), 12);
    });

    test('a birth date in the future never counts as a month of age', () {
      expect(ageInMonthsOn(DateTime(2026, 11, 10), today), lessThanOrEqualTo(0));
    });

    test('changes the old count only when the day has not come yet, by one',
        () {
      var changed = 0;
      var total = 0;
      for (var dob = DateTime(2020, 1, 1);
          !dob.isAfter(today);
          dob = DateTime(dob.year, dob.month, dob.day + 1)) {
        total++;
        final old =
            (today.year - dob.year) * 12 + today.month - dob.month;
        final now = ageInMonthsOn(dob, today);
        if (now == old) continue;
        changed++;
        expect(now, old - 1, reason: 'dob $dob');
        expect(today.day < dob.day, isTrue, reason: 'dob $dob');
      }
      // ignore: avoid_print
      print('birth dates checked: $total, changed: $changed');
    });
  });

  group('calculateAgeInMonths (forms function)', () {
    final fn = functionRegistry['calculateAgeInMonths']!;
    final now = DateTime.now();
    // A day later than today, a year ago, in this month: 11 months old.
    final dayNotReached = DateTime(now.year - 1, now.month, now.day + 1);
    final skipOnLastDay = dayNotReached.month != now.month
        ? 'needs a later day in this month'
        : null;

    test('empty or unreadable input is 0, as before', () {
      expect(fn(['']), 0);
      expect(fn(['not a date']), 0);
    });

    test('dd/MM/yyyy and yyyy-MM-dd give the same age', () {
      final dob = DateTime(now.year - 2, now.month, 1);
      expect(fn([ddMMyyyy(dob)]), fn([DateFormat('yyyy-MM-dd').format(dob)]));
      expect(fn([ddMMyyyy(dob)]), ageInMonthsOn(dob, now));
    });

    test('a birthday later this month is not counted yet', () {
      expect(fn([ddMMyyyy(dayNotReached)]), 11);
    }, skip: skipOnLastDay);
  });

  group('Height rule (12-59 months)', () {
    const rule = [
      VisibilityExpression(
        condition:
            'calculateAgeInMonths(beneficiaryDetails.dobPicker)>=12 && calculateAgeInMonths(beneficiaryDetails.dobPicker)<=59',
      ),
    ];
    final now = DateTime.now();
    final laterThisMonth = DateTime(now.year, now.month, now.day + 1);
    final skipOnLastDay = laterThisMonth.month != now.month
        ? 'needs a later day in this month'
        : null;

    bool heightShown(DateTime dob) => evaluateVisibilityExpression(
        rule, {'beneficiaryDetails.dobPicker': ddMMyyyy(dob)});

    test('11 months (birthday later this month): hidden', () {
      expect(heightShown(DateTime(now.year - 1, now.month, now.day + 1)),
          isFalse);
    }, skip: skipOnLastDay);

    test('exactly 12 months: shown', () {
      expect(heightShown(DateTime(now.year - 1, now.month, now.day)), isTrue);
    });

    test('59 months (birthday later this month): shown', () {
      expect(heightShown(DateTime(now.year - 5, now.month, now.day + 1)),
          isTrue);
    }, skip: skipOnLastDay);

    test('exactly 60 months: hidden', () {
      expect(heightShown(DateTime(now.year - 5, now.month, now.day)), isFalse);
    });

    test('6 months: hidden', () {
      expect(heightShown(DateTime(now.year, now.month - 6, 1)), isFalse);
    });
  });
}
