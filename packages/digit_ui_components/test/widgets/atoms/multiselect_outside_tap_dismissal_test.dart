import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the on-device panel "resurrection" (Maestro runs
/// 2026-09-02-1654/-1710): after an outside tap dismissed the panel, it came
/// back and swallowed the Submit tap (selecting a second boundary).
/// Mechanism: the overlay lifecycle is driven by focus
/// (`_handleFocusChange` re-inserts the overlay whenever the field's
/// AlwaysFocusableFocusNode regains focus), and on a real device Android's
/// window/IME focus churn can hand focus straight back after
/// `_onOutSideTap`'s unfocus. Widget tests have no such churn, so the churn
/// is SIMULATED here by re-requesting focus programmatically.
///
/// Invariant under test: an explicit outside-tap dismissal is FINAL until the
/// user taps the field again - focus re-grants must not reopen the panel.
void main() {
  /// Mirrors the boundary screen: options/initialOptions are rebuilt as NEW
  /// list instances on every parent rebuild (bloc-driven), and selection
  /// triggers a parent rebuild.
  Widget harness({required void Function(FocusNode node) onFocusNode}) {
    final selected = <String>{};
    return MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          const all = ['Atosi', 'Amulekangbo', 'Yelwa'];
          return Scaffold(
            body: Builder(builder: (context) {
              final node = Focus.maybeOf(context);
              return MultiSelectDropDown<int>(
                onOptionSelected: (selectedOptions) {
                  setState(() {
                    selected
                      ..clear()
                      ..addAll(selectedOptions.map((e) => e.code));
                  });
                },
                options: all
                    .map((e) => DropdownItem(name: e, code: e))
                    .toList(),
                initialOptions: all
                    .where(selected.contains)
                    .map((e) => DropdownItem(name: e, code: e))
                    .toList(),
              );
            }),
          );
        },
      ),
    );
  }

  testWidgets(
      'outside-tap dismissal is final: focus re-grant must not reopen the panel',
      (WidgetTester tester) async {
    await tester.pumpWidget(harness(onFocusNode: (_) {}));

    // Open the panel by tapping the field (device gesture).
    await tester.tap(find.byType(MultiSelectDropDown<int>));
    await tester.pump();
    expect(find.byType(ListView), findsOneWidget);

    // Select an option -> parent rebuilds with fresh list instances (bloc
    // behavior on the boundary screen); the panel stays open.
    await tester.tap(find.text('Atosi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(ListView), findsOneWidget);

    // Outside tap near the top of the screen (Maestro taps 50%,7%).
    await tester.tapAt(const Offset(400, 40));
    await tester.pump();
    expect(find.byType(ListView), findsNothing,
        reason: 'outside tap must close the panel');

    // Simulate Android focus churn: the field FocusNode regains focus.
    final focusNode = tester
        .widgetList<Focus>(find.descendant(
            of: find.byType(MultiSelectDropDown<int>),
            matching: find.byType(Focus)))
        .map((f) => f.focusNode)
        .whereType<FocusNode>()
        .first;
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ListView), findsNothing,
        reason: 'panel must NOT resurrect on a focus re-grant after an '
            'explicit outside-tap dismissal (device bug, runs -1654/-1710)');

    // A REAL field tap after dismissal must still open the panel again.
    // (Tap the suffix arrow: after selection the widget grew a chips row, so
    // the widget's center no longer lies on the field's InkWell.)
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pump();
    expect(find.byType(ListView), findsOneWidget,
        reason: 'field tap must reopen the panel after a dismissal');

    // Close again before teardown - disposing the tree with the panel open
    // trips the package's own dispose bug (_overlayState?.dispose()).
    await tester.tapAt(const Offset(400, 40));
    await tester.pump();
    expect(find.byType(ListView), findsNothing);

    // Teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });
}
