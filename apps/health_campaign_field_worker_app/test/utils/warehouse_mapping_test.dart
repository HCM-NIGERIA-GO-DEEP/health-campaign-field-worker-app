import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/models/app_config/app_config_model.dart';
import 'package:health_campaign_field_worker_app/utils/warehouse_mapping.dart';

void main() {
  const mapping = {
    'REG-A': ['DIST-1', 'DIST-2'],
    'REG-B': ['DIST-3'],
  };

  group('mappedFacilityIds', () {
    test('a regional warehouse issues to its own districts only', () {
      expect(
        mappedFacilityIds(
          mapping: mapping,
          currentFacilityIds: ['REG-A'],
          side: WarehouseMappingSide.children,
        ),
        ['DIST-1', 'DIST-2'],
      );
    });

    test('a district answers to the regional warehouse that lists it', () {
      expect(
        mappedFacilityIds(
          mapping: mapping,
          currentFacilityIds: ['DIST-3'],
          side: WarehouseMappingSide.parent,
        ),
        ['REG-B'],
      );
    });

    test('a warehouse the master does not name keeps its own list', () {
      for (final side in WarehouseMappingSide.values) {
        expect(
          mappedFacilityIds(
            mapping: mapping,
            currentFacilityIds: ['COUNTY-1'],
            side: side,
          ),
          isNull,
        );
        expect(
          mappedFacilityIds(
            mapping: const {},
            currentFacilityIds: ['REG-A'],
            side: side,
          ),
          isNull,
        );
      }
    });

    test('the two sides do not leak into each other', () {
      // A district has no children entry, a region has no parent entry.
      expect(
        mappedFacilityIds(
          mapping: mapping,
          currentFacilityIds: ['DIST-1'],
          side: WarehouseMappingSide.children,
        ),
        isNull,
      );
      expect(
        mappedFacilityIds(
          mapping: mapping,
          currentFacilityIds: ['REG-A'],
          side: WarehouseMappingSide.parent,
        ),
        isNull,
      );
    });

    test('an empty or blank children list counts as no entry', () {
      expect(
        mappedFacilityIds(
          mapping: const {
            'REG-A': <String>[],
            'REG-B': [' ', ''],
          },
          currentFacilityIds: ['REG-A', 'REG-B'],
          side: WarehouseMappingSide.children,
        ),
        isNull,
      );
    });

    test('a district listed under two regions is offered both, once each', () {
      expect(
        mappedFacilityIds(
          mapping: const {
            'REG-A': ['DIST-1', 'DIST-1'],
            'REG-B': ['DIST-1'],
          },
          currentFacilityIds: ['DIST-1'],
          side: WarehouseMappingSide.parent,
        ),
        ['REG-A', 'REG-B'],
      );
    });
  });

  group('warehouseMappingSide', () {
    WarehouseMappingSide? side({
      bool to = false,
      bool from = false,
      bool returnOrLessExcess = false,
      String type = '',
      String upward = 'parent',
    }) =>
        warehouseMappingSide(
          isToField: to,
          isFromField: from,
          isReturnOrLessExcessFlow: returnOrLessExcess,
          transactionType: type,
          upwardLevel: upward,
        );

    test('issue: Deliver to shows children, the source field is untouched',
        () {
      for (final type in ['DISPATCHED', 'ISSUED']) {
        expect(side(to: true, type: type), WarehouseMappingSide.children);
        expect(side(from: true, type: type), isNull);
      }
    });

    test('receipt: Receive from shows the parent, Deliver to is untouched', () {
      for (final type in ['RECEIVED', 'RECEIPT']) {
        expect(side(from: true, type: type), WarehouseMappingSide.parent);
        expect(side(to: true, type: type), isNull);
      }
    });

    test('return and loss/excess go to the parent whatever the type', () {
      for (final type in ['DISPATCHED', 'RECEIVED', '']) {
        expect(
          side(to: true, returnOrLessExcess: true, type: type),
          WarehouseMappingSide.parent,
        );
        expect(
          side(from: true, returnOrLessExcess: true, type: type),
          isNull,
        );
      }
    });

    test('a distributor without the warehouse role is never mapped upward',
        () {
      expect(side(from: true, type: 'RECEIVED', upward: 'current'), isNull);
      expect(
        side(to: true, returnOrLessExcess: true, upward: 'current'),
        isNull,
      );
    });

    test('an unknown transaction type is untouched', () {
      expect(side(to: true, type: 'OTHER'), isNull);
      expect(side(from: true), isNull);
    });
  });

  group('WAREHOUSE_MAPPING master parsing', () {
    test('reads the shared example entry', () {
      final entry = WarehouseMapping.fromJson(const {
        'facilityId': 'REG-A',
        'children': ['DIST-1', 'DIST-2'],
      });
      expect(entry.facilityId, 'REG-A');
      expect(entry.children, ['DIST-1', 'DIST-2']);
    });

    test('an entry with missing fields parses instead of failing start-up',
        () {
      final entry = WarehouseMapping.fromJson(const {});
      expect(entry.facilityId, isNull);
      expect(entry.children, isNull);
    });
  });
}
