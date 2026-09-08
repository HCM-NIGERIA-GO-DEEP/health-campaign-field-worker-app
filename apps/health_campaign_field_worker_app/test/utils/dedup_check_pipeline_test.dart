import 'dart:convert';
import 'dart:io';

import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_ui_components/constants/icon_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bundled runtime config for the registration flow.
///
/// `assets/configs/` is gitignored and regenerated from the admin console, so
/// the file can legitimately be absent; the bundled-config group skips itself
/// rather than failing a fresh clone.
final _registrationConfig = File('assets/configs/json/REGISTRATION.json');

Map<String, dynamic> _flow(String name) {
  final config = json.decode(_registrationConfig.readAsStringSync())
      as Map<String, dynamic>;
  return (config['flows'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((f) => f['name'] == name);
}

PropertySchema _page(String flowName, String pageName) {
  final pages = transformJson(_flow(flowName))['pages'] as Map<String, dynamic>;
  return PropertySchema.fromJson(pages[pageName] as Map<String, dynamic>);
}

void main() {
  group('transformJson', () {
    test('carries dedupCheck through to the page schema', () {
      // transformJson rebuilds each page from an explicit key whitelist, so a
      // page-level key it does not list is dropped silently -- leaving the
      // check dormant while the config still looks correct.
      final transformed = transformJson({
        'name': 'HOUSEHOLD',
        'version': 1,
        'pages': [
          {
            'page': 'beneficiaryDetails',
            'type': 'object',
            'order': 1,
            'properties': [
              {'fieldName': 'nameOfIndividual', 'type': 'string'},
            ],
            'dedupCheck': {
              'model': 'individual',
              'fields': {'givenName': 'nameOfIndividual'},
            },
          }
        ],
      });

      final page = (transformed['pages'] as Map<String, dynamic>)[
          'beneficiaryDetails'] as Map<String, dynamic>;
      expect(page['dedupCheck'], isNotNull);

      final schema = PropertySchema.fromJson(page);
      expect(schema.dedupCheck, isNotNull);
      expect(schema.dedupCheck!.fields, {'givenName': 'nameOfIndividual'});
    });

    test('leaves dedupCheck null for a page without one', () {
      final transformed = transformJson({
        'name': 'HOUSEHOLD',
        'version': 1,
        'pages': [
          {
            'page': 'householdDetails',
            'type': 'object',
            'order': 1,
            'properties': [
              {'fieldName': 'memberCount', 'type': 'string'},
            ],
          }
        ],
      });

      final page = (transformed['pages'] as Map<String, dynamic>)[
          'householdDetails'] as Map<String, dynamic>;
      expect(PropertySchema.fromJson(page).dedupCheck, isNull);
    });
  });

  group('bundled REGISTRATION.json', () {
    setUp(() {
      if (!_registrationConfig.existsSync()) {
        markTestSkipped('assets/configs/json/REGISTRATION.json is not present');
      }
    });

    test('HOUSEHOLD beneficiaryDetails survives the full pipeline', () {
      if (!_registrationConfig.existsSync()) return;

      final schema = _page('HOUSEHOLD', 'beneficiaryDetails');
      final dedup = schema.dedupCheck;

      expect(dedup, isNotNull,
          reason: 'dedupCheck missing from HOUSEHOLD.beneficiaryDetails');
      expect(dedup!.model, 'individual');
      expect(dedup.effectiveMatchThreshold, 0.85);
      expect(dedup.effectiveMaxResults, 5);
      expect(dedup.skipOnEdit, isTrue);
      expect(dedup.backToSearchPage, 'searchBeneficiary');

      // An unfiltered corpus search is rejected by the search repository.
      expect(dedup.filters, isNotEmpty);
      expect(dedup.filters.first.root, 'address');
      expect(dedup.filters.first.key, 'localityBoundaryCode');

      // Every mapped field must exist on the page and be visible, or the
      // check quietly no-ops at runtime.
      final properties = schema.properties!;
      for (final mapped in dedup.fields.values) {
        expect(properties.keys, contains(mapped),
            reason: '\$mapped is not a field on beneficiaryDetails');
        expect(properties[mapped]!.hidden, isNot(isTrue),
            reason: '\$mapped is hidden, so the user never fills it');
      }
    });

    test('the back-to-search target is a flow in the config', () {
      if (!_registrationConfig.existsSync()) return;

      final target =
          _page('HOUSEHOLD', 'beneficiaryDetails').dedupCheck!.backToSearchPage;

      final config = json.decode(_registrationConfig.readAsStringSync())
          as Map<String, dynamic>;
      final names = (config['flows'] as List)
          .cast<Map<String, dynamic>>()
          .map((f) => f['name'])
          .toSet();

      // NavigationRegistry resolves the target through FlowRegistry, which is
      // keyed by flow name.
      expect(names, contains(target));
    });

    test('ADD_MEMBER beneficiaryDetails opts out', () {
      if (!_registrationConfig.existsSync()) return;
      expect(_page('ADD_MEMBER', 'beneficiaryDetails').dedupCheck, isNull);
    });

    test('dedupAlertPopUp survives the full pipeline', () {
      if (!_registrationConfig.existsSync()) return;

      final alert = _page('HOUSEHOLD', 'beneficiaryDetails').dedupCheck!.dedupAlertPopUp;

      expect(alert, isNotNull,
          reason: 'dedupAlertPopUp missing, so the built-in dialog is used');
      expect(alert!.matchesKey, 'dedupMatches');
      expect(alert.body, isNotEmpty);
      // A duplicate warning has to be answered, not dismissed by accident.
      expect(alert.barrierDismissible, isFalse);
      expect(alert.showCloseButton, isFalse);
    });

    test('the body binds its listView to the published matches key', () {
      if (!_registrationConfig.existsSync()) return;

      final alert = _page('HOUSEHOLD', 'beneficiaryDetails').dedupCheck!.dedupAlertPopUp!;
      final root = alert.body.first as Map<String, dynamic>;

      expect(root['format'], 'listView');
      // A dataSource that does not match matchesKey renders nothing at all.
      expect(root['dataSource'], alert.matchesKey);
      expect(root['child'], isNotNull,
          reason: 'listView reads its row template from "child"');
    });

    test('every copy action names an icon the shared mapping knows', () {
      if (!_registrationConfig.existsSync()) return;

      final alert = _page('HOUSEHOLD', 'beneficiaryDetails').dedupCheck!.dedupAlertPopUp!;
      final copyButtons = <Map<String, dynamic>>[];

      void walk(dynamic node) {
        if (node is Map) {
          if (node['format'] == 'iconButton') {
            copyButtons.add(Map<String, dynamic>.from(node));
          }
          node.values.forEach(walk);
        } else if (node is List) {
          node.forEach(walk);
        }
      }

      walk(alert.body);
      expect(copyButtons, hasLength(2),
          reason: 'one copy button for the name, one for the ID');

      for (final button in copyButtons) {
        final iconName = button['iconData'] as String?;
        expect(iconName, isNotNull);
        // getIcon falls back to a question mark for an unknown name.
        expect(DigitIconMapping.iconMap.containsKey(iconName), isTrue,
            reason: '$iconName is not in DigitIconMapping');

        final actions = button['onAction'] as List;
        expect(actions, hasLength(1));
        final action = actions.single as Map<String, dynamic>;
        expect(action['actionType'], 'COPY_TO_CLIPBOARD');

        final props = action['properties'] as Map<String, dynamic>;
        // The executor resolves this itself; an unresolved template would
        // otherwise land on the clipboard verbatim.
        expect(props['value'], startsWith('{{item.'));
      }
    });
  });
}
