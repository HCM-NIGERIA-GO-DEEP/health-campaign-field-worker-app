// F4 (RC-02): header and footer widgets must read their own screen
// instance's state, not the newest instance registered under the bare key.
import 'package:digit_flow_builder/blocs/app_localization.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/layout_renderer.dart';
import 'package:digit_flow_builder/router/flow_builder_routes.gm.dart';
import 'package:digit_flow_builder/widget_registry.dart';
import 'package:digit_ui_components/widgets/atoms/digit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

const kDisabledExpr = "{{searchBar}} == null || {{searchBar}} == ''";

Map<String, dynamic> screenConfig() => {
      'name': kScreen,
      'screenType': 'TEMPLATE',
      'body': <dynamic>[],
      'footer': [
        {
          'format': 'button',
          'label': 'REGISTER_BENEFICIARY',
          'fieldName': 'registerBeneficiary',
          'disabled': kDisabledExpr,
          'properties': {'type': 'primary', 'size': 'large'},
        }
      ],
    };

Future<void> pumpScreen(WidgetTester tester, String instanceId) async {
  await tester.pumpWidget(MaterialApp(
    onGenerateRoute: (_) => MaterialPageRoute(
      settings: RouteSettings(
        arguments: FlowBuilderHomeRouteArgs(
          pageName: kScreen,
          navigationParams: {'_instanceId': instanceId},
        ),
      ),
      builder: (_) => LayoutRendererPage(
        config: screenConfig(),
        compositeKey: '$kScreen::$instanceId',
        appLocalizations: FlowBuilderLocalization(
          const Locale('en', 'NG'),
          Future.value(<dynamic>[]),
          const <dynamic>[],
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() {
    initTestEnv();
    WidgetRegistry.initialize();
  });
  setUp(resetRegistry);
  tearDown(resetRegistry);

  testWidgets('the older screen keeps an enabled Register after the newer one closes',
      (tester) async {
    final reg = FlowCrudStateRegistry();
    reg.registerInstance(kScreen, 'A');
    reg.updateByCompositeKey(
        '$kScreen::A', const FlowCrudState(widgetData: {'searchBar': 'Ad'}));
    reg.registerInstance(kScreen, 'B');
    reg.updateByCompositeKey(
        '$kScreen::B', const FlowCrudState(widgetData: {'searchBar': 'zz'}));
    reg.disposeByCompositeKey('$kScreen::B'); // B closed; owner stays B

    await pumpScreen(tester, 'A');

    final button = tester.widget<DigitButton>(find.byType(DigitButton));
    expect(button.isDisabled, isFalse,
        reason: 'A typed a name; its footer must read A, not the closed B');
  });

  testWidgets('single instance: the footer reads the same slot the body writes',
      (tester) async {
    // Regression guard for every other flow screen: with one instance open,
    // the footer's composite key and the bare key resolve to the same slot
    // (flow_crud_bloc.dart:651-668), so nothing changes for those screens.
    final reg = FlowCrudStateRegistry();
    reg.registerInstance(kScreen, 'A');
    reg.update(kScreen, const FlowCrudState(widgetData: {'searchBar': 'Ad'})); // bare write

    await pumpScreen(tester, 'A');

    expect(tester.widget<DigitButton>(find.byType(DigitButton)).isDisabled, isFalse);
    expect(identical(reg.listen(kScreen), reg.listenByCompositeKey('$kScreen::A')), isTrue);
  });

  testWidgets('control: an empty search box on the screen disables Register', (tester) async {
    final reg = FlowCrudStateRegistry();
    reg.registerInstance(kScreen, 'A');
    reg.updateByCompositeKey('$kScreen::A', const FlowCrudState(widgetData: {}));

    await pumpScreen(tester, 'A');

    expect(tester.widget<DigitButton>(find.byType(DigitButton)).isDisabled, isTrue);
  });
}
