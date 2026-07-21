import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers `isORSDelivered` cycle scoping (tickets: post-SMC ORS continuation
/// and standalone ORS):
///
/// ORS-Zinc is deliverable once per cycle. An ORS delivered in cycle 1 must
/// not mark the member as "delivered" in cycle 2 — previously the function
/// returned true for a delivered ORS task from ANY cycle, so the overview
/// showed "delivered" forever and the deliver button never re-enabled.
///
/// Conservative fallbacks (original behavior preserved): a delivered ORS task
/// without a cycleIndex counts as delivered in every cycle, and when no
/// cycle window is resolvable the original any-cycle behavior applies.
///
/// The current cycle is resolved from the campaign projectType (same
/// date-window logic as the SMC eligibility checks — SMC and ORS-Zinc cycles
/// are aligned per campaign config).
void main() {
  /// Project type where cycle [activeCycleId] spans "now"; other cycles
  /// sit in 30-day windows before/after so only one matches.
  ProjectTypeModel campaignProjectType(int activeCycleId,
      {int totalCycles = 3}) {
    final now = DateTime.now();
    return ProjectTypeModel(
      id: 'ors-pt-1',
      code: 'ORS-Zinc',
      cycles: [
        for (var i = 1; i <= totalCycles; i++)
          ProjectCycle(
            id: i,
            startDate: now
                .subtract(Duration(days: 30 * (activeCycleId - i) + 15))
                .millisecondsSinceEpoch,
            endDate: now
                .subtract(Duration(days: 30 * (activeCycleId - i) - 15))
                .millisecondsSinceEpoch,
          ),
      ],
    );
  }

  /// Sets the campaign projectType whose cycle [activeCycleId] is running;
  /// null simulates a missing projectType (no resolvable cycle).
  void setActiveOrsCycle(int? activeCycleId) {
    FlowBuilderSingleton().setInitialData(
      loggedInUserUuid: 'test-user',
      maxRadius: 1000,
      projectId: 'project-1',
      selectedBeneficiaryType: BeneficiaryType.household,
      projectType:
          activeCycleId == null ? null : campaignProjectType(activeCycleId),
      selectedProject: ProjectModel(id: 'project-1', name: 'Test Project'),
      loggedInUser: null,
    );
  }

  TaskModel orsTask({
    required String status,
    String? cycleIndex,
    String flow = 'orsDone',
  }) =>
      TaskModel(
        clientReferenceId: 'task-$flow-$status-${cycleIndex ?? 'none'}',
        status: status,
        additionalFields: TaskAdditionalFields(
          version: 1,
          fields: [
            AdditionalField('flow', flow),
            if (cycleIndex != null) AdditionalField('cycleIndex', cycleIndex),
          ],
        ),
      );

  bool isOrsDelivered(List<TaskModel> tasks) {
    final fn = FunctionRegistry.get('isORSDelivered');
    expect(fn, isNotNull, reason: 'isORSDelivered must be registered');
    return fn!.call([tasks], CrudStateData({}, [])) as bool;
  }

  setUpAll(() {
    initializeFunctionRegistry();
  });

  group('isORSDelivered per-cycle scoping', () {
    test('ORS delivered in the current cycle -> delivered (chip shows)', () {
      setActiveOrsCycle(1);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.administrationSuccess, cycleIndex: '1'),
      ]);
      expect(delivered, isTrue);
    });

    test(
        'ORS delivered in cycle 1 -> NOT delivered in cycle 2 '
        '(button can re-enable)', () {
      setActiveOrsCycle(2);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.administrationSuccess, cycleIndex: '1'),
      ]);
      expect(delivered, isFalse);
    });

    test('zero-padded cycleIndex "01" matches cycle 1', () {
      setActiveOrsCycle(1);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.administrationSuccess, cycleIndex: '01'),
      ]);
      expect(delivered, isTrue);
    });

    test(
        'task stamped with a FUTURE cycle counts as delivered NOW '
        '(defensive: bad stamp like nextCycleId must not re-enable the '
        'button in the same cycle)', () {
      setActiveOrsCycle(1);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.administrationSuccess, cycleIndex: '2'),
      ]);
      expect(delivered, isTrue);
    });

    test('cycle-1 delivery and cycle-2 delivery -> delivered in cycle 2', () {
      setActiveOrsCycle(2);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.administrationSuccess, cycleIndex: '1'),
        orsTask(status: TaskStatus.administrationSuccess, cycleIndex: '2'),
      ]);
      expect(delivered, isTrue);
    });
  });

  group('isORSDelivered conservative fallbacks (original behavior)', () {
    test(
        'delivered ORS task without cycleIndex counts as delivered in a '
        'later cycle too (legacy data never silently re-enabled)', () {
      setActiveOrsCycle(2);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.administrationSuccess),
      ]);
      expect(delivered, isTrue);
    });

    test(
        'no project type / unresolvable cycle -> any delivered ORS counts '
        '(old behavior)', () {
      setActiveOrsCycle(null);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.administrationSuccess, cycleIndex: '1'),
      ]);
      expect(delivered, isTrue);
    });
  });

  group('isORSDelivered unchanged filters', () {
    test('no tasks -> not delivered', () {
      setActiveOrsCycle(1);
      expect(isOrsDelivered([]), isFalse);
    });

    test('SMC/VAS delivered tasks do not count as ORS', () {
      setActiveOrsCycle(1);
      final delivered = isOrsDelivered([
        orsTask(
            status: TaskStatus.administrationSuccess,
            cycleIndex: '1',
            flow: 'smcDone'),
        orsTask(
            status: TaskStatus.administrationSuccess,
            cycleIndex: '1',
            flow: 'vasDone'),
      ]);
      expect(delivered, isFalse);
    });

    test('non-success ORS statuses do not count', () {
      setActiveOrsCycle(1);
      final delivered = isOrsDelivered([
        orsTask(status: TaskStatus.ineligible, cycleIndex: '1'),
        orsTask(status: TaskStatus.beneficiaryRefused, cycleIndex: '1'),
      ]);
      expect(delivered, isFalse);
    });
  });
}
