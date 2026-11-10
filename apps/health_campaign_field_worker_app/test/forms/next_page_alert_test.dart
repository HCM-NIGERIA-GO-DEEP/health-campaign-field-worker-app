import 'package:digit_forms_engine/helper/next_page_alert.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Household details "note down the e-token" popup (showNextAlertPopUp).
void main() {
  const token = '0042_raw7';
  const navToken = AlertCondition(
      expression: 'DEFAULT', value: '{{navigation.beneficiaryId}}');
  final messages = {
    'REGISTRATION_ETOKEN_POPUP_TITLE': 'Note down the e-Token',
    'REGISTRATION_ETOKEN_POPUP_DESCRIPTION':
        'Please note down the e-Token - **{value}**. Do you want to submit?',
    'ACTION_SUBMIT': 'Submit',
    'ACTION_CANCEL': 'Cancel',
    'LITERAL_KEY': 'Literal text',
  };
  String translate(String key) => messages[key] ?? key;

  String? describe(String text,
          {List<AlertCondition>? conditions = const [navToken],
          Map<String, dynamic> nav = const {'beneficiaryId': token}}) =>
      resolveNextPageAlertDescription(
          description: text,
          conditions: conditions,
          nextNavParams: nav,
          translate: translate);

  group('resolveNextPageAlertDescription', () {
    test('fills {value} with the e-token the next page receives', () {
      expect(describe('Note **{value}**. Submit?'), 'Note **$token**. Submit?');
    });

    test('fills a bare {} slot too, as typed in the request', () {
      expect(
          describe('Please note down the e token - {},Do you want to submit?'),
          'Please note down the e token - $token,Do you want to submit?');
    });

    test('appends the e-token in bold when the text has no slot', () {
      // A missing localisation comes back as the raw key.
      expect(describe('REGISTRATION_ETOKEN_POPUP_DESCRIPTION'),
          'REGISTRATION_ETOKEN_POPUP_DESCRIPTION\n\n**$token**');
      // A blank MDMS message must not hide it either.
      expect(describe(' '), '**$token**');
    });

    test('returns null when the e-token is missing or blank', () {
      expect(describe('Note {value}', nav: const {}), isNull);
      expect(describe('Note {value}', nav: const {'beneficiaryId': '  '}),
          isNull);
      expect(describe('no slot', nav: const {'beneficiaryId': null}), isNull);
      // One missing token in a combined value must not leave a partial one.
      expect(
          describe('Note {value}', conditions: const [
            AlertCondition(
                expression: 'DEFAULT',
                value: '{{navigation.dpCode}}-{{navigation.beneficiaryId}}')
          ]),
          isNull);
    });

    test('uses the DEFAULT entry and ignores other expressions', () {
      expect(
          describe('Note {value}', conditions: const [
            AlertCondition(expression: 'isEdit == true', value: 'WRONG'),
            navToken,
          ]),
          'Note $token');
    });

    test('without a DEFAULT entry: unchanged text, or null if it has a slot',
        () {
      expect(describe('Plain text', conditions: null), 'Plain text');
      expect(describe('Note {value}', conditions: const []), isNull);
    });

    test('a plain value is translated like showAlertPopUp values', () {
      expect(
          describe('Note {value}', conditions: const [
            AlertCondition(expression: 'DEFAULT', value: 'LITERAL_KEY')
          ]),
          'Note Literal text');
    });
  });

  group('confirmNextPage', () {
    const popup = ShowAlertPopUp(
      title: 'REGISTRATION_ETOKEN_POPUP_TITLE',
      description: 'REGISTRATION_ETOKEN_POPUP_DESCRIPTION',
      primaryActionLabel: 'ACTION_SUBMIT',
      secondaryActionLabel: 'ACTION_CANCEL',
      conditions: [navToken],
    );
    final title = find.text('Note down the e-Token', findRichText: true);

    /// Opens the popup and returns a getter for its outcome, which stays null
    /// while the popup is open - a missed tap fails the test, never hangs it.
    Future<bool? Function()> open(WidgetTester tester,
        {Map<String, dynamic> nav = const {'beneficiaryId': token}}) async {
      // A phone screen (360 x 800 dp): on the default 800 x 600 test surface
      // Popup's height cap clips its buttons out of reach.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
        builder: (c) {
          context = c;
          return const SizedBox.expand();
        },
      ))));
      bool? outcome;
      confirmNextPage(
              context: context,
              popup: popup,
              nextNavParams: nav,
              translate: translate)
          .then((value) => outcome = value);
      await tester.pumpAndSettle();
      return () => outcome;
    }

    Finder button(String label) => find.widgetWithText(DigitButton, label);

    testWidgets('shows the e-token with Submit and Cancel; Submit continues',
        (tester) async {
      final outcome = await open(tester);

      expect(title, findsOneWidget);
      expect(
          find.text(
              'Please note down the e-Token - $token. Do you want to submit?',
              findRichText: true),
          findsOneWidget);
      expect(button('Submit'), findsOneWidget);
      expect(button('Cancel'), findsOneWidget);
      expect(outcome(), isNull);

      await tester.tap(button('Submit'));
      await tester.pumpAndSettle();
      expect(outcome(), isTrue);
      expect(title, findsNothing);
    });

    testWidgets('Cancel stays on the page', (tester) async {
      final outcome = await open(tester);

      await tester.tap(button('Cancel'));
      await tester.pumpAndSettle();
      expect(outcome(), isFalse);
      expect(title, findsNothing);
    });

    testWidgets('the system back button also stays on the page',
        (tester) async {
      final outcome = await open(tester);

      // Popup is full-screen and passes no outside-tap handler, so back is
      // the only other way out of it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(outcome(), isFalse);
      expect(title, findsNothing);
    });

    testWidgets('no e-token: no popup, the page carries on as before',
        (tester) async {
      final outcome = await open(tester, nav: const {});

      expect(title, findsNothing);
      expect(outcome(), isTrue);
    });
  });
}
