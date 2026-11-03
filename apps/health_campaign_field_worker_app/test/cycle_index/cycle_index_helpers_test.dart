import 'package:digit_data_model/models/entities/project_type.dart';
import 'package:digit_flow_builder/utils/cycle_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cycleIndexStampAt', () {
    // Cycle 1 runs 100-200, a gap follows, cycle 2 runs 300-400.
    final cycles = [
      ProjectCycle(id: 1, startDate: 100, endDate: 200),
      ProjectCycle(id: 2, startDate: 300, endDate: 400),
    ];

    test('is the running cycle while a cycle runs', () {
      expect(cycleIndexStampAt(cycles, 150), 1);
      expect(cycleIndexStampAt(cycles, 350), 2);
    });

    test('is the cycle that just ended on a day between two cycles', () {
      expect(cycleIndexStampAt(cycles, 250), 1);
      final threeCycles = [
        ...cycles,
        ProjectCycle(id: 3, startDate: 500, endDate: 600),
      ];
      expect(cycleIndexStampAt(threeCycles, 450), 2);
    });

    test('is the last cycle after the last cycle has ended', () {
      expect(cycleIndexStampAt(cycles, 450), 2);
    });

    test('is the first cycle before any cycle has started', () {
      expect(cycleIndexStampAt(cycles, 50), 1);
    });

    test('a cycle counts from the moment it starts', () {
      expect(cycleIndexStampAt(cycles, 300), 2);
      expect(cycleIndexStampAt(cycles, 299), 1);
    });

    test('goes by start date, not by the order the cycles are listed in', () {
      final unordered = [
        ProjectCycle(id: 3, startDate: 500, endDate: 600),
        ProjectCycle(id: 1, startDate: 100, endDate: 200),
        ProjectCycle(id: 2, startDate: 300, endDate: 400),
      ];
      expect(cycleIndexStampAt(unordered, 50), 1);
      expect(cycleIndexStampAt(unordered, 250), 1);
      expect(cycleIndexStampAt(unordered, 450), 2);
      expect(cycleIndexStampAt(unordered, 700), 3);
    });

    test('is null when there are no cycles', () {
      expect(cycleIndexStampAt(null, 150), isNull);
      expect(cycleIndexStampAt(const [], 150), isNull);
    });
  });
}
