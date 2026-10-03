import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/flow_widget_state.dart';
import 'package:digit_flow_builder/widget_registry.dart';
import 'package:digit_flow_builder/widgets/implementations/proximity_search_widget.dart';
import 'package:digit_flow_builder/widgets/resolved_flow_widget.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:digit_ui_components/widgets/atoms/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Toggling Proximity search must reset every ID/name search bar - otherwise
/// a leftover National ID or Phone Number typed before enabling Proximity
/// would silently re-apply once Proximity is turned back off. This is the
/// linkedSearchWidgetKeys/filterKeys list in proximity_search_widget.dart
/// that was extended for the National ID / Voter ID / Phone Number toggles.
class FakeLocationBloc extends MockBloc<LocationEvent, LocationState>
    implements LocationBloc {}

const _compositeKey = 'searchBeneficiary::proximity-test';

// Encoded as a JSON string (mirroring REGISTRATION.json) and decoded via
// json.decode below, rather than a typed Dart map literal. A Dart const
// literal infers concrete types like List<Map<String, Object>>, which makes
// firstWhere's generic `E` non-nullable and breaks on `orElse: () => null`
// inside proximity_search_widget.dart - a mismatch that can't happen in
// production, where config always arrives via json.decode() and is plain
// Map<String, dynamic>/List<dynamic>.
const _proximitySearchJsonString = '''
{
  "type": "template",
  "label": "SEARCH_BY_PROXIMITY",
  "format": "proximitySearch",
  "onAction": [
    {
      "actionType": "field.value==true ? SEARCH_EVENT : CLEAR_STATE",
      "properties": {
        "data": [
          {"key": "", "value": 5, "operation": "within"},
          {
            "key": "localityBoundaryCode",
            "root": "address",
            "value": "{{singleton.boundary.code}}",
            "operation": "equals"
          }
        ],
        "name": "address",
        "type": "field.value==true ? SEARCH_EVENT : CLEAR_STATE"
      }
    }
  ],
  "fieldName": "proximitySearch",
  "mandatory": true,
  "schemaCode": null,
  "validations": [
    {
      "key": "proximityRadius",
      "value": 5,
      "errorMessage": "PROXIMITY_RADIUS_ERROR_MESSAGE"
    }
  ]
}
''';

void main() {
  late FakeLocationBloc locationBloc;
  final dispatchedActions = <ActionConfig>[];

  setUp(() {
    locationBloc = FakeLocationBloc();
    // The widget only picks up lat/lng inside its BlocConsumer `listener`,
    // which only runs on a genuine state *change* on the stream - not on
    // whatever `initialState` the bloc starts with. So the loaded location
    // must arrive as a stream event, not just as the initial state.
    const loadedLocation = LocationState(
      latitude: 8.4657,
      longitude: -13.2317,
      hasPermissions: true,
      serviceEnabled: true,
    );
    whenListen(
      locationBloc,
      Stream<LocationState>.value(loadedLocation),
      initialState: const LocationState(),
    );
    dispatchedActions.clear();

    FlowCrudStateRegistry().update(
      _compositeKey,
      const FlowCrudState(
        widgetData: {
          'searchBar': 'John',
          'idSearchBar': '123456789012',
          'nationalIdSearchBar': '98765432109',
          'phoneNumberSearchBar': '76123456',
        },
      ),
    );
  });

  tearDown(() {
    FlowCrudStateRegistry().disposeAll();
  });

  Future<void> pumpWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LocationBloc>.value(
          value: locationBloc,
          child: CrudItemContext(
            compositeKey: _compositeKey,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final resolved = ResolvedWidgetContext(
                    state: WidgetStateContext(compositeKey: _compositeKey),
                    localization: null,
                  );
                  return ProximitySearchWidget().buildResolved(
                    jsonDecode(_proximitySearchJsonString) as Map<String, dynamic>,
                    context,
                    dispatchedActions.add,
                    resolved,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'enabling Proximity clears every search bar (Name, Beneficiary/National ID, Phone Number)',
    (tester) async {
      await pumpWidget(tester);

      final switchFinder = find.byType(DigitSwitch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final widgetData = FlowCrudStateRegistry().get(_compositeKey)?.widgetData;

      expect(widgetData, isNotNull);
      for (final key in [
        'searchBar',
        'idSearchBar',
        'nationalIdSearchBar',
        'phoneNumberSearchBar',
      ]) {
        expect(widgetData![key], '', reason: '$key should be cleared');
      }
    },
  );

  testWidgets(
    'enabling Proximity dispatches a CLEAR_STATE covering identifierType and mobileNumber filters',
    (tester) async {
      await pumpWidget(tester);

      await tester.tap(find.byType(DigitSwitch));
      await tester.pumpAndSettle();

      final clearStateAction = dispatchedActions.firstWhere(
        (a) => a.properties['name'] == 'address',
        orElse: () => throw StateError('No CLEAR_STATE action for "address" was dispatched'),
      );

      final filterKeys =
          (clearStateAction.properties['filterKeys'] as List).cast<String>();

      expect(filterKeys, containsAll(['identifierId', 'identifierType', 'mobileNumber']));
    },
  );
}
