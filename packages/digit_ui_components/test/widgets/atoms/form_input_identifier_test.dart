import 'package:digit_ui_components/widgets/atoms/digit_text_form_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for `BaseDigitFormInput.semanticsIdentifier` (local
/// vendored change).
///
/// Why it exists: the forms engine puts `Semantics(identifier: formControlName)`
/// around the whole field, and a text input renders its helpText as a SIBLING
/// row inside its own Column. So the field-level node is up to twice the input's
/// height and its centre falls on the seam BELOW the box. Run
/// maestro-2026-09-03-1432 hit exactly that: `nameOfIndividual` resolved to
/// bounds [98,861][1342,1169], Maestro tapped the centre (720,1015), nothing
/// focused, `eraseText` fired 50 backspaces into nothing, and the follow-up
/// `hideKeyboard` (a BACK press) popped the page.
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

  /// Mirrors the live tree: a field-level identifier wrapping an input that
  /// renders a helpText row of its own.
  Widget host({String? inputIdentifier, String? helpText}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Semantics(
              identifier: 'nameOfIndividual',
              child: DigitTextFormInput(
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
      inputIdentifier: 'nameOfIndividual_input',
      helpText: 'Enter the full legal name of the individual.',
    ));

    expect(
      allIdentifiers(tester),
      containsAll(['nameOfIndividual', 'nameOfIndividual_input']),
    );

    final fieldRect = tester.getRect(byIdentifier('nameOfIndividual'));
    final inputRect = tester.getRect(byIdentifier('nameOfIndividual_input'));

    // The helpText row must be outside the annotated input.
    expect(inputRect.height, lessThan(fieldRect.height));

    // THE defect, stated directly: the field block's centre is not on the box,
    // so a driver aiming at the field id taps dead space.
    expect(inputRect.contains(fieldRect.center), isFalse,
        reason: 'field-level centre must be outside the input box - that is '
            'why the input needs its own id');

    // ...while the input id's own centre is on the box.
    expect(inputRect.contains(inputRect.center), isTrue);

    handle.dispose();
  });

  testWidgets('tapping the input id focuses the field (the field id does not)',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(
      inputIdentifier: 'nameOfIndividual_input',
      helpText: 'Enter the full legal name of the individual.',
    ));

    bool hasFocus() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;

    expect(hasFocus(), isFalse);

    // Aiming at the field block's centre - what Maestro did in run -1432.
    await tester
        .tapAt(tester.getRect(byIdentifier('nameOfIndividual')).center);
    await tester.pump();
    expect(hasFocus(), isFalse, reason: 'reproduces the run -1432 miss');

    // Aiming at the input id focuses it, so eraseText/inputText can land.
    await tester.tapAt(tester.getRect(byIdentifier('nameOfIndividual_input')).center);
    await tester.pump();
    expect(hasFocus(), isTrue);

    handle.dispose();
  });

  testWidgets('no identifier leaves the input unannotated (previous behaviour)',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(helpText: 'Some help text.'));

    expect(allIdentifiers(tester), ['nameOfIndividual']);

    handle.dispose();
  });
}
