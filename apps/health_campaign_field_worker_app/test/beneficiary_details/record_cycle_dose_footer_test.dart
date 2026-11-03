// QA (Kebbi AZM, 2026-11-03): after a child got this cycle's only dose,
// beneficiaryDetails still showed "Record Cycle Dose". It was the no-stock
// twin of the button (insufficientStockPopUp, same label): its "already
// delivered" guard read `contextData.0.task`, which this screen doesn't have
// (the relation is `tasks`), so a worker holding less than one dose always
// saw it. Proven on device: AZM 12 required, 0 available.
//
// Decision (Amit, 2026-11-03): the popup shows exactly when the Record button
// would, but stock is short: canRecordDelivery(nextCycleId) && !hasStock.
//
// Reads both footer rules from the bundled REGISTRATION.json, which is
// gitignored (a clone of the config repo); skipped when it is absent.
import 'dart:convert';
import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;
import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/function_registries.dart';

import '../widget_app.dart';

const _day = Duration.millisecondsPerDay;
const _configPath = 'assets/configs/json/REGISTRATION.json';

/// Footer rules of beneficiaryDetails, keyed by fieldName.
Map<String, String> _footerRules() {
  final raw = File(_configPath).readAsStringSync().replaceFirst('﻿', '');
  final flows = (jsonDecode(raw) as Map)['flows'] as List;
  final screen = flows.cast<Map>().firstWhere(
        (f) => f['name'] == 'beneficiaryDetails',
      );
  return {
    for (final item in (screen['footer'] as List).cast<Map>())
      item['fieldName'] as String: item['visible'] as String,
  };
}

/// Kebbi AZM's shape: cycle 1 running now, cycle 2 not started, one dose each.
void _setProject() {
  final now = DateTime.now().millisecondsSinceEpoch;
  ProjectCycle cycle(int id, int start, int end) => ProjectCycle(
        id: id,
        startDate: start,
        endDate: end,
        deliveries: [ProjectCycleDelivery(id: 1, deliveryStrategy: 'DIRECT')],
      );
  FlowBuilderSingleton().setInitialData(
    loggedInUserUuid: 'U1',
    maxRadius: 0,
    projectId: 'P1',
    selectedBeneficiaryType: BeneficiaryType.individual,
    projectType: ProjectTypeModel(id: 'PT1', code: 'AZT', cycles: [
      cycle(1, now - 2 * _day, now + 58 * _day),
      cycle(2, now + 59 * _day, now + 89 * _day),
    ]),
    selectedProject: ProjectModel(id: 'P1', name: 'Project', tenantId: 'kb'),
    loggedInUser: UserModel(uuid: 'U1'),
  );
}

/// The screen's wrapper as the details page builds it: the next cycle to
/// record (2 once cycle 1's only dose is given) and the dose's products.
Map<String, dynamic> _wrapper({required int nextCycleId}) => {
      'nextCycleId': nextCycleId,
      'eligibleProductVariants': [
        {
          'condition': '12<=age and age<=59',
          'ProductVariants': [
            {'quantity': 12, 'productVariantId': 'PV-AZM', 'name': 'AZM'},
          ],
        },
      ],
    };

/// Mirrors LayoutRenderer: an item is hidden only when its rule is false.
bool _shown(String rule, Map<String, dynamic> wrapper) {
  final rawState = [wrapper];
  return ConditionalEvaluator.evaluate(
        rule,
        {'contextData': rawState},
        screenKey: 'beneficiaryDetails::test',
        stateData: CrudStateData({}, rawState),
      ) !=
      false;
}

void main() {
  final configMissing =
      File(_configPath).existsSync() ? null : '$_configPath not present';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    data_model_mappers.initializeMappers();
    initializeFunctionRegistry();
    _setProject();
  });
  tearDown(StockBalanceCache.instance.clear);

  for (final scenario in [
    // (name, nextCycleId, AZM held, popup shown, Record button shown)
    ('dose given, no stock (QA)', 2, 0.0, false, false),
    ('dose given, enough stock', 2, 24.0, false, false),
    ('dose due, no stock', 1, 0.0, true, false),
    ('dose due, enough stock', 1, 24.0, false, true),
    ('every cycle done, no stock', 3, 0.0, false, false),
  ]) {
    final (name, nextCycleId, held, popup, button) = scenario;

    testWidgets('$name: popup ${popup ? 'shown' : 'hidden'}, '
        'Record button ${button ? 'shown' : 'hidden'}', (tester) async {
      await tester.pumpWidget(WidgetApp(
        child: Builder(builder: (context) {
          FunctionRegistries(context).registerAll();
          return const SizedBox.shrink();
        }),
      ));
      StockBalanceCache.instance.setCache('F1', {'PV-AZM': held});

      final rules = _footerRules();
      final wrapper = _wrapper(nextCycleId: nextCycleId);

      expect(_shown(rules['insufficientStockPopUp']!, wrapper), popup,
          reason: 'popup rule: ${rules['insufficientStockPopUp']}');
      expect(_shown(rules['recordCycle']!, wrapper), button,
          reason: 'button rule: ${rules['recordCycle']}');
    }, skip: configMissing != null);
  }
}
