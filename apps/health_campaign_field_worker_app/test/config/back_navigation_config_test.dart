import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the "go back" actions that previously PUSHED their target instead
/// of popping to it.
///
/// NavigationService defaults an absent `navigationMode` to
/// NavigationMode.push (navigation_service.dart, _parseMode's `default:`), so
/// a NAVIGATION action pointing at the screen the user came FROM stacked a
/// second copy of it rather than returning. Repeating the journey grew the
/// stack - [search, overview, search, overview, search, ...] - and pressing
/// the device back button then walked back through those stale screens, so a
/// previously-visited household overview (or complaint detail) reappeared.
///
/// BACK_NAVIGATION is the correct action here: it pops until the named page
/// when that page is on the stack, and falls back to a single pop when it is
/// not (back_navigation_executor.dart), so it can never stack a duplicate.
void main() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(File('assets/configs/json/$name').readAsStringSync())
          as Map<String, dynamic>;

  /// Every action anywhere under [node], paired with the fieldName/label of
  /// the nearest enclosing widget, for readable failure messages.
  List<Map<String, dynamic>> actionsTargeting(dynamic node, String pageName) {
    final found = <Map<String, dynamic>>[];
    void walk(dynamic n) {
      if (n is Map) {
        if (n['properties'] is Map &&
            (n['properties'] as Map)['name'] == pageName &&
            n['actionType'] != null) {
          found.add(Map<String, dynamic>.from(n));
        }
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(node);
    return found;
  }

  Map<String, dynamic> flowNamed(Map<String, dynamic> config, String name) =>
      (config['flows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => f['name'] == name);

  group('REGISTRATION.json', () {
    late Map<String, dynamic> config;

    setUpAll(() => config = load('REGISTRATION.json'));

    for (final pageName in ['householdOverview', 'previewScreen']) {
      test('$pageName\'s back link pops rather than pushing a second search',
          () {
        final header = (flowNamed(config, pageName)['header'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((h) => h['format'] == 'backLink');
        final action =
            (header['onAction'] as List).cast<Map<String, dynamic>>().single;

        expect(action['actionType'], 'BACK_NAVIGATION');
        expect(action['properties']['name'], 'searchBeneficiary');
      });
    }

    test(
        'the Registrar CTA on householdOverview reads Save, not Back, and '
        'returns to the search screen', () {
      final button = (flowNamed(config, 'householdOverview')['footer'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['fieldName'] == 'backToSearchRegistrar');

      expect(button['label'], 'CORE_COMMON_SAVE');
      final action =
          (button['onAction'] as List).cast<Map<String, dynamic>>().single;
      expect(action['actionType'], 'BACK_NAVIGATION');
      expect(action['properties']['name'], 'searchBeneficiary');
    });

    test(
        'nothing in the registration flow navigates to searchBeneficiary with '
        'a plain push', () {
      for (final action in actionsTargeting(config, 'searchBeneficiary')) {
        if (action['actionType'] != 'NAVIGATION') continue;
        final mode = action['properties']['navigationMode'];
        expect(
          mode,
          isNotNull,
          reason: 'A NAVIGATION to searchBeneficiary without an explicit '
              'navigationMode defaults to push and stacks a duplicate: '
              '${jsonEncode(action)}',
        );
      }
    });
  });

  group('COMPLAINTS.json', () {
    late Map<String, dynamic> config;

    setUpAll(() => config = load('COMPLAINTS.json'));

    test('the complaint-detail Close button pops back to the inbox', () {
      final button = (flowNamed(config, 'complaintView')['footer'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['fieldName'] == 'close');
      final action =
          (button['onAction'] as List).cast<Map<String, dynamic>>().single;

      expect(action['actionType'], 'BACK_NAVIGATION');
      expect(action['properties']['name'], 'complaintInbox');
    });

    test(
        'nothing in the complaints flow navigates to complaintInbox with a '
        'plain push', () {
      for (final action in actionsTargeting(config, 'complaintInbox')) {
        if (action['actionType'] != 'NAVIGATION') continue;
        final mode = action['properties']['navigationMode'];
        expect(
          mode,
          isNotNull,
          reason: 'A NAVIGATION to complaintInbox without an explicit '
              'navigationMode defaults to push and stacks a duplicate: '
              '${jsonEncode(action)}',
        );
      }
    });

    test('the supervisor contact number requires exactly 11 digits', () {
      List<dynamic>? validations;
      void walk(dynamic n) {
        if (n is Map) {
          if (n['fieldName'] == 'supervisorContactNumber') {
            validations = n['validations'] as List<dynamic>?;
          }
          n.values.forEach(walk);
        } else if (n is List) {
          n.forEach(walk);
        }
      }

      walk(config);

      expect(validations, isNotNull);
      final byType = {
        for (final v in validations!) (v as Map)['type']: v['value'],
      };
      // Previously minLength was 10, so a 10-digit supervisor number passed
      // while the complainant's own number already required 11.
      expect(byType['minLength'], 11);
      expect(byType['maxLength'], 11);
    });
  });
}
