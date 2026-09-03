import 'package:digit_ui_components/models/RadioButtonModel.dart';
import 'package:digit_ui_components/widgets/atoms/digit_checkbox.dart';
import 'package:digit_ui_components/widgets/atoms/digit_radio_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the per-option `Semantics(identifier: '<prefix>_<code>')`
/// added to [RadioList] (local vendored change).
///
/// Why it exists: on a real device the radio's own label is absorbed into the
/// field's merged label node, so the tappable radio ships with no id, no text
/// and no accessibility label — accessibility-tree drivers (Maestro, TalkBack)
/// have nothing to address it by. Proven on run maestro-2026-09-03-1214, where
/// the caregiver-consent radios appeared as two bare clickable nodes at
/// [510,908][594,992] and [738,908][822,992].
void main() {
  /// Every semantics identifier currently in the tree.
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

  Finder byIdentifier(String identifier) => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.identifier == identifier,
      );

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('radio options expose <prefix>_<code> identifiers',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(
      RadioList(
        semanticsIdentifierPrefix: 'consentToParticipate',
        onChanged: (_) {},
        radioDigitButtons: [
          RadioButtonModel(code: 'TRUE', name: 'Yes'),
          RadioButtonModel(code: 'FALSE', name: 'No'),
        ],
      ),
    ));

    expect(
      allIdentifiers(tester),
      containsAll(['consentToParticipate_TRUE', 'consentToParticipate_FALSE']),
    );

    handle.dispose();
  });

  testWidgets('the identified node is the one that selects the option',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    RadioButtonModel? selected;

    await tester.pumpWidget(host(
      RadioList(
        semanticsIdentifierPrefix: 'consentToParticipate',
        onChanged: (value) => selected = value,
        radioDigitButtons: [
          RadioButtonModel(code: 'TRUE', name: 'Yes'),
          RadioButtonModel(code: 'FALSE', name: 'No'),
        ],
      ),
    ));

    // Tapping the identified node must pick that option - an id on a
    // non-interactive ancestor would be useless to a UI-test driver.
    await tester.tap(byIdentifier('consentToParticipate_TRUE'));
    await tester.pump();

    expect(selected?.code, 'TRUE');

    handle.dispose();
  });

  testWidgets('option identifiers survive an enclosing field identifier',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    // Mirrors the live tree: JsonFormBuilder wraps every field in
    // Semantics(identifier: formControlName), and that wrapper must not
    // swallow the per-option identifiers underneath it.
    await tester.pumpWidget(host(
      Semantics(
        identifier: 'consentToParticipate',
        child: RadioList(
          semanticsIdentifierPrefix: 'consentToParticipate',
          onChanged: (_) {},
          radioDigitButtons: [
            RadioButtonModel(code: 'TRUE', name: 'Yes'),
            RadioButtonModel(code: 'FALSE', name: 'No'),
          ],
        ),
      ),
    ));

    expect(
      allIdentifiers(tester),
      containsAll([
        'consentToParticipate',
        'consentToParticipate_TRUE',
        'consentToParticipate_FALSE',
      ]),
    );

    handle.dispose();
  });

  testWidgets('groups sharing option codes get distinct identifiers',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    // The eligibility checklist renders ec1..ec5 on one page, all YES/NO -
    // scoping by form control name is what keeps them addressable apart.
    await tester.pumpWidget(host(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in ['ec1', 'ec2'])
            RadioList(
              semanticsIdentifierPrefix: field,
              onChanged: (_) {},
              radioDigitButtons: [
                RadioButtonModel(code: 'YES', name: 'Yes'),
                RadioButtonModel(code: 'NO', name: 'No'),
              ],
            ),
        ],
      ),
    ));

    expect(
      allIdentifiers(tester),
      containsAll(['ec1_YES', 'ec1_NO', 'ec2_YES', 'ec2_NO']),
    );

    handle.dispose();
  });

  testWidgets('no prefix leaves the radios unannotated (previous behaviour)',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(
      RadioList(
        onChanged: (_) {},
        radioDigitButtons: [
          RadioButtonModel(code: 'TRUE', name: 'Yes'),
          RadioButtonModel(code: 'FALSE', name: 'No'),
        ],
      ),
    ));

    expect(allIdentifiers(tester), isEmpty);

    handle.dispose();
  });

  // DigitCheckbox has the same shape as RadioList: the tappable box and its
  // label are siblings, so the box carries no label of its own. Probed
  // 2026-09-03 - the box is a bare 24x24 node with label="" and tap=true.
  testWidgets('checkbox exposes semanticsIdentifier on the tappable box',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    bool? changed;

    await tester.pumpWidget(host(
      Semantics(
        identifier: 'ACTION1',
        child: DigitCheckbox(
          semanticsIdentifier: 'ACTION1_checkbox',
          label: 'I have explained the dosage',
          value: false,
          onChanged: (value) => changed = value,
        ),
      ),
    ));

    expect(
      allIdentifiers(tester),
      containsAll(['ACTION1', 'ACTION1_checkbox']),
    );

    // The identified node must be the box itself, not the label block.
    await tester.tap(byIdentifier('ACTION1_checkbox'));
    await tester.pump();
    expect(changed, isTrue);

    handle.dispose();
  });

  testWidgets('checkbox without an identifier stays unannotated',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(
      DigitCheckbox(
        label: 'I have explained the dosage',
        value: false,
        onChanged: (_) {},
      ),
    ));

    expect(allIdentifiers(tester), isEmpty);

    handle.dispose();
  });
}
