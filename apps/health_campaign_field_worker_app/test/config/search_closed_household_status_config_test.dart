import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

void main() {
  late List<dynamic> cardChildren;

  setUpAll(() {
    final flows = (sampleFlows['flows'] as List).cast<Map<String, dynamic>>();
    final search = flows.firstWhere((f) => f['name'] == 'searchBeneficiary');
    final listView = (search['body'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((w) => w['fieldName'] == 'listView');
    cardChildren = listView['child']['children'] as List<dynamic>;
  });

  Map<String, dynamic> childNamed(String fieldName) {
    return cardChildren.cast<Map<String, dynamic>>().firstWhere(
          (w) => w['fieldName'] == fieldName,
          orElse: () => throw StateError('No card child with fieldName "$fieldName" found'),
        );
  }

  test('statusClosedHousehold shows only while the household is marked closed', () {
    final widget = childNamed('statusClosedHousehold');

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_CLOSED');
    expect(widget['visible'],
        "{{fn:isDelivered(item.tasks)}} == false && {{fn:isHouseholdMarkedClosed(item.tasks, item.HouseholdModel)}} == true");
  });

  test('statusNotVisited (Delivery Pending) excludes closed households, so the two never both show', () {
    final widget = childNamed('statusNotVisited');

    expect(
      widget['visible'],
      "{{fn:isDelivered(item.tasks)}} == false && {{fn:isHouseholdMarkedClosed(item.tasks, item.HouseholdModel)}} == false",
    );
  });

  test('closed household Open uses the current beneficiary ID pool', () {
    FlowBuilderSingleton().setInitialData(
      loggedInUserUuid: 'user',
      maxRadius: 0,
      projectId: 'project',
      selectedBeneficiaryType: BeneficiaryType.household,
      projectType: null,
      selectedProject: ProjectModel(id: 'project', name: 'Project'),
      loggedInUser: null,
      beneficiaryIdMinCount: 2,
    );
    FunctionRegistry.register('hasRole', (args, _) => args.single == 'REGISTRAR');
    FunctionRegistry.register('isDelivered', (args, _) => args.single == 'delivered');
    FunctionRegistry.register(
      'isHouseholdMarkedClosed',
      (args, _) => args.first == 'closed',
    );
    FunctionRegistry.register(
      'hasMinimumBeneficiaryId',
      (args, _) => (args[1] as int) >= (args[0] as int),
    );

    final row = cardChildren.firstWhere((child) => child['format'] == 'row');
    final open = (row['children'] as List)
        .singleWhere((child) => child['label'] == 'OPEN');

    bool isDisabled(String status, int count) =>
        ConditionalEvaluator.evaluate(open['disabled'], <String, dynamic>{
          'item': {'tasks': status},
          'contextData': const [],
          'widgetData': {'uniqueIdPoolCount': count},
        }) == true;

    expect(isDisabled('closed', 0), isTrue);
    expect(isDisabled('closed', 2), isFalse);
    expect(isDisabled('active', 0), isFalse);
    expect(isDisabled('delivered', 2), isTrue);
  });

  test('Android Back clears search after viewing or saving a household', () {
    final flows = sampleFlows['flows'] as List;
    for (final screen in [
      'householdOverview',
      'previewScreen',
      'caregiverAcknowledgement',
      'deliverySuccess',
    ]) {
      final flow = flows.singleWhere((flow) => flow['name'] == screen);
      final action = (flow['onSystemBack'] as List).single;

      expect(action['actionType'], 'NAVIGATION');
      expect(action['properties']['name'], 'searchBeneficiary');
      expect(action['properties']['navigationMode'], 'popUntilAndReplace');
      expect(action['properties']['popUntilPageName'], 'searchBeneficiary');
    }

    final search =
        flows.singleWhere((flow) => flow['name'] == 'searchBeneficiary');
    final action = (search['onSystemBack'] as List).single;
    expect(action['actionType'], 'BACK_NAVIGATION');
    expect(action['properties']['name'], 'HOME');

    final returnAction = (search['onReturn'] as List).single;
    expect(returnAction['properties']['navigationMode'], 'popUntilAndReplace');
    expect(returnAction['properties']['popUntilPageName'], 'searchBeneficiary');
  });

  test('delivered status is unaffected', () {
    final widget = childNamed('statusDelivered');

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_ITN_DELIVERED');
    expect(widget['visible'], "{{fn:isDelivered(item.tasks)}} == true");
  });
}
