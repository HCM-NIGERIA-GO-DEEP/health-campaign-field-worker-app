import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the boundary-screen automation sequence that failed on device
/// (Maestro runs 2026-09-02-1601/-1654): non-searchable MultiSelectDropDown,
/// open -> select an option (panel stays open) -> tap the outside scrim.
/// The panel must close and STAY closed - on device the Submit tap 2s later
/// landed on an option row, selecting a second boundary instead of submitting.
void main() {
  testWidgets(
      'MultiSelectDropDown closes on outside tap after a selection and stays closed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiSelectDropDown<int>(
            onOptionSelected: (selectedOptions) {},
            options: const [
              DropdownItem(name: 'Atosi', code: 'c1'),
              DropdownItem(name: 'Amulekangbo', code: 'c2'),
              DropdownItem(name: 'Yelwa', code: 'c3'),
            ],
          ),
        ),
      ),
    );

    // Open the panel.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pump();
    expect(find.byType(ListView), findsOneWidget);

    // Select an option - the panel stays open (multiselect behavior).
    await tester.tap(find.text('Atosi'));
    await tester.pump();
    // Let the widget's 100ms _isInteractingWithDropdown reset elapse.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(ListView), findsOneWidget);

    // Tap the outside scrim (full-screen GestureDetector).
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();

    // Closed now...
    expect(find.byType(ListView), findsNothing,
        reason: 'outside tap must close the panel');

    // ...and still closed after focus events / delayed callbacks settle
    // (on device the panel was back ~2s later and ate the Submit tap).
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ListView), findsNothing,
        reason: 'panel must not resurrect after the outside tap (0.5s)');
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ListView), findsNothing,
        reason: 'panel must not resurrect after the outside tap (3s)');

    // Teardown: dispose tree, then flush any remaining timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });
}
