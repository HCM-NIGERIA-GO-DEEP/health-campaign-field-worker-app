import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:digit_flow_builder/blocs/app_localization.dart';
import 'package:digit_flow_builder/widgets/dedup_match_dialog.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_ui_components/theme/digit_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves an empty string table, so `translate` echoes each code back and the
/// dialog falls through to its English copy -- the same state as a device that
/// has not yet downloaded the dedup strings.
class _EmptyLocalizationDelegate
    extends LocalizationsDelegate<FlowBuilderLocalization> {
  const _EmptyLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FlowBuilderLocalization> load(Locale locale) async {
    final localization =
        FlowBuilderLocalization(locale, Future.value(const []), const []);
    await localization.load();
    return localization;
  }

  @override
  bool shouldReload(_) => false;
}

/// Null exercises the built-in dialog's own default copy, which is what a page
/// with no dialog block gets.
const DedupAlertPopUp? _alert = null;

DedupMatch _match({String? beneficiaryId}) => DedupMatch(
      recordIndex: 0,
      score: 0.92,
      attributeScores: const {'givenName': 0.92},
      record: {
        DedupRecordKeys.displayName: 'Piter one',
        DedupRecordKeys.beneficiaryId: beneficiaryId,
        DedupRecordKeys.clientReferenceId: 'ref-1',
      },
    );

void main() {
  late List<MethodCall> clipboardCalls;

  setUp(() {
    clipboardCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Popup sizes itself from the viewport, and the 800x600 test default lays
  /// its content out thousands of pixels down, beyond hit-test range. Use a
  /// phone-sized viewport so the layout matches a real device.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(414, 896);
    addTearDown(tester.view.reset);
  }

  /// Pumps the dialog and hands back a future completing with the outcome.
  Future<Future<DedupCheckOutcome>> pumpDialog(
    WidgetTester tester, {
    required List<DedupMatch> matches,
    VoidCallback? onBackToSearch,
  }) async {
    usePhoneViewport(tester);
    late Future<DedupCheckOutcome> outcome;

    await tester.pumpWidget(MaterialApp(
      theme: DigitTheme.instance.mobileTheme,
      localizationsDelegates: const [_EmptyLocalizationDelegate()],
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              outcome = showDedupMatchDialog(
                context: context,
                alert: _alert,
                matches: matches,
                onBackToSearch: onBackToSearch ?? () {},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    // Localizations resolve asynchronously, so the first frame is empty.
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return outcome;
  }

  testWidgets('shows the match name, beneficiary ID and score', (tester) async {
    await pumpDialog(tester, matches: [_match(beneficiaryId: '551520131')]);

    expect(find.text('Piter one'), findsOneWidget);
    expect(find.text('551520131'), findsOneWidget);
    expect(find.text('92% match'), findsOneWidget);
  });

  testWidgets('labels the primary action Skip and Proceed', (tester) async {
    await pumpDialog(tester, matches: [_match(beneficiaryId: '551520131')]);

    // DigitButton title-cases labels unless told not to, which would turn
    // this into "Skip And Proceed".
    expect(find.text('Skip and Proceed'), findsOneWidget);
    expect(find.text('Skip And Proceed'), findsNothing);
    expect(find.text('Back to Search'), findsOneWidget);
  });

  testWidgets('renders a copy button for both the name and the ID',
      (tester) async {
    await pumpDialog(tester, matches: [_match(beneficiaryId: '551520131')]);
    expect(find.byIcon(Icons.content_copy_outlined), findsNWidgets(2));
  });

  testWidgets('copying the name puts it on the clipboard', (tester) async {
    await pumpDialog(tester, matches: [_match(beneficiaryId: '551520131')]);

    await tester.tap(find.byIcon(Icons.content_copy_outlined).first);
    await tester.pump();

    expect(clipboardCalls, hasLength(1));
    expect((clipboardCalls.single.arguments as Map)['text'], 'Piter one');
  });

  testWidgets('copying the ID puts it on the clipboard', (tester) async {
    await pumpDialog(tester, matches: [_match(beneficiaryId: '551520131')]);

    await tester.tap(find.byIcon(Icons.content_copy_outlined).last);
    await tester.pump();

    expect(clipboardCalls, hasLength(1));
    expect((clipboardCalls.single.arguments as Map)['text'], '551520131');
  });

  testWidgets('a copy button confirms with a tick, then reverts',
      (tester) async {
    await pumpDialog(tester, matches: [_match(beneficiaryId: '551520131')]);

    await tester.tap(find.byIcon(Icons.content_copy_outlined).last);
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.content_copy_outlined), findsNWidgets(2));
  });

  testWidgets('offers no copy button when the match has no beneficiary ID',
      (tester) async {
    await pumpDialog(tester, matches: [_match()]);

    expect(find.text('No beneficiary ID'), findsOneWidget);
    // Only the name remains copyable.
    expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);
  });

  testWidgets('Skip and Proceed resolves to proceed', (tester) async {
    final outcome =
        await pumpDialog(tester, matches: [_match(beneficiaryId: '1')]);

    await tester.tap(find.text('Skip and Proceed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await outcome, DedupCheckOutcome.proceed);
  });

  testWidgets('Back to Search aborts and fires the callback', (tester) async {
    var backToSearchCalls = 0;
    final outcome = await pumpDialog(
      tester,
      matches: [_match(beneficiaryId: '1')],
      onBackToSearch: () => backToSearchCalls++,
    );

    await tester.tap(find.text('Back to Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await outcome, DedupCheckOutcome.abort);
    expect(backToSearchCalls, 1);
  });
}
