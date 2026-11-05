import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// transformJson normalises a flow config into the shape the forms engine
/// consumes. Its per-page map is an explicit ALLOW-LIST: any page key not
/// named in it is dropped.
///
/// That makes the failure mode silent and expensive. secondaryActionVisibility
/// was declared on stockReceiptDetails to hide "Partially Accept" on a plain
/// return, PropertySchema parsed the field correctly, and forms_render honoured
/// it - but the key never survived normalisation, so the gate simply did not
/// exist at runtime and the button stayed visible. Nothing errored; the result
/// was a valid schema that was merely missing a condition.
///
/// These tests pin the keys whose loss is invisible rather than loud - a page
/// that renders fine but silently drops a guard.
void main() {
  Map<String, dynamic> configWith(Map<String, dynamic> pageExtras) => {
        'name': 'TEST',
        'version': 1,
        'pages': [
          {
            'page': 'somePage',
            'type': 'object',
            'order': 1,
            'properties': <dynamic>[],
            ...pageExtras,
          },
        ],
      };

  Map<String, dynamic> pageFrom(Map<String, dynamic> config) =>
      (transformJson(config)['pages'] as Map<String, dynamic>)['somePage']
          as Map<String, dynamic>;

  test('carries secondaryActionVisibility through normalisation', () {
    const gate = {
      'expression': [
        {'condition': "navigation.incomingStockEntryType != 'RETURNED'"},
        {'condition': "navigation.discrepancyReason != ''"},
      ],
    };

    final page = pageFrom(configWith({
      'secondaryActionLabel': 'INVENTORY_PARTIALLY_ACCEPT_STOCK_LABEL',
      'secondaryActionVisibility': gate,
    }));

    expect(page['secondaryActionVisibility'], gate,
        reason: 'the gate was dropped, so the secondary action will render '
            'unconditionally - exactly the Partially Accept regression');
  });

  test('a visibility gate never outlives its label', () {
    // The pair is only meaningful together: a label with no gate is an
    // always-visible button. If someone prunes this allow-list again, these
    // two must go or stay as one.
    final page = pageFrom(configWith({
      'secondaryActionLabel': 'SOME_LABEL',
      'secondaryActionVisibility': {
        'expression': [
          {'condition': 'a == b'}
        ]
      },
    }));

    expect(page.containsKey('secondaryActionLabel'), isTrue);
    expect(page.containsKey('secondaryActionVisibility'), isTrue);
  });

  test('every silently-droppable guard key survives', () {
    // Keys where absence degrades to "no restriction" rather than to a
    // visible error. Losing any of these weakens a guard without failing.
    const guards = {
      'visibilityCondition': {
        'expression': [
          {'condition': 'x == 1'}
        ]
      },
      'secondaryActionVisibility': {
        'expression': [
          {'condition': 'y == 2'}
        ]
      },
      'submitCondition': {
        'expression': [
          {'condition': 'z == 3'}
        ]
      },
      'preventScreenCapture': true,
      'readOnly': true,
      'validations': [
        {'type': 'required', 'value': true}
      ],
    };

    final page = pageFrom(configWith(Map<String, dynamic>.from(guards)));

    for (final entry in guards.entries) {
      expect(page[entry.key], entry.value,
          reason: '${entry.key} did not survive transformJson - its guard '
              'silently stops applying');
    }
  });

  test('absent keys stay absent rather than becoming a default', () {
    // A page that declares no gate must not acquire one, or the opposite bug
    // appears: a button hidden when it should show.
    final page = pageFrom(configWith({'secondaryActionLabel': 'SOME_LABEL'}));

    expect(page['secondaryActionVisibility'], isNull);
  });
}
