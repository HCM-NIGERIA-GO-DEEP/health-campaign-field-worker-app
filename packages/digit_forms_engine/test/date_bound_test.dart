import 'package:digit_forms_engine/helper/date_bound_resolver.dart';
import 'package:digit_forms_engine/helper/validator_helper.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

void main() {
  group('resolveDateBoundMillis', () {
    DateTime clock() => DateTime(2026, 10, 5, 14, 30);

    test('passes integer epochs through unchanged', () {
      expect(
        resolveDateBoundMillis(1700000000000, endOfDay: true, now: clock),
        1700000000000,
      );
    });

    test('resolves today to the first millisecond of the day for a start bound',
        () {
      expect(
        resolveDateBoundMillis('today', endOfDay: false, now: clock),
        DateTime(2026, 10, 5).millisecondsSinceEpoch,
      );
    });

    test('resolves today to the last millisecond of the day for an end bound',
        () {
      expect(
        resolveDateBoundMillis('today', endOfDay: true, now: clock),
        DateTime(2026, 10, 6).millisecondsSinceEpoch - 1,
      );
    });

    test('ignores case and surrounding whitespace in the keyword', () {
      expect(
        resolveDateBoundMillis(' Today ', endOfDay: false, now: clock),
        DateTime(2026, 10, 5).millisecondsSinceEpoch,
      );
    });

    test('returns null for missing or unrecognised values', () {
      expect(resolveDateBoundMillis(null, endOfDay: true), isNull);
      expect(resolveDateBoundMillis('yesterday', endOfDay: true), isNull);
      expect(resolveDateBoundMillis(12.5, endOfDay: true), isNull);
    });
  });

  group('startDate / endDate "today" validators', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    FormControl<DateTime> dateControl(String ruleType) => FormControl<DateTime>(
          validators: buildValidators(PropertySchema(
            type: PropertySchemaType.string,
            format: PropertySchemaFormat.date,
            validations: [
              ValidationRule(type: ruleType, value: 'today', message: 'Bad'),
            ],
          )),
        );

    // Mirrors the eligibility checklist "last date received" fields.
    test('endDate today accepts today and past dates', () {
      final control = dateControl('endDate');

      control.value = today;
      expect(control.valid, isTrue);

      control.value = today.subtract(const Duration(days: 400));
      expect(control.valid, isTrue);
    });

    test('endDate today rejects a future date', () {
      final control = dateControl('endDate');

      control.value = today.add(const Duration(days: 1));
      expect(control.hasError('endDate'), isTrue);
    });

    test('startDate today rejects a past date', () {
      final control = dateControl('startDate');

      control.value = today.subtract(const Duration(days: 1));
      expect(control.hasError('startDate'), isTrue);

      control.value = today;
      expect(control.valid, isTrue);
    });

    test('leaves an empty value to the required rule', () {
      final control = dateControl('endDate');

      control.value = null;
      expect(control.valid, isTrue);
    });
  });
}
