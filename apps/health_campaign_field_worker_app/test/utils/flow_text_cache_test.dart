import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/flow_text_cache.dart';

/// Liberia QA: Close Household showed raw keys on the first entry and the
/// texts after going back and opening it again. The texts were in the local
/// database; the copy the flows translate from did not have them yet.
/// flowTextsAreStale is the check a Home tile makes before it opens a flow.
void main() {
  String Function(String) translateFrom(Map<String, String> copy) =>
      (code) => copy[code] ?? code;

  const stored = [
    MapEntry('CLOSE_HOUSEHOLD_HEADING', 'Close household'),
    MapEntry('CLOSE_HOUSEHOLD_REASON', 'Reason'),
  ];

  test('the copy holds every stored text: not stale', () {
    expect(
      flowTextsAreStale(
        stored: stored,
        translate: translateFrom({
          'CLOSE_HOUSEHOLD_HEADING': 'Close household',
          'CLOSE_HOUSEHOLD_REASON': 'Reason',
          'OTHER': 'Other',
        }),
      ),
      isFalse,
    );
  });

  test('the copy holds none of the stored texts: stale', () {
    expect(
      flowTextsAreStale(stored: stored, translate: translateFrom(const {})),
      isTrue,
    );
  });

  test('one stored text is missing from the copy: stale', () {
    expect(
      flowTextsAreStale(
        stored: stored,
        translate: translateFrom({'CLOSE_HOUSEHOLD_HEADING': 'Close household'}),
      ),
      isTrue,
    );
  });

  test('a code two modules define with other wording is not stale', () {
    // The copy keeps one message per code; which module wins is not this
    // check's business.
    expect(
      flowTextsAreStale(
        stored: stored,
        translate: translateFrom({
          'CLOSE_HOUSEHOLD_HEADING': 'Closed household',
          'CLOSE_HOUSEHOLD_REASON': 'Why',
        }),
      ),
      isFalse,
    );
  });

  test('blank messages and messages equal to their code are ignored', () {
    // Neither can be told apart from a missing text, and a refresh would not
    // change what the screen shows for them.
    expect(
      flowTextsAreStale(
        stored: const [
          MapEntry('BLANK', ''),
          MapEntry('SPACE', '  '),
          MapEntry('SAME', 'SAME'),
        ],
        translate: translateFrom(const {}),
      ),
      isFalse,
    );
  });

  test('nothing stored: not stale', () {
    expect(
      flowTextsAreStale(stored: const [], translate: translateFrom(const {})),
      isFalse,
    );
  });

  test('source check: a Home tile runs the check before it opens a flow', () {
    // Only the wiring is checked here; the Home page is not mounted.
    final home = File('lib/pages/home.dart').readAsStringSync();
    final start = home.indexOf('Future<void> triggerLocalization(');
    expect(start, isNonNegative);
    final method = home.substring(start);
    expect(method, contains('flowTextsAreStale('));
    expect(
        method,
        matches(RegExp(
            r'if \(!_flowTextRefreshDidNotHelp\.contains\(module\) && stale\(\)\) \{'
            r'\s*await localizationBloc\.refreshFlowBuilderLocalization\(')),
        reason: 'stale texts are refreshed before the tile navigates');
  });
}
