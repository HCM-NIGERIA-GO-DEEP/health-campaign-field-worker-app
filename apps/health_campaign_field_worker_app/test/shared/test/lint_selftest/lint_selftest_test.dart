// Self-tests for the lint engine: every invariant is proven to FIRE on a
// bad fixture and stay QUIET on a good one. This mechanizes the kit rule
// "a test enters the kit only after it's proven able to fail" — the proof
// runs on every kit execution, on every branch, with no real configs needed.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../lint/config_lint_engine.dart';

ConfigSet _set(String json, {String path = 'fixture.json'}) =>
    ConfigSet([ConfigDoc(path, jsonDecode(json))], const []);

const _goodFlow = '''
{
  "flows": [
    {
      "name": "deliverySummary",
      "screenType": "FORM",
      "body": [
        {
          "label": "Deliver",
          "actions": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "configName": "ineligibleConfig",
                "data": [
                  {"key": "beneficiaryId", "value": "{{navigation.id}}"},
                  {
                    "key": "cycleIndex",
                    "value": "{{fn:getCurrentCycleIndex()}}"
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  ]
}
''';

const _transformerSource = '''
final jsonConfig = {
  "ineligibleConfig": {
    "additionalFields": {
      "cycleIndex": "__context:cycleIndex"
    }
  },
  "otherConfig": {
    "value": "__context:somethingElse"
  }
};
''';

void main() {
  group('lintCycleIndexStamp', () {
    test('fires when cycleIndex is missing', () {
      const bad = '''
      {"flows": [{"name": "p", "screenType": "FORM", "body": [{"actions": [
        {"actionType": "FETCH_TRANSFORMER_CONFIG", "properties": {
          "configName": "ineligibleConfig",
          "data": [{"key": "beneficiaryId", "value": "{{navigation.id}}"}]
        }}]}]}]}
      ''';
      expect(
        lintCycleIndexStamp(_set(bad)),
        [contains('does not stamp cycleIndex')],
      );
    });

    test('fires when cycleIndex comes from contextData.*', () {
      const bad = '''
      {"flows": [{"name": "p", "screenType": "FORM", "body": [{"actions": [
        {"actionType": "FETCH_TRANSFORMER_CONFIG", "properties": {
          "configName": "ineligibleConfig",
          "data": [{"key": "cycleIndex", "value": "{{contextData.cycleIndex}}"}]
        }}]}]}]}
      ''';
      expect(
        lintCycleIndexStamp(_set(bad)),
        [contains('contextData.*')],
      );
    });

    test('fires on a parse error', () {
      final set = ConfigSet(const [], ['x.json: not valid JSON (boom)']);
      expect(lintCycleIndexStamp(set), [contains('not valid JSON')]);
    });

    test('quiet on a properly stamped config', () {
      expect(lintCycleIndexStamp(_set(_goodFlow)), isEmpty);
    });
  });

  group('lintFormContextData', () {
    test('fires on contextData.* in FETCH data on a FORM screen', () {
      const bad = '''
      {"flows": [{"name": "form1", "screenType": "FORM", "body": [{"actions": [
        {"actionType": "FETCH_TRANSFORMER_CONFIG", "properties": {
          "configName": "orsDelivery",
          "data": [{"key": "cycleIndex", "value": "{{contextData.cycleIndex}}"}]
        }}]}]}]}
      ''';
      final violations = lintFormContextData(_set(bad));
      expect(violations, hasLength(1));
      expect(violations.single, contains('form1'));
      expect(violations.single, contains('cycleIndex'));
    });

    test('quiet for the same block on a TEMPLATE screen', () {
      const okOnTemplate = '''
      {"flows": [{"name": "t1", "screenType": "TEMPLATE", "body": [{"actions": [
        {"actionType": "FETCH_TRANSFORMER_CONFIG", "properties": {
          "configName": "orsDelivery",
          "data": [{"key": "cycleIndex", "value": "{{contextData.cycleIndex}}"}]
        }}]}]}]}
      ''';
      expect(lintFormContextData(_set(okOnTemplate)), isEmpty);
    });

    test('quiet on navigation.* and fn: values on FORM screens', () {
      expect(lintFormContextData(_set(_goodFlow)), isEmpty);
    });
  });

  group('lintTransformerMapping', () {
    test('fires when configName does not exist in the transformer', () {
      const bad = '''
      {"flows": [{"body": [{"actions": [
        {"actionType": "FETCH_TRANSFORMER_CONFIG", "properties": {
          "configName": "typoConfig", "data": []
        }}]}]}]}
      ''';
      expect(
        lintTransformerMapping(_set(bad), _transformerSource),
        [contains('typoConfig')],
      );
    });

    test('fires when a critical key has no __context mapping', () {
      const bad = '''
      {"flows": [{"body": [{"actions": [
        {"actionType": "FETCH_TRANSFORMER_CONFIG", "properties": {
          "configName": "otherConfig",
          "data": [{"key": "cycleIndex", "value": "{{fn:getCurrentCycleIndex()}}"}]
        }}]}]}]}
      ''';
      final violations = lintTransformerMapping(_set(bad), _transformerSource);
      expect(violations, hasLength(1));
      expect(violations.single, contains('three-link'));
    });

    test('quiet when the section maps the critical key', () {
      expect(
        lintTransformerMapping(_set(_goodFlow), _transformerSource),
        isEmpty,
      );
    });
  });

  group('lintUnregisteredFns', () {
    test('fires once per unknown fn', () {
      const bad = '''
      {"flows": [
        {"label": "{{fn:ghostFn(a)}}"},
        {"label": "{{fn:ghostFn(b)}}", "visible": "{{fn:realFn()}}"}
      ]}
      ''';
      final violations = lintUnregisteredFns(_set(bad), {'realFn'});
      expect(violations, hasLength(1));
      expect(violations.single, contains('fn:ghostFn'));
    });

    test('quiet when every fn is registered', () {
      expect(
        lintUnregisteredFns(_set(_goodFlow), {'getCurrentCycleIndex'}),
        isEmpty,
      );
    });
  });

  group('lintWhitespaceOnlyText', () {
    test('fires on a single-space label', () {
      const bad = '{"flows": [{"label": " ", "name": "x"}]}';
      expect(
        lintWhitespaceOnlyText(_set(bad)),
        [contains('whitespace-only')],
      );
    });

    test('quiet on empty strings and real text', () {
      const ok = '{"flows": [{"label": "", "title": "Deliver", "name": "x"}]}';
      expect(lintWhitespaceOnlyText(_set(ok)), isEmpty);
    });
  });

  group('lintBlankLocalization', () {
    test('fires on empty and single-space messages, quiet on real ones', () {
      const dump = '''
      [
        {"code": "A_KEY", "message": " ", "module": "hcm-x-CMP-1"},
        {"code": "B_KEY", "message": "", "module": "hcm-x-CMP-1"},
        {"code": "C_KEY", "message": "Fine", "module": "hcm-x-CMP-1"}
      ]
      ''';
      final violations = lintBlankLocalization(_set(dump));
      expect(violations, hasLength(2));
      expect(violations[0], contains('A_KEY'));
      expect(violations[1], contains('B_KEY'));
    });

    test('detects dumps wrapped in a messages envelope', () {
      const dump = '{"messages": [{"code": "K", "message": "ok"}]}';
      expect(hasLocalizationDocs(_set(dump)), isTrue);
      expect(lintBlankLocalization(_set(dump)), isEmpty);
    });

    test('flow configs are not mistaken for localization dumps', () {
      expect(hasLocalizationDocs(_set(_goodFlow)), isFalse);
    });
  });

  group('lintNavigationTargets', () {
    const twoScreens = '''
      {"initialPage": "a", "flows": [
        {"name": "a", "screenType": "TEMPLATE", "body": [{"actions": [
          {"actionType": "NAVIGATION",
           "properties": {"name": "b", "navigationMode": "popUntilAndPush",
                          "popUntilPageName": "a"}}]}]},
        {"name": "b", "screenType": "FORM"}
      ]}
      ''';

    test('fires on a target that is no screen anywhere', () {
      const bad = '''
      {"flows": [
        {"name": "a", "screenType": "TEMPLATE", "body": [{"actions": [
          {"actionType": "NAVIGATION", "properties": {"name": "ghostScreen"}}
        ]}]}
      ]}
      ''';
      final violations = lintNavigationTargets(_set(bad));
      expect(violations, hasLength(1));
      expect(violations.single, contains('ghostScreen'));
      expect(violations.single, contains('screen "a"'));
    });

    test('fires on a bad popUntilPageName too', () {
      const bad = '''
      {"flows": [
        {"name": "a", "screenType": "TEMPLATE", "body": [{"actions": [
          {"actionType": "NAVIGATION",
           "properties": {"name": "a", "popUntilPageName": "ghost"}}
        ]}]}
      ]}
      ''';
      expect(lintNavigationTargets(_set(bad)), [contains('ghost')]);
    });

    test('quiet on same-config, cross-config, HOME, templated and allowed '
        'targets', () {
      expect(lintNavigationTargets(_set(twoScreens)), isEmpty);
      const cross = '''
      {"flows": [{"name": "c", "body": [{"actions": [
        {"actionType": "NAVIGATION", "properties": {"name": "HOME"}},
        {"actionType": "NAVIGATION", "properties": {"name": "{{fn:pick()}}"}},
        {"actionType": "NAVIGATION", "properties": {"name": "external"}}
      ]}]}]}
      ''';
      expect(
        lintNavigationTargets(_set(cross), allow: {'external'}),
        isEmpty,
      );
    });
  });

  group('lintPushOverSelf', () {
    String nav(String name, String mode, String popUntil) => '''
      {"flows": [{"name": "$name", "body": [{"actions": [
        {"actionType": "NAVIGATION", "properties": {
          "name": "$name", "navigationMode": "$mode",
          "popUntilPageName": "$popUntil"}}]}]}]}
      ''';

    test('fires when popUntilAndPush pushes the screen it pops until', () {
      final violations =
          lintPushOverSelf(_set(nav('overview', 'popUntilAndPush', 'overview')));
      expect(violations, hasLength(1));
      expect(violations.single, contains('stale screen'));
    });

    test('fires on the underscore mode spelling too', () {
      expect(
        lintPushOverSelf(_set(nav('overview', 'pop_until_and_push', 'overview'))),
        hasLength(1),
      );
    });

    test('quiet when popping until a different screen', () {
      expect(
        lintPushOverSelf(_set(nav('overview', 'popUntilAndPush', 'search'))),
        isEmpty,
      );
    });

    test('quiet in plain popUntil mode, where name == popUntil is normal', () {
      expect(
        lintPushOverSelf(_set(nav('search', 'popUntil', 'search'))),
        isEmpty,
      );
    });

    test('quiet on allowlisted screens', () {
      expect(
        lintPushOverSelf(
          _set(nav('search', 'popUntilAndPush', 'search')),
          allow: {'search'},
        ),
        isEmpty,
      );
    });
  });

  group('lintUnknownActionTypes', () {
    test('fires on an unhandled type and on expression-typed actions', () {
      const bad = '''
      {"flows": [{"body": [
        {"actionType": "SHOW_TOAST"},
        {"actionType": "field.value==true ? SEARCH_EVENT : CLEAR_STATE"}
      ]}]}
      ''';
      final violations = lintUnknownActionTypes(_set(bad), {'SHOW_TOAST'});
      expect(violations, hasLength(1));
      expect(violations.single, contains('silently no-ops'));
    });

    test('quiet on known types', () {
      const ok = '{"flows": [{"body": [{"actionType": "SHOW_TOAST"}]}]}';
      expect(lintUnknownActionTypes(_set(ok), {'SHOW_TOAST'}), isEmpty);
    });
  });

  group('lintOrphanScreens', () {
    test('fires on a screen no string anywhere references', () {
      const bad = '''
      {"initialPage": "a", "flows": [
        {"name": "a", "body": [{"actions": [
          {"actionType": "NAVIGATION", "properties": {"name": "b"}}]}]},
        {"name": "b"},
        {"name": "deadScreen"}
      ]}
      ''';
      final violations = lintOrphanScreens(_set(bad));
      expect(violations, hasLength(1));
      expect(violations.single, contains('deadScreen'));
    });

    test('initialPages, referenced and allowlisted screens are not orphans',
        () {
      const ok = '''
      {"initialPage": "a", "flows": [
        {"name": "a", "body": [{"actions": [
          {"actionType": "NAVIGATION", "properties": {"name": "b"}}]}]},
        {"name": "b"},
        {"name": "appEntered"}
      ]}
      ''';
      expect(lintOrphanScreens(_set(ok), allow: {'appEntered'}), isEmpty);
    });
  });

  group('collectKnownActionTypes extraction patterns', () {
    test('catches canHandle bodies, registry calls and inline comparisons',
        () {
      // Mirrors the three real registration styles found in the repo.
      expect(
        RegExp(r"actionType[^\n]{0,24}'([A-Z][A-Z_]{2,})'")
            .firstMatch("bool canHandle(String actionType) => actionType == 'SHOW_TOAST';")!
            .group(1),
        'SHOW_TOAST',
      );
      expect(
        RegExp(r"actionType[^\n]{0,24}'([A-Z][A-Z_]{2,})'")
            .firstMatch("if (a['actionType'] == 'REQUEST_PERMISSION') {")!
            .group(1),
        'REQUEST_PERMISSION',
      );
      expect(
        RegExp(r"register\(\s*'([A-Z][A-Z_]{2,})'")
            .firstMatch("register('CLOSE_POPUP', ClosePopupExecutor());")!
            .group(1),
        'CLOSE_POPUP',
      );
    });
  });

  group('transformerSections', () {
    test('splits top-level named sections and keeps their bodies separate',
        () {
      final sections = transformerSections(_transformerSource);
      expect(sections.keys, containsAll(['ineligibleConfig', 'otherConfig']));
      expect(sections['ineligibleConfig'], contains('__context:cycleIndex'));
      expect(
        sections['otherConfig'],
        isNot(contains('__context:cycleIndex')),
      );
    });
  });
}
