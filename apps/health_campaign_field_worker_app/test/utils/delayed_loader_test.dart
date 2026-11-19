import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/delayed_loader.dart';

Future<void> _testLoader(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Text('loading'),
    );

void main() {
  const delay = Duration(milliseconds: 300);

  /// Opens a second page over a home page and returns its context, so a
  /// stray pop would be visible as the second page disappearing.
  Future<BuildContext> openPage(WidgetTester tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (home) => TextButton(
          onPressed: () => Navigator.of(home).push(MaterialPageRoute<void>(
            builder: (page) {
              pageContext = page;
              return const Scaffold(body: Text('boundary page'));
            },
          )),
          child: const Text('home'),
        ),
      ),
    ));
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    return pageContext;
  }

  Future<T?> run<T>(BuildContext context, Future<T> work) =>
      runWithDelayedLoader(context, work,
          delay: delay, showLoader: _testLoader);

  testWidgets('work that finishes at once shows no loader', (tester) async {
    final context = await openPage(tester);

    final result = run(context, Future.value(7));
    await tester.pump(delay * 2);

    expect(await result, 7);
    expect(find.text('loading'), findsNothing);
    expect(find.text('boundary page'), findsOneWidget);
  });

  testWidgets('slow work shows the loader and closes it when done',
      (tester) async {
    final context = await openPage(tester);
    final work = Completer<int>();

    final result = run(context, work.future);
    await tester.pump(delay ~/ 2);
    expect(find.text('loading'), findsNothing);
    await tester.pump(delay);
    expect(find.text('loading'), findsOneWidget);

    work.complete(7);
    expect(await result, 7);
    await tester.pumpAndSettle();
    expect(find.text('loading'), findsNothing);
    expect(find.text('boundary page'), findsOneWidget);
  });

  testWidgets('a loader closed with back does not close the page under it',
      (tester) async {
    final context = await openPage(tester);
    final work = Completer<int>();

    final result = run(context, work.future);
    await tester.pump(delay * 2);
    expect(find.text('loading'), findsOneWidget);

    Navigator.of(context, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    expect(find.text('loading'), findsNothing);

    work.complete(7);
    await result;
    await tester.pumpAndSettle();
    expect(find.text('boundary page'), findsOneWidget);
  });

  testWidgets('failed work closes the loader and passes the error on',
      (tester) async {
    final context = await openPage(tester);
    final work = Completer<int>();

    final result = run(context, work.future);
    await tester.pump(delay * 2);
    expect(find.text('loading'), findsOneWidget);

    work.completeError(TimeoutException('slow'));
    await expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pumpAndSettle();
    expect(find.text('loading'), findsNothing);
    expect(find.text('boundary page'), findsOneWidget);
  });
}
