import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the "Mark Closed Household" home card's navigation.
///
/// It used to hand-roll its own SharedPreferences read of
/// `app_config_schemas['CLOSEHOUSEHOLD']`, bypassing `FlowNavigationUtils`
/// (the path every other flow - Complaints, Registration, Inventory - goes
/// through). That bespoke path had no null-safety on the decoded schema and
/// swallowed every failure via `catch (e) { debugPrint('error $e'); }`, so a
/// missing/incompatible remote schema meant the form could still open but
/// nothing was ever persisted, with zero feedback to the user.
///
/// The fix routes Closed Household through the same
/// `FlowNavigationUtils.navigateToFlowModule` used by every other flow,
/// which loads the verified-correct bundled CLOSEHOUSEHOLD.json.
void main() {
  late String closedHouseholdBlock;

  setUpAll(() {
    final file = File('${Directory.current.path}/lib/pages/home.dart');
    final source = file.readAsStringSync();

    final startMarker = "i18.home.closedHouseHoldLabel:";
    final endMarker = "i18.home.manageStockLabel:";
    final start = source.indexOf(startMarker);
    final end = source.indexOf(endMarker);
    expect(start, greaterThanOrEqualTo(0),
        reason: 'Could not locate the closedHouseHoldLabel home item');
    expect(end, greaterThan(start),
        reason: 'Could not locate the manageStockLabel home item after it');

    closedHouseholdBlock = source.substring(start, end);
  });

  test('Closed Household navigates via FlowNavigationUtils, like every other flow', () {
    expect(
      closedHouseholdBlock.contains('FlowNavigationUtils.navigateToFlowModule'),
      isTrue,
    );
    expect(closedHouseholdBlock.contains("schemaKey: 'CLOSEHOUSEHOLD'"), isTrue);
  });

  test('Closed Household no longer hand-rolls its own SharedPreferences schema read', () {
    expect(closedHouseholdBlock.contains("prefs.getString('app_config_schemas')"), isFalse);
    expect(closedHouseholdBlock.contains("allSchemas['CLOSEHOUSEHOLD']"), isFalse);
  });
}
