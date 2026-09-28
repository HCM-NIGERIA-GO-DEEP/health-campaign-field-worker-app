import 'package:digit_forms_engine/utils/forms_function_config.dart';
import 'package:digit_forms_engine/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const productId = 'pv-1';

  setUp(() {
    FormsFunctionConfig.instance
      ..stockBalanceResolver = null
      ..unitMultiplierResolver = null;
  });

  tearDown(() {
    FormsFunctionConfig.instance
      ..stockBalanceResolver = null
      ..unitMultiplierResolver = null;
  });

  void withBalance(num balance, {double? multiplier}) {
    FormsFunctionConfig.instance
      ..stockBalanceResolver = ((id) => id == productId ? balance : 0)
      ..unitMultiplierResolver =
          multiplier == null ? null : (() => multiplier);
  }

  group('unitMultiplier', () {
    test('defaults to 1 when no resolver is registered', () {
      expect(FormsFunctionConfig.instance.unitMultiplier, 1.0);
    });

    test('falls back to 1 for a non-positive multiplier', () {
      FormsFunctionConfig.instance.unitMultiplierResolver = () => 0;
      expect(FormsFunctionConfig.instance.unitMultiplier, 1.0);
    });
  });

  group('calculateWastage', () {
    final wastage = functionRegistry['calculateWastage']!;

    test('returns 0 when nothing was returned', () {
      withBalance(300, multiplier: 30);
      expect(wastage([0, 5, productId]), 0);
    });

    test('accounts a whole-bottle return with no leftover', () {
      // 300 ml in hand, 10 full bottles back, no partial -> nothing wasted.
      withBalance(300, multiplier: 30);
      expect(wastage([10, 0, productId]), 0);
    });

    test('treats the part-used bottle as holding the remainder', () {
      // 305 ml in hand: 10 full bottles (300 ml) + 5 ml in the open bottle.
      withBalance(305, multiplier: 30);
      expect(wastage([10, 1, productId]), 0);
    });

    test('reports the shortfall as wastage', () {
      // 300 ml in hand but only 8 bottles (240 ml) came back.
      withBalance(300, multiplier: 30);
      expect(wastage([8, 0, productId]), 60);
    });

    test('never goes negative', () {
      withBalance(60, multiplier: 30);
      expect(wastage([5, 0, productId]), 0);
    });

    test('honours a multiplier other than 30', () {
      // 10 ml per bottle: 100 in hand, 7 bottles back -> 30 wasted.
      withBalance(100, multiplier: 10);
      expect(wastage([7, 0, productId]), 30);
    });

    test('degrades to a plain count when no multiplier is configured', () {
      withBalance(10);
      expect(wastage([4, 0, productId]), 6);
    });

    test('returns 0 when the product has no resolvable balance', () {
      withBalance(300, multiplier: 30);
      expect(wastage([2, 0, 'unknown-product']), 0);
    });
  });

  group('calculatePartial', () {
    final partial = functionRegistry['calculatePartial']!;

    test('derives the leftover from the balance remainder', () {
      withBalance(305, multiplier: 30);
      expect(partial([10, 1, productId]), 5);
    });

    test('is 0 when the worker reported no partial bottle', () {
      withBalance(305, multiplier: 30);
      expect(partial([10, 0, productId]), 0);
    });

    test('is 0 when nothing was returned', () {
      withBalance(305, multiplier: 30);
      expect(partial([0, 1, productId]), 0);
    });
  });
}
