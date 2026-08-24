// Kit test — cross-branch coverage for the downsync cursor-poisoning bug
// (fixed 2026-07-27). A cursor advanced from the device clock after an empty
// server page permanently hid national→state stock dispatches; the cursor
// must advance only from downloaded records' server lastModifiedTime.
//
// Scenario source: scenarios/stock/downsync-cursor.md

import 'package:digit_data_model/data_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/stock_downsync_cursor.dart';

StockModel _stock(String id, {int? createdTime, int? lastModifiedTime}) =>
    StockModel(
      clientReferenceId: id,
      auditDetails: createdTime == null
          ? null
          : AuditDetails(
              createdBy: 'server-user',
              createdTime: createdTime,
              lastModifiedTime: lastModifiedTime,
            ),
    );

void main() {
  group('StockDownsyncCursor.key', () {
    test('is scoped by project, user and cycle', () {
      expect(
        StockDownsyncCursor.key('P-1', 'uuid-a', 2),
        'stockDownsyncTime_P-1_uuid-a_2',
      );
      // Two users on a shared device must never collide.
      expect(
        StockDownsyncCursor.key('P-1', 'uuid-a', 2),
        isNot(StockDownsyncCursor.key('P-1', 'uuid-b', 2)),
      );
      // Cycle boundary resets the window.
      expect(
        StockDownsyncCursor.key('P-1', 'uuid-a', 1),
        isNot(StockDownsyncCursor.key('P-1', 'uuid-a', 2)),
      );
    });
  });

  group('StockDownsyncCursor.resolveCutoff', () {
    test('stored cursor wins over cycle start', () {
      expect(
        StockDownsyncCursor.resolveCutoff(
          storedTime: 2000,
          cycleStartDate: 1000,
        ),
        2000,
      );
    });

    test('falls back to cycle start when no cursor is stored (fresh install)',
        () {
      expect(
        StockDownsyncCursor.resolveCutoff(
          storedTime: null,
          cycleStartDate: 1000,
        ),
        1000,
      );
    });

    test('null when neither exists (no campaign cycles configured)', () {
      expect(
        StockDownsyncCursor.resolveCutoff(
          storedTime: null,
          cycleStartDate: null,
        ),
        isNull,
      );
    });
  });

  group('StockDownsyncCursor.nextCursor', () {
    test('returns null on an empty page so the caller keeps the old cursor',
        () {
      expect(
        StockDownsyncCursor.nextCursor(stored: 1000, stocks: const []),
        isNull,
      );
    });

    test('returns null when no record carries a server audit time', () {
      expect(
        StockDownsyncCursor.nextCursor(
          stored: 1000,
          stocks: [_stock('s1'), _stock('s2')],
        ),
        isNull,
      );
    });

    test('advances to the max server lastModifiedTime of the page', () {
      expect(
        StockDownsyncCursor.nextCursor(
          stored: 1000,
          stocks: [
            _stock('s1', createdTime: 500, lastModifiedTime: 1500),
            _stock('s2', createdTime: 500, lastModifiedTime: 3000),
            _stock('s3', createdTime: 500, lastModifiedTime: 2000),
          ],
        ),
        3000,
      );
    });

    test('never moves backward past the stored cursor', () {
      expect(
        StockDownsyncCursor.nextCursor(
          stored: 5000,
          stocks: [_stock('s1', createdTime: 100, lastModifiedTime: 4000)],
        ),
        5000,
      );
    });

    test('records without audit details are ignored, not treated as zero', () {
      expect(
        StockDownsyncCursor.nextCursor(
          stored: null,
          stocks: [
            _stock('s1'),
            _stock('s2', createdTime: 100, lastModifiedTime: 2500),
          ],
        ),
        2500,
      );
    });
  });
}
