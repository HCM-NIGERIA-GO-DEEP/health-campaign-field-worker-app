import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/pages/boundary_selection.dart';
import 'package:health_campaign_field_worker_app/utils/app_theme.dart';

/// Records the routes currently on the navigator, bottom first.
class _Routes extends NavigatorObserver {
  final stack = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.remove(route);
}

/// Submit on the boundary page shows a loader during the connection check.
/// The loader must always go away, and must take nothing else with it.
void main() {
  late _Routes routes;
  late BuildContext pageContext;

  Future<void> pumpPage(WidgetTester tester) async {
    routes = _Routes();
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      navigatorObservers: [routes],
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold(body: Text('page'));
      }),
    ));
    expect(routes.stack, hasLength(1));
  }

  testWidgets('the loader shows while the task runs and is removed after it',
      (tester) async {
    await pumpPage(tester);
    final task = Completer<bool>();

    final result = runWithOverlayLoader(pageContext, () => task.future);
    await tester.pump();
    expect(routes.stack, hasLength(2), reason: 'page + loader');
    expect(routes.stack.last, isA<PopupRoute<dynamic>>());

    task.complete(true);
    expect(await result, isTrue);
    await tester.pump();
    expect(routes.stack, hasLength(1), reason: 'only the page is left');
  });

  testWidgets('the loader is removed when the task throws', (tester) async {
    await pumpPage(tester);
    final task = Completer<bool>();

    Object? error;
    final result = runWithOverlayLoader(pageContext, () => task.future)
        .catchError((Object e) {
      error = e;
      return false;
    });
    await tester.pump();
    expect(routes.stack, hasLength(2));

    task.completeError(StateError('lookup failed'));
    await result;
    await tester.pump();
    expect(error, isA<StateError>(), reason: 'the error still reaches the caller');
    expect(routes.stack, hasLength(1));
  });

  testWidgets('back during the task closes the loader and nothing else',
      (tester) async {
    await pumpPage(tester);
    final page = routes.stack.single;
    final task = Completer<bool>();

    final result = runWithOverlayLoader(pageContext, () => task.future);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(routes.stack, [page], reason: 'back closed the loader');

    task.complete(false);
    await result;
    await tester.pump();
    expect(routes.stack, [page], reason: 'the page is not popped afterwards');
  });

  testWidgets('a popup opened during the task stays; only the loader goes',
      (tester) async {
    await pumpPage(tester);
    final task = Completer<bool>();

    final result = runWithOverlayLoader(pageContext, () => task.future);
    await tester.pump();
    final loader = routes.stack.last;
    unawaited(showDialog<void>(
      context: pageContext,
      builder: (_) => const AlertDialog(title: Text('No internet')),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(routes.stack, hasLength(3));

    task.complete(true);
    await result;
    await tester.pump(const Duration(seconds: 1));
    expect(routes.stack, hasLength(2));
    expect(routes.stack, isNot(contains(loader)));
    expect(find.text('No internet'), findsOneWidget);
  });

  testWidgets('two loaders opened together are both removed', (tester) async {
    await pumpPage(tester);
    final first = Completer<bool>();
    final second = Completer<bool>();

    final a = runWithOverlayLoader(pageContext, () => first.future);
    final b = runWithOverlayLoader(pageContext, () => second.future);
    await tester.pump();
    expect(routes.stack, hasLength(3));

    first.complete(true);
    await a;
    second.complete(true);
    await b;
    await tester.pump(const Duration(seconds: 1));
    expect(routes.stack, hasLength(1));
  });
}
