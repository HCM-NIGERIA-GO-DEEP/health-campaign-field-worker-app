import 'package:digit_ui_components/widgets/atoms/digit_text_area_form_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for `DigitTextAreaFormInput.semanticsIdentifier` (local
/// vendored change).
///
/// Why it exists: `BaseDigitFormInput.semanticsIdentifier` (see
/// form_input_identifier_test.dart) already wraps the INPUT ONLY - including
/// the `isTextArea` branch, which is a sibling of the helpText/charCount/error
/// row in the same Column - but `DigitTextAreaFormInput`'s own const
/// constructor never exposed the parameter, so every textArea field (e.g.
/// STOCKRECONCILIATION.json's `comments`) had no way to get one.
///
/// NOTE - this is NOT a copy of form_input_identifier_test's "field-centre
/// misses the box" finding: measured in this harness, a textArea's box is
/// tall enough (min 4 lines) that the FIELD-level centre still lands inside
/// it even with a helpText row below, unlike the single-line text input where
/// the box is short and the seam dominates. So this file does not assert a
/// field-level-tap miss (it would be false here) - only that the input gets
/// its own reliable, independently-addressable id, which is what actually
/// matters for a stable Maestro selector regardless of a given screen's
/// helpText length/box height. Per that other test's own caution note, the
/// device hierarchy is the source of truth for which taps work on a real
/// STOCKRECONCILIATION screen, not this synthetic host tree.
void main() {
  Finder byIdentifier(String identifier) => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.identifier == identifier,
      );

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

    visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    return ids;
  }

  /// Mirrors the live tree: a field-level identifier wrapping a textArea input
  /// that renders a helpText row of its own.
  Widget host({String? inputIdentifier, String? helpText}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Semantics(
              identifier: 'comments',
              child: DigitTextAreaFormInput(
                semanticsIdentifier: inputIdentifier,
                helpText: helpText,
                initialValue: 'qatest',
                onChange: (_) {},
              ),
            ),
          ),
        ),
      );

  testWidgets('the input id survives the field id and covers only the box',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(
      inputIdentifier: 'comments_input',
      helpText: 'Explain the discrepancy between the manual and system count.',
    ));

    expect(
      allIdentifiers(tester),
      containsAll(['comments', 'comments_input']),
    );

    final fieldRect = tester.getRect(byIdentifier('comments'));
    final inputRect = tester.getRect(byIdentifier('comments_input'));

    // The helpText row must be outside the annotated input - the input rect
    // is strictly smaller than the field block that also contains it.
    expect(inputRect.height, lessThan(fieldRect.height));

    // The input id's own centre is reliably on the box itself.
    expect(inputRect.contains(inputRect.center), isTrue);

    handle.dispose();
  });

  testWidgets('tapping the input id focuses the field',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(
      inputIdentifier: 'comments_input',
      helpText: 'Explain the discrepancy between the manual and system count.',
    ));

    bool hasFocus() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;

    expect(hasFocus(), isFalse);

    // Aiming at the input id focuses it, so eraseText/inputText can land.
    await tester.tapAt(tester.getRect(byIdentifier('comments_input')).center);
    await tester.pump();
    expect(hasFocus(), isTrue);

    handle.dispose();
  });

  testWidgets('no identifier leaves the input unannotated (previous behaviour)',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(helpText: 'Some help text.'));

    expect(allIdentifiers(tester), ['comments']);

    handle.dispose();
  });
}
