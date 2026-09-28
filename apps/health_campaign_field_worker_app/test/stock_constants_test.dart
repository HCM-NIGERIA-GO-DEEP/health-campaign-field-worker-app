import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/stock_constants.dart';

void main() {
  group('stock unit constants', () {
    test('everything derives from the one isLiquid flag', () {
      expect(
        StockConstants.multiplier,
        StockConstants.isLiquid ? StockConstants.mlPerBottle : 1.0,
      );
      expect(StockConstants.deductPartialUsed, StockConstants.isLiquid);
    });

    test('a whole-unit campaign never scales', () {
      if (StockConstants.isLiquid) return;
      expect(StockConstants.multiplier, 1.0);
      expect(StockConstants.toDisplayUnit(7), 7);
      expect(StockConstants.toBaseUnit(7), 7);
    });

    test('a liquid campaign converts both ways', () {
      if (!StockConstants.isLiquid) return;
      final m = StockConstants.mlPerBottle;
      expect(StockConstants.toDisplayUnit(4), 4 * m);
      expect(StockConstants.toBaseUnit(4 * m), 4);
    });

    test('conversion round-trips', () {
      for (final v in [0, 1, 4, 33, 1000]) {
        expect(
          StockConstants.toBaseUnit(StockConstants.toDisplayUnit(v)),
          closeTo(v.toDouble(), 1e-9),
        );
      }
    });

    test('the multiplier is usable as a divisor', () {
      expect(StockConstants.multiplier, greaterThan(0));
    });
  });
}
