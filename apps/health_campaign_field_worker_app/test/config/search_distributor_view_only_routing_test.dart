import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A Distributor tapping a household in search used to land in the same
/// editable, multi-page HOUSEHOLD registration form a Registrar uses (the
/// tap-routing on the "OPEN" button never checked role at all). Since there
/// is no per-field view-only mode for that form, Distributors are now routed
/// straight to householdOverview (the summary page with the Deliver ITN
/// button) instead for any not-yet-delivered household. Registrar routing
/// (editable form, insufficient-stock popup) is unchanged other than adding
/// the same "not a Distributor" guard, so a dual-role user gets the
/// Distributor (view-only) behavior.
void main() {
  late List<dynamic> openButtonOnAction;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final flows = (config['flows'] as List).cast<Map<String, dynamic>>();
    final search = flows.firstWhere((f) => f['name'] == 'searchBeneficiary');
    final serialized = jsonEncode(search);
    final decoded = jsonDecode(serialized) as Map<String, dynamic>;

    Map<String, dynamic>? findOpenButton(dynamic node) {
      if (node is Map<String, dynamic>) {
        if (node['label'] == 'OPEN' && node['format'] == 'button') {
          return node;
        }
        for (final value in node.values) {
          final found = findOpenButton(value);
          if (found != null) return found;
        }
      } else if (node is List) {
        for (final item in node) {
          final found = findOpenButton(item);
          if (found != null) return found;
        }
      }
      return null;
    }

    openButtonOnAction =
        (findOpenButton(decoded)!['onAction'] as List).cast<Map<String, dynamic>>();
  });

  Map<String, dynamic> branchWithNavTarget(String name) {
    return openButtonOnAction.firstWhere((branch) {
      final actions = (branch['actions'] as List).cast<Map<String, dynamic>>();
      final nav = actions.firstWhere(
        (a) => a['actionType'] == 'NAVIGATION',
        orElse: () => const {},
      );
      return (nav['properties'] as Map<String, dynamic>?)?['name'] == name;
    });
  }

  test('a Distributor tapping a not-yet-delivered household goes to householdOverview', () {
    final branch = branchWithNavTarget('householdOverview');

    expect(
      branch['condition']['expression'],
      "{{fn:hasRole('DISTRIBUTOR')}} == true && {{fn:isClosedHousehold(item.tasks)}} == false",
    );

    final actions = (branch['actions'] as List).cast<Map<String, dynamic>>();
    expect(actions.map((a) => a['actionType']), ['NAVIGATION']);

    final navProps =
        actions.first['properties'] as Map<String, dynamic>;
    expect(navProps['type'], 'TEMPLATE');
    final data = (navProps['data'] as List).cast<Map<String, dynamic>>();
    final keys = data.map((d) => d['key']).toSet();
    expect(keys, contains('HouseholdClientReferenceId'));
    // The project beneficiary must travel with the household: the delivery
    // task hangs its projectBeneficiaryClientReferenceId off this nav param,
    // and without it the created task never joins back to the household, so
    // the search card stays on "Delivery Pending" forever.
    expect(keys, contains('ProjectBeneficiaryClientReferenceId'));
  });

  test('the editable HOUSEHOLD form branches are Registrar-only (exclude Distributor)', () {
    // There are two such branches - reopening a still-closed household vs
    // plainly editing a registered one - split on fn:isHouseholdMarkedClosed
    // so that only the latter skips ahead to householdDetails. Both must stay
    // gated on stock / not-yet-delivered / not-a-Distributor. The clauses are
    // asserted individually rather than as one exact string so that adding a
    // further branch condition does not break this test.
    final branches = openButtonOnAction.where((b) {
      final actions = (b['actions'] as List).cast<Map<String, dynamic>>();
      final nav = actions.firstWhere(
        (a) => a['actionType'] == 'NAVIGATION',
        orElse: () => const {},
      );
      final props = nav['properties'] as Map<String, dynamic>?;
      return props?['name'] == 'HOUSEHOLD' && props?['type'] == 'FORM';
    }).toList();

    expect(branches, hasLength(2));

    for (final branch in branches) {
      final expression = branch['condition']['expression'] as String;
      expect(expression, contains('{{fn:hasStockForRegistration()}}==true'));
      expect(
          expression, contains('{{fn:isClosedHousehold(item.tasks)}} == false'));
      expect(expression, contains("{{fn:hasRole('DISTRIBUTOR')}} == false"));
    }
  });

  test('the insufficient-stock-for-registration popup is now Registrar-only too', () {
    final branch = openButtonOnAction.firstWhere((b) {
      final actions = (b['actions'] as List).cast<Map<String, dynamic>>();
      return actions.any((a) => a['actionType'] == 'OPEN_POPUP');
    });

    expect(
      branch['condition']['expression'],
      "{{fn:hasStockForRegistration()}}==false && {{fn:isClosedHousehold(item.tasks)}} == false && {{fn:hasRole('DISTRIBUTOR')}} == false",
    );
  });

  test('an already-delivered household still goes to the read-only previewScreen for both roles', () {
    final branch = branchWithNavTarget('previewScreen');

    expect(
      branch['condition']['expression'],
      "{{fn:isClosedHousehold(item.tasks)}} == true",
    );
  });
}
