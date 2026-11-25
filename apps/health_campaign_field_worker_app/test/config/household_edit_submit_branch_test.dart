import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/action_handler.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// QA (Liberia, 2026-11-25): "when we are updating the details of head ... it
/// is not getting stored in db or elastic".
///
/// A FORM screen submits through the FLOW's `onAction` only
/// (screen_builder.dart `_handleFormSubmission`); a page's own `onAction` is
/// never read (`transformJson` does not copy it). The plain "edit household
/// details" branch lived on the householdDetails PAGE, so a head edit fell
/// through to the flow's DEFAULT branch and ran CREATE_EVENT on records that
/// already exist: the household was re-created with a "create" sync entry and
/// the individual's insert failed on its existing identifier row.
///
/// These tests run the flow's real `onAction` through the real
/// `ActionHandler.executeActions` with recording executors, and name the
/// actions each way of opening the HOUSEHOLD form ends up running.
class _Recorder extends ActionExecutor {
  _Recorder(this.log);

  final List<String> log;

  @override
  bool canHandle(String actionType) => true;

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    final detail = action.properties['configName'] ??
        action.properties['entity'] ??
        action.properties['name'];
    log.add(detail == null ? action.actionType : '${action.actionType}:$detail');
    return contextData;
  }
}

const _actionTypes = [
  'FETCH_TRANSFORMER_CONFIG',
  'CREATE_EVENT',
  'UPDATE_EVENT',
  'UPDATE_IDENTIFIER_STATUS',
  'NAVIGATION',
  'SHOW_TOAST',
];

void main() {
  late List<dynamic> householdOnAction;
  final log = <String>[];

  setUpAll(() {
    final flows = ((sampleFlows as Map)['flows'] as List).cast<Map<String, dynamic>>();
    final household = flows.firstWhere(
      (f) => f['name'] == 'HOUSEHOLD' && f['screenType'] == 'FORM',
    );
    householdOnAction = household['onAction'] as List<dynamic>;
  });

  setUp(() {
    log.clear();
    for (final type in _actionTypes) {
      ActionHandler.registry.register(type, _Recorder(log));
    }
  });

  tearDown(() {
    ActionHandler.registry.unregister('UPDATE_IDENTIFIER_STATUS');
    ActionHandler.registry.registerDefaultExecutors();
  });

  /// What the forms bloc hands over on submit: one map per page, every page of
  /// the form, whether the user opened it or not.
  Map<String, dynamic> formData({required String? consent}) => {
        'beneficiaryLocation': {'administrativeArea': 'Boundary'},
        'caregiverConsent': {
          'consentToParticipate': consent,
          'firstName': null,
          'lastName': null,
        },
        'householdDetails': {
          'nameOfIndividual': 'Given',
          'familyname': 'Family',
          'memberCount': 3,
          'childrenCount': 2,
        },
      };

  Future<List<String>> submit(
    WidgetTester tester, {
    required Map<String, dynamic> navigation,
    required String? consent,
  }) async {
    late BuildContext context;
    await tester.pumpWidget(Builder(builder: (c) {
      context = c;
      return const SizedBox();
    }));
    await ActionHandler.executeActions(householdOnAction, context, {
      'formData': formData(consent: consent),
      'navigation': navigation,
      '_compositeKey': 'HOUSEHOLD::test',
    });
    return List.of(log);
  }

  // 'FALSE' cannot be reached from the app today (a declined household is
  // opened through the closed-household route), but an edit must update
  // whatever the stored consent is.
  for (final consent in ['TRUE', null, 'FALSE']) {
    testWidgets(
        'editing a registered household (stored consent $consent) updates it '
        'and never creates', (tester) async {
      final ran = await submit(
        tester,
        // editIndividualButton, head branch (householdOverview).
        navigation: {
          'HouseholdClientReferenceId': 'household',
          'isEdit': 'true',
          'startPage': 'householdDetails',
          'firstName': 'Given',
          'lastName': 'Family',
        },
        consent: consent,
      );

      expect(ran, isNot(contains('CREATE_EVENT')),
          reason: 'the household and its head already exist');
      expect(ran, isNot(contains('UPDATE_IDENTIFIER_STATUS')),
          reason: 'an edit assigns no new beneficiary id');
      expect(ran, [
        'FETCH_TRANSFORMER_CONFIG:householdDetailsEdit',
        'UPDATE_EVENT:HouseholdModel, IndividualModel',
        'NAVIGATION:householdOverview',
      ]);
    });
  }

  testWidgets('reopening a closed household with consent Yes is unchanged',
      (tester) async {
    final ran = await submit(
      tester,
      navigation: {
        'HouseholdClientReferenceId': 'household',
        'isEdit': 'true',
        'isClosedHousehold': 'true',
        'startPage': 'caregiverConsent',
      },
      consent: 'TRUE',
    );

    expect(ran, [
      'FETCH_TRANSFORMER_CONFIG:beneficiaryRegistration',
      'UPDATE_IDENTIFIER_STATUS',
      'UPDATE_EVENT:HouseholdModel, IndividualModel, TaskModel',
      'NAVIGATION:householdOverview',
    ]);
  });

  testWidgets('reopening a closed household with consent No is unchanged',
      (tester) async {
    final ran = await submit(
      tester,
      navigation: {
        'HouseholdClientReferenceId': 'household',
        'isEdit': 'true',
        'isClosedHousehold': 'true',
        'startPage': 'caregiverConsent',
      },
      consent: 'FALSE',
    );

    expect(ran, [
      'FETCH_TRANSFORMER_CONFIG:householdConsentDeclinedUpdate',
      'UPDATE_EVENT:HouseholdModel, IndividualModel, TaskModel',
      'NAVIGATION:caregiverAcknowledgement',
    ]);
  });

  testWidgets('a new registration with consent Yes still creates',
      (tester) async {
    final ran = await submit(
      tester,
      navigation: {'startPage': 'beneficiaryLocation'},
      consent: 'TRUE',
    );

    expect(ran, [
      'FETCH_TRANSFORMER_CONFIG:beneficiaryRegistration',
      'UPDATE_IDENTIFIER_STATUS',
      'CREATE_EVENT',
      'NAVIGATION:householdOverview',
    ]);
  });

  testWidgets('a new registration with consent No still creates',
      (tester) async {
    final ran = await submit(
      tester,
      navigation: {'startPage': 'beneficiaryLocation'},
      consent: 'FALSE',
    );

    expect(ran, [
      'FETCH_TRANSFORMER_CONFIG:householdConsentDeclinedRegistration',
      'UPDATE_IDENTIFIER_STATUS',
      'CREATE_EVENT',
      'NAVIGATION:caregiverAcknowledgement',
    ]);
  });
}
