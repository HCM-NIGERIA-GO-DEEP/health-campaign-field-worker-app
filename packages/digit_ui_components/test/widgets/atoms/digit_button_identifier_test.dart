import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for `DigitButton.semanticsIdentifier` (local vendored
/// change): the identifier must ride INSIDE the button so callers that cast
/// the built widget to DigitButton (flow-builder popup footers) keep working —
/// wrapping the button in an outer Semantics crashed those casts at runtime
/// ("type 'Semantics' is not a subtype of type 'DigitButton'").
void main() {
  List<String> allIdentifiers(WidgetTester tester) {
    final ids = <String>[];
    void visit(SemanticsNode node) {
      final identifier = node.getSemanticsData().identifier;
      if (identifier.isNotEmpty) ids.add(identifier);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    final root =
        tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
    expect(root, isNotNull, reason: 'semantics must be enabled');
    visit(root!);
    return ids;
  }

  testWidgets('semanticsIdentifier surfaces in the semantics tree',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DigitButton(
            label: 'Skip & Continue',
            semanticsIdentifier: 'searchBeneficiary_clearFilter',
            onPressed: () {},
            type: DigitButtonType.secondary,
            size: DigitButtonSize.large,
          ),
        ),
      ),
    );

    expect(allIdentifiers(tester), contains('searchBeneficiary_clearFilter'));

    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('no semanticsIdentifier -> no identifier node (default intact)',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DigitButton(
            label: 'Plain',
            onPressed: () {},
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
        ),
      ),
    );

    expect(allIdentifiers(tester), isEmpty);

    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });

  /// Run -1339: the flow-builder `row` around a search-result card annotates
  /// itself with `Semantics(identifier: '..._detailsRow')`. Before
  /// `container: true`, the button's own annotation had no node and was
  /// absorbed by that row, so `.*_openMemberCard` did not exist in the tree at
  /// all — and the surviving row node spans BOTH the name and the button, so
  /// its centre lands in the gap between them and taps nothing.
  testWidgets('a button nested under an annotated row keeps its own id',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            identifier: 'searchBeneficiary_detailsRow',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('QATEST 0907-1339 HEAD QATEST'),
                DigitButton(
                  label: 'Open',
                  semanticsIdentifier: 'searchBeneficiary_openMemberCard',
                  onPressed: () => opened++,
                  type: DigitButtonType.secondary,
                  size: DigitButtonSize.medium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // THE regression: the row must not swallow the button's identifier.
    expect(
      allIdentifiers(tester),
      containsAll(
          ['searchBeneficiary_detailsRow', 'searchBeneficiary_openMemberCard']),
      reason: 'run -1339 found only the row id; the button id was absorbed',
    );

    Finder byId(String id) => find.byWidgetPredicate((w) =>
        w is Semantics && w.properties.identifier == id && w.properties.scopesRoute != true);

    final rowRect = tester.getRect(byId('searchBeneficiary_detailsRow'));
    final buttonRect = tester.getRect(byId('searchBeneficiary_openMemberCard'));

    // The row's centre is NOT on the button - that is why the row id cannot be
    // used as a tap target even though the merged node reports clickable.
    expect(buttonRect.contains(rowRect.center), isFalse);

    // ...while the button's own node centre does open the household.
    await tester.tapAt(buttonRect.center);
    await tester.pump();
    expect(opened, 1);

    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('identifier wrap does not swallow taps',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DigitButton(
            label: 'Tap me',
            semanticsIdentifier: 'tap_probe',
            onPressed: () => tapped++,
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
        ),
      ),
    );

    // Tap by widget type - DigitButton reformats its label text (capitalize/
    // sentence-case), so a raw text finder misses.
    await tester.tap(find.byType(DigitButton));
    await tester.pump();
    expect(tapped, 1);

    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });
}
