import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural lint for the Search Households screen's searchBeneficiary
/// widgets in REGISTRATION.json: Name, an explicit Beneficiary ID toggle,
/// a National ID toggle covering any of National ID/Voter ID/Passport/
/// Driver's License, and Phone Number.
///
/// This does not exercise digit_flow_builder's runtime - it only guards the
/// invariants that runtime depends on but does not itself validate, so a
/// future config edit that silently breaks one of them fails CI immediately
/// instead of failing silently on-device:
///   - search_bar_widget.dart injects the typed value into data[0] only, so
///     identifierId/mobileNumber MUST be at index 0 in every search bar's
///     "data" array (see search_bar_widget.dart's `_processAction`).
///   - all switches must clear identifierType (and mobileNumber) so
///     switching ID-search modes never leaks a stale type/number filter into
///     the next search.
///   - switch_widget.dart writes `true` to its own fieldName BEFORE firing
///     onAction; if a toggle's own CLEAR_STATE widgetKeys listed its own
///     fieldName, it would immediately erase the value it just set.
void main() {
  late Map<String, dynamic> config;
  late List<dynamic> searchBody;

  setUpAll(() {
    final file = File(
      '${Directory.current.path}/assets/configs/json/REGISTRATION.json',
    );
    config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final pages = (config['flows'] as List).cast<Map<String, dynamic>>();
    final searchScreen = pages.firstWhere(
      (p) => (p['body'] as List?)?.any(
            (w) => w is Map && w['fieldName'] == 'searchBar',
          ) ==
          true,
      orElse: () => throw StateError(
        'Could not find the searchBeneficiary body containing "searchBar" in REGISTRATION.json',
      ),
    );
    searchBody = searchScreen['body'] as List<dynamic>;
  });

  Map<String, dynamic> widgetNamed(String fieldName) {
    return searchBody.cast<Map<String, dynamic>>().firstWhere(
          (w) => w['fieldName'] == fieldName,
          orElse: () => throw StateError('No widget with fieldName "$fieldName" found'),
        );
  }

  List<Map<String, dynamic>> onActionDataFor(Map<String, dynamic> bar) {
    final onAction = bar['onAction'] as List;
    final firstBranch = onAction.first as Map<String, dynamic>;
    final action = (firstBranch['actions'] as List).first as Map<String, dynamic>;
    return (action['properties']['data'] as List).cast<Map<String, dynamic>>();
  }

  group('search bars', () {
    const idBars = ['idSearchBar', 'nationalIdSearchBar'];

    for (final fieldName in idBars) {
      test('$fieldName has identifierId at data[0] (search_bar_widget.dart only injects into index 0)', () {
        final bar = widgetNamed(fieldName);
        final data = onActionDataFor(bar);

        expect(data, isNotEmpty);
        expect(data.first['key'], 'identifierId');
      });
    }

    test('phoneNumberSearchBar has mobileNumber at data[0]', () {
      final bar = widgetNamed('phoneNumberSearchBar');
      final data = onActionDataFor(bar);

      expect(data.first['key'], 'mobileNumber');
    });

    test('idSearchBar (Beneficiary ID) is scoped to identifierType=UNIQUE_BENEFICIARY_ID', () {
      final data = onActionDataFor(widgetNamed('idSearchBar'));
      final typeFilter = data.firstWhere((d) => d['key'] == 'identifierType');

      expect(typeFilter['value'], 'UNIQUE_BENEFICIARY_ID');
      expect(typeFilter['operation'], 'equals');
    });

    test('nationalIdSearchBar matches any of National ID/Voter ID/Passport/Driver\'s License', () {
      final bar = widgetNamed('nationalIdSearchBar');
      final data = onActionDataFor(bar);
      final idFilter = data.firstWhere((d) => d['key'] == 'identifierId');
      final typeFilter = data.firstWhere((d) => d['key'] == 'identifierType');

      // "in" lets any of the 4 ID types match the same box, while the ID
      // value itself must match exactly to avoid returning partial matches.
      expect(idFilter['operation'], 'equals');
      expect(typeFilter['operation'], 'in');
      expect(
        typeFilter['value'],
        containsAll(['NATIONAL_ID', 'VOTER_ID', 'PASSPORT', 'DRIVERS_LICENSE']),
      );
      // Low enough that short test IDs (e.g. 6 chars) still fire a search -
      // a minSearchChars mismatched to real ID lengths silently no-ops the
      // whole search bar.
      expect(bar['minSearchChars'], lessThanOrEqualTo(3));
    });

    test('phoneNumberSearchBar requires 8 digits and roots on individual', () {
      final bar = widgetNamed('phoneNumberSearchBar');
      final data = onActionDataFor(bar);

      expect(bar['minSearchChars'], 8);
      expect(data.first['root'], 'individual');
    });

    test('searchBar (Name) matches both first and last name, not just a givenName prefix', () {
      final data = onActionDataFor(widgetNamed('searchBar'));
      final nameFilter = data.first;

      // A single-column "contains" on givenName only ever does a prefix
      // match (col LIKE 'value%'), so typing "John Smith" against a
      // givenName column that only holds "John" never matches once the
      // family name is typed. "containsAll" on the combined
      // "givenName,familyName" key requires each whitespace-separated
      // token to match either column, so first-name-only and
      // first-plus-last-name both find the household.
      expect(nameFilter['key'], 'givenName,familyName');
      expect(nameFilter['operation'], 'containsAll');
    });
  });

  group('toggles', () {
    const toggles = [
      'nameSearch',
      'beneficiaryIdSearch',
      'nationalIdSearch',
      'phoneNumberSearch',
    ];

    for (final fieldName in toggles) {
      test('$fieldName toggle never lists its own fieldName in its CLEAR_STATE widgetKeys', () {
        final toggle = widgetNamed(fieldName);
        final action = (toggle['onAction'] as List).first as Map<String, dynamic>;
        final widgetKeys =
            (action['properties']['widgetKeys'] as List).cast<String>();

        expect(
          widgetKeys,
          isNot(contains(fieldName)),
          reason:
              'SwitchWidget writes `true` to its own fieldName before firing '
              'onAction - listing it in widgetKeys would immediately clear '
              'the value the user just set.',
        );
      });

      test('$fieldName toggle clears identifierType, mobileNumber and the combined name filterKeys', () {
        final toggle = widgetNamed(fieldName);
        final action = (toggle['onAction'] as List).first as Map<String, dynamic>;
        final filterKeys =
            (action['properties']['filterKeys'] as List).cast<String>();

        expect(
          filterKeys,
          containsAll(['givenName,familyName', 'identifierId', 'identifierType', 'mobileNumber']),
        );
      });

      test('$fieldName toggle clears every search bar widgetKey', () {
        final toggle = widgetNamed(fieldName);
        final action = (toggle['onAction'] as List).first as Map<String, dynamic>;
        final widgetKeys =
            (action['properties']['widgetKeys'] as List).cast<String>();

        expect(
          widgetKeys,
          containsAll([
            'searchBar',
            'idSearchBar',
            'nationalIdSearchBar',
            'phoneNumberSearchBar',
          ]),
        );
      });
    }

    test('exactly one toggle is active for each of the other 3 (mutual exclusivity wiring)', () {
      for (final fieldName in toggles) {
        final toggle = widgetNamed(fieldName);
        final action = (toggle['onAction'] as List).first as Map<String, dynamic>;
        final widgetKeys =
            (action['properties']['widgetKeys'] as List).cast<String>();
        final otherToggles = toggles.where((t) => t != fieldName);

        expect(
          widgetKeys,
          containsAll(otherToggles),
          reason: '$fieldName must force every other toggle off when activated',
        );
      }
    });
  });
}
