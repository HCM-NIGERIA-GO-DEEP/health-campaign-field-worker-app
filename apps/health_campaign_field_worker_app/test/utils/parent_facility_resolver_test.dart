import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';
import 'package:health_campaign_field_worker_app/utils/parent_facility_resolver.dart';

/// Guards the usage-based parent facility resolution for a top-of-hierarchy
/// user. Country is the root of the LIBERIA boundary hierarchy, so the
/// ProjectFacility search can never return a 'parent' for the national
/// warehouse and the four upward-facing stock operations had no source.
void main() {
  group('parentFacilityUsages against the real INVENTORY config', () {
    test('Country resolves to the IDA Foundation usage', () {
      expect(
        parentFacilityUsages(
          inventoryConfig: sampleInventoryFlows,
          boundaryType: 'Country',
        ),
        ['IDA Foundation'],
      );
    });

    test('levels with a real boundary above them name a boundary type, '
        'which matches no facility usage', () {
      // District.forReceipt is "Country" - a boundary type. No facility
      // carries that as its usage, so nothing resolves and the district
      // flow is untouched.
      const realUsages = {
        'District Facility',
        'Central Facility',
        'Distribution Hub',
        'Warehouse',
        'IDA Foundation',
      };
      for (final level in ['District', 'Health Facility', 'Distribution Point']) {
        final resolved = parentFacilityUsages(
          inventoryConfig: sampleInventoryFlows,
          boundaryType: level,
        );
        expect(
          resolved.where(realUsages.contains),
          isEmpty,
          reason: '$level must not resolve a usage-based parent',
        );
      }
    });

    test('County was removed from the supply chain', () {
      expect(
        parentFacilityUsages(
          inventoryConfig: sampleInventoryFlows,
          boundaryType: 'County',
        ),
        isEmpty,
      );
    });

    test('unknown level and malformed config resolve to nothing, never throw', () {
      expect(
        parentFacilityUsages(
          inventoryConfig: sampleInventoryFlows,
          boundaryType: 'Nonexistent',
        ),
        isEmpty,
      );
      expect(parentFacilityUsages(inventoryConfig: null, boundaryType: 'Country'),
          isEmpty);
      expect(
          parentFacilityUsages(
              inventoryConfig: {'flows': 'not-a-list'}, boundaryType: 'Country'),
          isEmpty);
      expect(
          parentFacilityUsages(
              inventoryConfig: sampleInventoryFlows, boundaryType: null),
          isEmpty);
    });
  });

  group('isTopLevelAssignment', () {
    test('national user on the root boundary is top level', () {
      // What project.dart actually derives for the national warehouse:
      // Country is boundaryNum 1 so no parent is found, County is its child.
      expect(
        isTopLevelAssignment(
          assignedBoundaryType: 'Country',
          boundaryTypes: const ['Country', 'County'],
        ),
        isTrue,
      );
    });

    test('a user with a real parent level is not top level', () {
      expect(
        isTopLevelAssignment(
          assignedBoundaryType: 'District',
          boundaryTypes: const ['County', 'District', 'Health Facility'],
        ),
        isFalse,
      );
    });

    test('single-entry and empty boundaryTypes are top level', () {
      expect(
        isTopLevelAssignment(
          assignedBoundaryType: 'Country',
          boundaryTypes: const ['Country'],
        ),
        isTrue,
      );
      expect(
        isTopLevelAssignment(
            assignedBoundaryType: 'Country', boundaryTypes: const []),
        isTrue,
      );
      expect(
        isTopLevelAssignment(
            assignedBoundaryType: 'Country', boundaryTypes: null),
        isTrue,
      );
    });

    test('a missing assigned boundary type is never top level', () {
      expect(
        isTopLevelAssignment(assignedBoundaryType: null, boundaryTypes: null),
        isFalse,
      );
      expect(
        isTopLevelAssignment(assignedBoundaryType: '', boundaryTypes: null),
        isFalse,
      );
    });
  });

  test('only IDA Foundation matches, against the real facility master', () {
    // usage values exactly as returned by the Facilities search on the
    // liberia env (see assets/stock-file.txt).
    const master = {
      'F-2026-11-20-000001': 'District Facility',
      'F-2026-11-20-000002': 'Central Facility', // the national warehouse
      'F-2026-11-20-000003': 'Distribution Hub',
      'F-2026-11-22-000009': 'Warehouse',
      'F-2026-11-24-000010': 'IDA Foundation',
    };

    final usages = parentFacilityUsages(
      inventoryConfig: sampleInventoryFlows,
      boundaryType: 'Country',
    );
    final matched = master.entries
        .where((e) => usages.contains(e.value))
        .map((e) => e.key)
        .toList();

    expect(matched, ['F-2026-11-24-000010']);
    // The national warehouse must never resolve as its own parent - that was
    // the bug in the old "Central Facility" value.
    expect(matched, isNot(contains('F-2026-11-20-000002')));
  });
}
