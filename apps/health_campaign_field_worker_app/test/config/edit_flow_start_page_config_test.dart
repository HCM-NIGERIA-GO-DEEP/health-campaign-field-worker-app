import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards which page the HOUSEHOLD form opens on when a household is tapped
/// from the search results.
///
/// The HOUSEHOLD form has three pages - beneficiaryLocation (order 1),
/// caregiverConsent (order 2) and householdDetails (order 4) - and without a
/// `startPage` navigation param ScreenBuilder opens the first one
/// (screen_builder.dart: `schemaObject.pages.entries.first.key`). That meant
/// simply editing a registered household's member count or ID made the user
/// walk back through Location and Consent first.
///
/// The two cases must behave differently, which is why the search-result
/// branch is split on fn:isHouseholdMarkedClosed:
///   * an ordinary registered household is only being EDITED, so it jumps
///     straight to householdDetails - the one page with editable fields;
///   * a household whose latest task is still CLOSED_HOUSEHOLD is being
///     REOPENED, so it must still walk Location and Consent - skipping
///     caregiverConsent would make it impossible to flip
///     consentToParticipate from No to Yes, stranding the household as
///     permanently declined.
void main() {
  late Map<String, dynamic> config;

  setUpAll(() {
    config = jsonDecode(
      File('assets/configs/json/REGISTRATION.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  /// Every NAVIGATION into the HOUSEHOLD form carrying isEdit=true, paired
  /// with the condition expression of the branch it sits in.
  List<({String condition, String? startPage})> editNavigations() {
    final found = <({String condition, String? startPage})>[];

    void walk(dynamic node, String condition) {
      if (node is Map) {
        var current = condition;
        final cond = node['condition'];
        if (cond is Map && cond['expression'] is String) {
          current = cond['expression'] as String;
        }

        if (node['actionType'] == 'NAVIGATION') {
          final props = node['properties'];
          if (props is Map &&
              props['name'] == 'HOUSEHOLD' &&
              props['type'].toString().toUpperCase() == 'FORM') {
            final data = {
              for (final d in (props['data'] as List? ?? []))
                (d as Map)['key']: d['value'],
            };
            if (data['isEdit'] == 'true') {
              found.add((
                condition: current,
                startPage: data['startPage'] as String?,
              ));
            }
          }
        }
        for (final v in node.values) {
          walk(v, current);
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v, condition);
        }
      }
    }

    walk(config['flows'], '');
    return found;
  }

  test('householdDetails is a real page of the HOUSEHOLD form', () {
    // startPage is ignored unless it names an existing page, so a typo here
    // would silently fall back to beneficiaryLocation.
    final household = (config['flows'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['name'] == 'HOUSEHOLD');
    final pages = (household['pages'] as List)
        .cast<Map<String, dynamic>>()
        .map((p) => p['page'])
        .toList();

    expect(pages, contains('householdDetails'));
    expect(pages, contains('caregiverConsent'));
    expect(pages, contains('beneficiaryLocation'));
  });

  test('editing a normal registered household opens on householdDetails', () {
    final editBranch = editNavigations().where(
      (n) => n.condition.contains('isHouseholdMarkedClosed(item.tasks)}} == false'),
    );

    expect(editBranch, hasLength(1));
    expect(editBranch.single.startPage, 'householdDetails');
  });

  test(
      'reopening a still-closed household keeps the full flow so consent can '
      'be changed', () {
    final reopenBranch = editNavigations().where(
      (n) => n.condition.contains('isHouseholdMarkedClosed(item.tasks)}} == true'),
    );

    expect(reopenBranch, hasLength(1));
    expect(
      reopenBranch.single.startPage,
      isNull,
      reason: 'A reopened household must still see caregiverConsent, '
          'otherwise consentToParticipate can never be flipped to Yes.',
    );
  });

  test('every isEdit navigation is explicitly branched on closed-status', () {
    // Guards against a future edit entry point silently inheriting whichever
    // behaviour happens to come first.
    for (final nav in editNavigations()) {
      expect(
        nav.condition,
        contains('isHouseholdMarkedClosed'),
        reason: 'An isEdit navigation without a closed-status branch would '
            'apply one case\'s page flow to both.',
      );
    }
  });
}
