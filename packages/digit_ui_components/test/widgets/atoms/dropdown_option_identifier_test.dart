import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the option-row `Semantics(identifier: 'option_<code>')`
/// added (local vendored change) for accessibility-tree drivers (Maestro) and
/// TalkBack: such drivers can only address nodes that carry a resource-id, and
/// Flutter exposes none unless SemanticsProperties.identifier is set.
void main() {
  /// Collect every semantics identifier currently in the tree.
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

  testWidgets(
      'DigitDropdown (single-select) option rows expose option_<code> ids',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DigitDropdown(
            dropdownController: TextEditingController(),
            onSelect: (item) {},
            items: const [
              DropdownItem(name: 'Apple', code: 'a1'),
              DropdownItem(name: 'Banana', code: 'b2'),
            ],
          ),
        ),
      ),
    );

    // Closed: no option rows, no option identifiers.
    expect(allIdentifiers(tester).where((id) => id.startsWith('option_')),
        isEmpty);

    // Open the dropdown via its suffix arrow (same recipe as the package's
    // own tests).
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pump();
    expect(find.byType(ListView), findsOneWidget);

    final optionIds = allIdentifiers(tester)
        .where((id) => id.startsWith('option_'))
        .toList();
    expect(optionIds, containsAll(['option_a1', 'option_b2']));

    // Close before the test ends (open overlays/focus leak timers otherwise).
    await tester.tap(find.byType(GestureDetector, skipOffstage: false).first);
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsNothing);

    // Teardown: drop semantics, dispose the tree, then advance fake time so
    // any remaining one-shot timers (scrollbar fade etc.) fire - pumpAndSettle
    // only settles frames, it does not advance the clock for plain Timers.
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('MultiSelectDropDown option rows expose option_<code> ids',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiSelectDropDown<int>(
            onOptionSelected: (selectedOptions) {},
            options: const [
              DropdownItem(name: 'Atosi', code: 'c1'),
              DropdownItem(name: 'Yelwa', code: 'c2'),
            ],
          ),
        ),
      ),
    );

    expect(allIdentifiers(tester).where((id) => id.startsWith('option_')),
        isEmpty);

    // Open the multiselect via its suffix arrow.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pump();

    final optionIds = allIdentifiers(tester)
        .where((id) => id.startsWith('option_'))
        .toList();
    expect(optionIds, containsAll(['option_c1', 'option_c2']));

    // Close by tapping outside (same recipe as the package's own tests).
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    handle.dispose();
  });
}
