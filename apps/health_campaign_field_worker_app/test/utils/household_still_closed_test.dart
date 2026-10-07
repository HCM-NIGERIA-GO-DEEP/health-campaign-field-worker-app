import 'package:digit_data_model/data_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart';

/// Guards the household -> projectBeneficiary -> task resolution shared by
/// the Summary Report and the home page's Beneficiary Progress bar: a
/// household whose own last task is still CLOSED_HOUSEHOLD status (Mark
/// Closed Household, or a declined consent) is a placeholder, not a real
/// registration, until it's reopened and completed.
void main() {
  TaskModel task({
    required String projectBeneficiaryClientReferenceId,
    required String status,
    required int createdTime,
  }) {
    return TaskModel(
      clientReferenceId: 'task-$createdTime',
      projectBeneficiaryClientReferenceId: projectBeneficiaryClientReferenceId,
      status: status,
      clientAuditDetails: ClientAuditDetails(
        createdBy: 'user-1',
        createdTime: createdTime,
        lastModifiedBy: 'user-1',
        lastModifiedTime: createdTime,
      ),
    );
  }

  ProjectBeneficiaryModel projectBeneficiary({
    required String beneficiaryClientReferenceId,
    required String clientReferenceId,
  }) {
    return ProjectBeneficiaryModel(
      clientReferenceId: clientReferenceId,
      beneficiaryClientReferenceId: beneficiaryClientReferenceId,
      dateOfRegistration: 0,
    );
  }

  test('a household with no projectBeneficiary at all is not considered closed', () {
    final result = isHouseholdStillClosed(
      householdClientReferenceId: 'hh-1',
      projectBeneficiaryClientRefsByHousehold: {},
      tasksByProjectBeneficiaryClientRef: {},
    );

    expect(result, isFalse);
  });

  test('a household whose last task is CLOSED_HOUSEHOLD is still closed', () {
    final pbs = [projectBeneficiary(beneficiaryClientReferenceId: 'hh-1', clientReferenceId: 'pb-1')];
    final tasks = [
      task(projectBeneficiaryClientReferenceId: 'pb-1', status: 'CLOSED_HOUSEHOLD', createdTime: 100),
    ];

    final result = isHouseholdStillClosed(
      householdClientReferenceId: 'hh-1',
      projectBeneficiaryClientRefsByHousehold:
          groupProjectBeneficiaryClientRefsByHousehold(pbs),
      tasksByProjectBeneficiaryClientRef:
          groupTasksByProjectBeneficiaryClientRef(tasks),
    );

    expect(result, isTrue);
  });

  test('a household reopened and completed (later task moves off CLOSED_HOUSEHOLD) is no longer closed', () {
    final pbs = [projectBeneficiary(beneficiaryClientReferenceId: 'hh-1', clientReferenceId: 'pb-1')];
    final tasks = [
      task(projectBeneficiaryClientReferenceId: 'pb-1', status: 'CLOSED_HOUSEHOLD', createdTime: 100),
      task(projectBeneficiaryClientReferenceId: 'pb-1', status: 'NOT_ADMINISTERED', createdTime: 200),
    ];

    final result = isHouseholdStillClosed(
      householdClientReferenceId: 'hh-1',
      projectBeneficiaryClientRefsByHousehold:
          groupProjectBeneficiaryClientRefsByHousehold(pbs),
      tasksByProjectBeneficiaryClientRef:
          groupTasksByProjectBeneficiaryClientRef(tasks),
    );

    expect(result, isFalse);
  });

  test('a normal household (no CLOSED_HOUSEHOLD task ever) is never considered closed', () {
    final pbs = [projectBeneficiary(beneficiaryClientReferenceId: 'hh-2', clientReferenceId: 'pb-2')];
    final tasks = [
      task(projectBeneficiaryClientReferenceId: 'pb-2', status: 'ADMINISTRATION_SUCCESS', createdTime: 100),
    ];

    final result = isHouseholdStillClosed(
      householdClientReferenceId: 'hh-2',
      projectBeneficiaryClientRefsByHousehold:
          groupProjectBeneficiaryClientRefsByHousehold(pbs),
      tasksByProjectBeneficiaryClientRef:
          groupTasksByProjectBeneficiaryClientRef(tasks),
    );

    expect(result, isFalse);
  });
}
