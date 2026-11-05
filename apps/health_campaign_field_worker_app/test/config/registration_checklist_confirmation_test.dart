import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

void main() {
  Map<String, dynamic> flowNamed(String name) =>
      (sampleFlows['flows'] as List).cast<Map<String, dynamic>>().singleWhere(
            (flow) => flow['name'] == name,
          );

  test('both registrar checklist forms confirm on submit', () {
    for (final name in ['HOUSEHOLD', 'registrationHealthTalk']) {
      final schema = transformJson(flowNamed(name));
      final checklist = schema['pages']['registrationHealthTalkChecklist'];

      expect(checklist['showAlertPopUp'], {
        'title': 'APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE',
        'description': 'HOUSEHOLD_CHECKLIST_SUBMIT_DESCRIPTION',
        'primaryActionLabel': 'ACTION_SUBMIT',
        'secondaryActionLabel': 'ACTION_CANCEL',
      }, reason: name);
    }
  });

  test('overview submit still opens the registration acknowledgement', () {
    final overview = flowNamed('householdOverview');
    final submit = (overview['footer'] as List).singleWhere(
      (widget) => widget['fieldName'] == 'backToSearchRegistrar',
    );
    final action = (submit['onAction'] as List).single;
    final navigation = action['properties'];

    expect(action['actionType'], 'NAVIGATION');
    expect(navigation['name'], 'registrationHealthTalkSuccess');
    expect(navigation['navigationMode'], 'popUntilAndPush');
    expect(navigation['popUntilPageName'], 'searchBeneficiary');
    expect(navigation['data'], [
      {
        'key': 'HouseholdClientReferenceId',
        'value': '{{navigation.HouseholdClientReferenceId}}',
      },
      {
        'key': 'ProjectBeneficiaryClientReferenceId',
        'value': '{{navigation.ProjectBeneficiaryClientReferenceId}}',
      },
    ]);
  });
}
