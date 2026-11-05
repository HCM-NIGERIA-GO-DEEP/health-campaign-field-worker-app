import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:digit_flow_builder/utils/flow_widget_state.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

/// A household marked closed (via Mark Closed Household, or a declined
/// consent) used to show the same generic "Delivery Pending" status in
/// search as any normal not-yet-delivered household - a Registrar couldn't
/// tell the two apart. This adds a distinct "Closed Household" status,
/// shown only while the task's last status is literally CLOSED_HOUSEHOLD.
/// Once the household is reopened and completed, its task status moves off
/// CLOSED_HOUSEHOLD (see the HOUSEHOLD flow's isEdit && isClosedHousehold
/// branch), so it naturally falls back to "Delivery Pending" like any other
/// household - no separate "revert" logic needed.
void main() {
  late Map<String, dynamic> listView;
  late List<dynamic> cardChildren;

  setUpAll(() {
    final flows = (sampleFlows['flows'] as List).cast<Map<String, dynamic>>();
    final search = flows.firstWhere((f) => f['name'] == 'searchBeneficiary');
    listView = (search['body'] as List)
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

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_CLOSED_HOUSEHOLD');
    expect(widget['visible'], "{{fn:isHouseholdMarkedClosed(item.tasks)}} == true");
  });

  test('statusNotVisited (Delivery Pending) excludes closed households, so the two never both show', () {
    final widget = childNamed('statusNotVisited');

    expect(
      widget['visible'],
      "{{fn:isClosedHousehold(item.tasks)}} == false && {{fn:isHouseholdMarkedClosed(item.tasks)}} == false",
    );
  });

  testWidgets('Open requires an available ID only for a closed household',
      (tester) async {
    initializeFunctionRegistry();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox.shrink();
    })));

    final rowChildren = childNamed('detailsRow')['children'] as List;
    final open = rowChildren.singleWhere(
        (child) => child['fieldName'] == 'openMemberCard') as Map<String, dynamic>;

    bool disabled(String status, {int? availableIds}) {
      final state = WidgetStateContext(
        itemData: {
          'tasks': [
            {'status': status},
          ],
        },
        widgetData: {
          if (availableIds != null) 'uniqueIdPoolCount': availableIds,
        },
      );
      final rowConfig = preprocessConfigWithState(
        open,
        CrudStateData(const {}, const []),
        listIndex: 0,
        item: state.itemData,
      );
      return ConditionalEvaluator.evaluate(
              rowConfig['disabled'], state.evalContext,
              widgetdata: state.widgetData) ==
          true;
    }

    expect(disabled('CLOSED_HOUSEHOLD'), isTrue);
    expect(disabled('CLOSED_HOUSEHOLD', availableIds: 0), isTrue);
    expect(disabled('CLOSED_HOUSEHOLD', availableIds: 1), isFalse);
    expect(disabled('PENDING', availableIds: 0), isFalse);
    expect(disabled('VISITED', availableIds: 1), isTrue);

    // A closed household without consent must still take the guarded route.
    final closedWithoutConsent = WidgetStateContext(
      itemData: {
        'HouseholdModel': <String, dynamic>{},
        'tasks': [
          {'status': 'CLOSED_HOUSEHOLD'},
        ],
      },
    ).evalContext;
    final branches = open['onAction'] as List;
    final reopen = branches.firstWhere((branch) =>
        ConditionalEvaluator.evaluate(
            branch['condition']['expression'], closedWithoutConsent) ==
        true);
    expect((reopen['actions'] as List).first, {
      'actionType': 'LOAD_UNIQUE_ID_POOL',
      'properties': {'requireAvailable': true},
    });
  });

  testWidgets('closed results stay hidden for distributor-only users',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      FunctionRegistries(context).registerAll();
      return const SizedBox.shrink();
    })));

    final original = FunctionRegistry.get('hasRole')!;
    addTearDown(() => FunctionRegistry.register('hasRole', original));
    final state = WidgetStateContext(itemData: {
      'tasks': [
        {'status': 'CLOSED_HOUSEHOLD'},
      ],
    });

    FunctionRegistry.register('hasRole', (args, _) => args.contains('DISTRIBUTOR'));
    expect(ConditionalEvaluator.evaluate(listView['itemFilter'], state.evalContext),
        isFalse);
    FunctionRegistry.register('hasRole', (args, _) => args.contains('REGISTRAR'));
    expect(ConditionalEvaluator.evaluate(listView['itemFilter'], state.evalContext),
        isTrue);
  });

  test('leaving household overview refreshes retained search results', () {
    final overview = (sampleFlows['flows'] as List)
        .singleWhere((flow) => flow['name'] == 'householdOverview');
    final headerBack = (overview['header'] as List)
        .singleWhere((widget) => widget['format'] == 'backLink');
    final systemBack = overview['onSystemBack'];
    expect(systemBack, isA<List>());
    for (final actions in [headerBack['onAction'], systemBack]) {
      expect((actions as List).map((action) => action['actionType']),
          ['BACK_NAVIGATION', 'REFRESH_SEARCH']);
      expect(actions.first['properties']['forcePop'], isTrue);
      expect(actions.last['properties']['screenName'], 'searchBeneficiary');
    }
  });

  test('registration acknowledgement refreshes the retained search route', () {
    final success = (sampleFlows['flows'] as List)
        .singleWhere((flow) => flow['name'] == 'registrationHealthTalkSuccess');
    final card = (success['body'] as List).singleWhere(
        (widget) => widget['fieldName'] == 'registrationHealthTalkSuccessCard');
    for (final actions in [
      success['onSystemBack'],
      success['header'][0]['onAction'],
      card['secondaryAction']['onAction'],
    ]) {
      expect((actions as List).map((action) => action['actionType']),
          ['BACK_NAVIGATION', 'REFRESH_SEARCH']);
      expect(actions.first['properties']['name'], 'searchBeneficiary');
      expect(actions.first['properties']['forcePop'], isTrue);
      expect(actions.last['properties']['screenName'], 'searchBeneficiary');
    }
  });

  test('delivered status is unaffected', () {
    final widget = childNamed('statusDelivered');

    expect(widget['value'], 'SEARCH_HOUSEHOLD_STATUS_ITN_DELIVERED');
    expect(widget['visible'], "{{fn:isClosedHousehold(item.tasks)}} == true");
  });
}
