import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers `checkEligibilityForAgeAndSideEffect` cycle handling:
///
/// - Case A: a within-age child marked INELIGIBLE in cycle 1 must be
///   re-evaluated (eligible) in cycle 2 — an ineligible verdict only holds for
///   the cycle it was recorded in.
/// - Regression table from commit 9e7bdcd18 (aged-out >59mo continuation):
///   those scenarios must keep their verdicts.
void main() {
  const smcAgeCondition = '3<=age && age<=59';

  /// Project type where cycle [activeCycleId] spans "now" and the other
  /// cycles sit in 30-day windows before/after it, so only one cycle matches
  /// the current-cycle lookup.
  ProjectTypeModel projectTypeWithActiveCycle(int activeCycleId,
      {int totalCycles = 3}) {
    final now = DateTime.now();
    final cycles = <ProjectCycle>[
      for (var i = 1; i <= totalCycles; i++)
        ProjectCycle(
          id: i,
          startDate: now
              .subtract(Duration(days: 30 * (activeCycleId - i) + 15))
              .millisecondsSinceEpoch,
          endDate: now
              .subtract(Duration(days: 30 * (activeCycleId - i) - 15))
              .millisecondsSinceEpoch,
          deliveries: [
            ProjectCycleDelivery(
              id: 1,
              deliveryStrategy: 'DIRECT',
              doseCriteria: [
                DeliveryDoseCriteria(condition: smcAgeCondition),
              ],
            ),
          ],
        ),
    ];
    return ProjectTypeModel(id: 'pt-1', code: 'SMC', cycles: cycles);
  }

  void setActiveCycle(int activeCycleId) {
    FlowBuilderSingleton().setInitialData(
      loggedInUserUuid: 'test-user',
      maxRadius: 1000,
      projectId: 'project-1',
      selectedBeneficiaryType: BeneficiaryType.household,
      projectType: projectTypeWithActiveCycle(activeCycleId),
      selectedProject: ProjectModel(id: 'project-1', name: 'Test Project'),
      loggedInUser: null,
    );
  }

  /// Individual whose age is [months] months as of today.
  Map<String, dynamic> individualAgedMonths(int months) {
    final now = DateTime.now();
    return {
      'dateOfBirth': DateTime(now.year, now.month - months, 1),
    };
  }

  Map<String, dynamic> smcTask({
    required String status,
    required int cycleIndex,
  }) =>
      {
        'status': status,
        'clientReferenceId': 'task-c$cycleIndex-$status',
        'additionalFields': {
          'fields': [
            {'key': 'flow', 'value': 'smcDone'},
            {'key': 'cycleIndex', 'value': '$cycleIndex'},
          ],
        },
      };

  bool checkEligibility({
    required Map<String, dynamic> individual,
    required List<Map<String, dynamic>> tasks,
    required int currentRunningCycle,
  }) {
    final fn = FunctionRegistry.get('checkEligibilityForAgeAndSideEffect');
    expect(fn, isNotNull,
        reason: 'checkEligibilityForAgeAndSideEffect must be registered');
    final result = fn!.call(
      [individual, tasks, currentRunningCycle],
      CrudStateData({}, []),
    );
    return result as bool;
  }

  setUpAll(() {
    initializeFunctionRegistry();
  });

  group('within-age: previous-cycle INELIGIBLE (Case A)', () {
    // The rule is age-generic, not 11-months-specific: any child still
    // matching dose criteria is re-evaluated each cycle regardless of why the
    // previous cycle marked them ineligible (checklist assessment or any
    // INELIGIBLE task — both persist as status INELIGIBLE via
    // ineligibleConfig).
    for (final ageMonths in [4, 11, 24, 36, 59]) {
      test(
          '${ageMonths}mo child INELIGIBLE in cycle 1 is eligible again '
          'in cycle 2', () {
        setActiveCycle(2);
        final eligible = checkEligibility(
          individual: individualAgedMonths(ageMonths),
          tasks: [smcTask(status: TaskStatus.ineligible, cycleIndex: 1)],
          currentRunningCycle: 2,
        );
        expect(eligible, isTrue);
      });
    }

    test(
        'child aged past dose criteria (>59mo) with only a cycle-1 '
        'INELIGIBLE stays ineligible — no criteria match ends eligibility',
        () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(61),
        tasks: [smcTask(status: TaskStatus.ineligible, cycleIndex: 1)],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test('INELIGIBLE recorded in the current cycle still blocks', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(11),
        tasks: [smcTask(status: TaskStatus.ineligible, cycleIndex: 2)],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test('INELIGIBLE in cycle 1 blocks while still inside cycle 1', () {
      setActiveCycle(1);
      final eligible = checkEligibility(
        individual: individualAgedMonths(11),
        tasks: [smcTask(status: TaskStatus.ineligible, cycleIndex: 1)],
        currentRunningCycle: 1,
      );
      expect(eligible, isFalse);
    });

    test('BENEFICIARY_DIED in a previous cycle blocks every later cycle', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(11),
        tasks: [smcTask(status: TaskStatus.beneficiaryDied, cycleIndex: 1)],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test(
        'without a currentRunningCycle arg the cycle filter is bypassed, '
        'so INELIGIBLE from any cycle still blocks (old blanket behavior)',
        () {
      setActiveCycle(2);
      final fn = FunctionRegistry.get('checkEligibilityForAgeAndSideEffect');
      final result = fn!.call(
        [
          individualAgedMonths(11),
          [smcTask(status: TaskStatus.ineligible, cycleIndex: 1)],
        ],
        CrudStateData({}, []),
      );
      expect(result, isFalse);
    });

    test('within-age child with no tasks is eligible', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(11),
        tasks: [],
        currentRunningCycle: 2,
      );
      expect(eligible, isTrue);
    });
  });

  group('tasks without cycleIndex (legacy ineligibleConfig shape)', () {
    // The ineligibleConfig actions originally passed no cycleIndex (the
    // transformer drops null fields), so tasks created before the config fix
    // carry NO cycleIndex additionalField. Such tasks can't be attributed to
    // a cycle, so their blocking status is applied to EVERY cycle rather than
    // silently skipped — per-cycle re-eligibility requires the stamped
    // cycleIndex, which the REGISTRATION config now passes
    // ({{contextData.0.currentRunningCycle}}).

    /// Task with `flow: smcDone` but no cycleIndex field, created at
    /// [createdTime] (epoch millis) — mirrors what ineligibleConfig saves.
    Map<String, dynamic> checklistTask({
      required String status,
      required int createdTime,
    }) =>
        {
          'status': status,
          'clientReferenceId': 'task-nocycle-$status-$createdTime',
          'clientAuditDetails': {'createdTime': createdTime},
          'additionalFields': {
            'fields': [
              {'key': 'flow', 'value': 'smcDone'},
            ],
          },
        };

    test(
        'INELIGIBLE created in the current cycle window blocks '
        '(QA overview case)', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(11),
        tasks: [
          checklistTask(
            status: TaskStatus.ineligible,
            createdTime: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test(
        'INELIGIBLE without cycleIndex created during cycle 1 also blocks '
        'cycle 2 (unattributable => conservative; creation time is NOT used)',
        () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(11),
        tasks: [
          checklistTask(
            status: TaskStatus.ineligible,
            createdTime: DateTime.now()
                .subtract(const Duration(days: 30))
                .millisecondsSinceEpoch,
          ),
        ],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test(
        'INELIGIBLE with neither cycleIndex nor timestamps blocks '
        '(unattributable tasks are never silently ignored)', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(11),
        tasks: [
          {
            'status': TaskStatus.ineligible,
            'clientReferenceId': 'task-nocycle-notime',
            'additionalFields': {
              'fields': [
                {'key': 'flow', 'value': 'smcDone'},
              ],
            },
          },
        ],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test(
        'aged-out child with only a cycle-1-window INELIGIBLE stays '
        'ineligible', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [
          checklistTask(
            status: TaskStatus.ineligible,
            createdTime: DateTime.now()
                .subtract(const Duration(days: 30))
                .millisecondsSinceEpoch,
          ),
        ],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });
  });

  group('aged-out (>59mo) regression table from commit 9e7bdcd18', () {
    test('cycle 2, successful cycle-1 delivery -> eligible', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [
          smcTask(status: TaskStatus.administrationSuccess, cycleIndex: 1),
        ],
        currentRunningCycle: 2,
      );
      expect(eligible, isTrue);
    });

    test('cycle 2, cycle-1 absent -> ineligible', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [
          smcTask(status: TaskStatus.beneficiaryAbsent, cycleIndex: 1),
        ],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test('cycle 2, no task at all -> ineligible', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test('cycle 2, cycle-1 INELIGIBLE only -> stays ineligible', () {
      setActiveCycle(2);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [smcTask(status: TaskStatus.ineligible, cycleIndex: 1)],
        currentRunningCycle: 2,
      );
      expect(eligible, isFalse);
    });

    test('cycle 3, cycle-1 and cycle-2 delivered -> eligible', () {
      setActiveCycle(3);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [
          smcTask(status: TaskStatus.administrationSuccess, cycleIndex: 1),
          smcTask(status: TaskStatus.administrationSuccess, cycleIndex: 2),
        ],
        currentRunningCycle: 3,
      );
      expect(eligible, isTrue);
    });

    test('cycle 3, cycle-1 delivered but cycle-2 missed -> eligible', () {
      setActiveCycle(3);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [
          smcTask(status: TaskStatus.administrationSuccess, cycleIndex: 1),
        ],
        currentRunningCycle: 3,
      );
      expect(eligible, isTrue);
    });

    test('cycle 3, late joiner delivered in cycle 2 only -> eligible', () {
      setActiveCycle(3);
      final eligible = checkEligibility(
        individual: individualAgedMonths(70),
        tasks: [
          smcTask(status: TaskStatus.administrationSuccess, cycleIndex: 2),
        ],
        currentRunningCycle: 3,
      );
      expect(eligible, isTrue);
    });
  });
}
