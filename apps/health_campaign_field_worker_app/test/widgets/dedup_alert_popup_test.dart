import 'dart:convert';
import 'dart:io';

import 'package:digit_dedup_engine/digit_dedup_engine.dart';
import 'package:digit_flow_builder/blocs/app_localization.dart';
import 'package:digit_flow_builder/flow_builder.dart';
import 'package:digit_forms_engine/forms_engine.dart';
import 'package:digit_ui_components/theme/digit_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal stand-in for a row of the localization store, which
/// [FlowBuilderLocalization.load] reads by field rather than by key.
class _Localized {
  final String locale;
  final String code;
  final String message;

  const _Localized(this.locale, this.code, this.message);
}

const _locale = Locale('en', 'US');

/// Real English strings rather than an empty table. The codes are far longer
/// than their translations, so an untranslated dialog lays out quite
/// differently -- asserting against codes would measure a state the user
/// should never see.
final _strings = <_Localized>[
  const _Localized('en_US', 'DEDUP_SIMILAR_BENEFICIARY_FOUND_TITLE',
      'Similar beneficiary found'),
  const _Localized('en_US', 'DEDUP_SIMILAR_BENEFICIARY_FOUND_DESCRIPTION',
      'A beneficiary with a similar name is already registered.'),
  const _Localized(
      'en_US', 'DEDUP_SIMILAR_BENEFICIARY_PROCEED', 'Skip and Proceed'),
  const _Localized(
      'en_US', 'DEDUP_SIMILAR_BENEFICIARY_BACK_TO_SEARCH', 'Back to Search'),
  const _Localized(
      'en_US', 'DEDUP_SIMILAR_BENEFICIARY_ID_LABEL', 'Beneficiary ID'),
  const _Localized(
      'en_US', 'DEDUP_SIMILAR_BENEFICIARY_NO_ID', 'No beneficiary ID'),
  const _Localized(
      'en_US', 'DEDUP_SIMILAR_BENEFICIARY_SCORE', '{score}% match'),
];

class _LocalizationDelegate
    extends LocalizationsDelegate<FlowBuilderLocalization> {
  const _LocalizationDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FlowBuilderLocalization> load(Locale locale) async {
    final localization =
        FlowBuilderLocalization(locale, Future.value(_strings), const []);
    await localization.load();
    return localization;
  }

  @override
  bool shouldReload(_) => false;
}

final _registrationConfig = File('assets/configs/json/REGISTRATION.json');

/// The real shipped alert config, so the test exercises what runs on device.
DedupAlertPopUp _shippedAlert() {
  final config = json.decode(_registrationConfig.readAsStringSync())
      as Map<String, dynamic>;
  final flow = (config['flows'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((f) => f['name'] == 'HOUSEHOLD');
  final pages = transformJson(flow)['pages'] as Map<String, dynamic>;
  return PropertySchema.fromJson(
    pages['beneficiaryDetails'] as Map<String, dynamic>,
  ).dedupCheck!.dedupAlertPopUp!;
}

DedupMatch _match({String? beneficiaryId = '551520131'}) => DedupMatch(
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
    // FlowWidgetFactory has no widgets until the registry is initialized.
    WidgetRegistry.initialize();

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

  /// Popup sizes itself from the viewport; the 800x600 test default lays its
  /// content out beyond hit-test range.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(414, 896);
    addTearDown(tester.view.reset);
  }

  /// The success toast schedules a timer the test framework will otherwise
  /// flag as pending at teardown.
  Future<void> drainToastTimer(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 6));

  Future<Future<DedupCheckOutcome>> pumpAlert(
    WidgetTester tester, {
    required List<DedupMatch> matches,
    DedupAlertPopUp? alert,
    VoidCallback? onBackToSearch,
  }) async {
    usePhoneViewport(tester);
    late Future<DedupCheckOutcome> outcome;

    await tester.pumpWidget(MaterialApp(
      theme: DigitTheme.instance.mobileTheme,
      locale: _locale,
      localizationsDelegates: const [_LocalizationDelegate()],
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              outcome = showConfigDedupAlert(
                context: context,
                alert: alert ?? _shippedAlert(),
                matches: matches,
                stateKey: 'HOUSEHOLD::beneficiaryDetails',
                onBackToSearch: onBackToSearch ?? () {},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return outcome;
  }

  group('config-driven dedup alert', () {
    testWidgets('renders the match row from the shipped config',
        (tester) async {
      await pumpAlert(tester, matches: [_match()]);

      // These come from the config body binding to the published match list.
      expect(find.text('Piter one'), findsOneWidget);
      expect(find.text('551520131'), findsOneWidget);
      expect(find.text('92% match'), findsOneWidget);
    });

    testWidgets('renders a copy button per value', (tester) async {
      await pumpAlert(tester, matches: [_match()]);
      expect(find.byIcon(Icons.content_copy_outlined), findsNWidgets(2));
    });

    testWidgets('lays the rows out without overflowing', (tester) async {
      await pumpAlert(tester, matches: [_match()]);

      // An overflowing Row paints striped bars in debug and pushes the copy
      // button out of hit-test range, which is how this first showed up.
      expect(tester.takeException(), isNull);
    });

    testWidgets('copying the name resolves its own item template',
        (tester) async {
      await pumpAlert(tester, matches: [_match()]);

      await tester.tap(find.byIcon(Icons.content_copy_outlined).first);
      await tester.pump();

      // preprocessConfigWithState leaves onAction untouched, so the executor
      // has to resolve {{item.displayName}} itself.
      expect(clipboardCalls, hasLength(1));
      expect((clipboardCalls.single.arguments as Map)['text'], 'Piter one');

      await drainToastTimer(tester);
    });

    testWidgets('copying the beneficiary ID resolves its own item template',
        (tester) async {
      await pumpAlert(tester, matches: [_match()]);

      await tester.tap(find.byIcon(Icons.content_copy_outlined).last);
      await tester.pump();

      expect(clipboardCalls, hasLength(1));
      expect((clipboardCalls.single.arguments as Map)['text'], '551520131');

      await drainToastTimer(tester);
    });

    testWidgets('renders one row per match', (tester) async {
      await pumpAlert(tester, matches: [_match(), _match()]);
      expect(find.text('Piter one'), findsNWidgets(2));
      expect(find.byIcon(Icons.content_copy_outlined), findsNWidgets(4));
    });

    testWidgets('hides the ID and its copy button when there is none',
        (tester) async {
      await pumpAlert(tester, matches: [_match(beneficiaryId: null)]);

      expect(find.text('551520131'), findsNothing);
      expect(find.text('No beneficiary ID'), findsOneWidget);
      // Only the name stays copyable.
      expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);
    });

    testWidgets('the primary action resolves to proceed', (tester) async {
      final outcome = await pumpAlert(tester, matches: [_match()]);

      await tester.tap(find.text('Skip and Proceed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(await outcome, DedupCheckOutcome.proceed);
    });

    testWidgets('the secondary action aborts and fires the callback',
        (tester) async {
      var backToSearchCalls = 0;
      final outcome = await pumpAlert(
        tester,
        matches: [_match()],
        onBackToSearch: () => backToSearchCalls++,
      );

      await tester.tap(find.text('Back to Search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(await outcome, DedupCheckOutcome.abort);
      expect(backToSearchCalls, 1);
    });

    testWidgets('an alert with no body still shows its actions',
        (tester) async {
      final outcome = await pumpAlert(
        tester,
        matches: [_match()],
        alert: const DedupAlertPopUp(
          title: 'T',
          primaryActionLabel: 'P',
          secondaryActionLabel: 'S',
        ),
      );

      expect(find.text('Piter one'), findsNothing);
      await tester.tap(find.text('P'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(await outcome, DedupCheckOutcome.proceed);
    });
  });
}
