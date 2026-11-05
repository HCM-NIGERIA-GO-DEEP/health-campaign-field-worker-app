import 'package:auto_route/auto_route.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/back_navigation_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final systemBack in [true, false]) {
    testWidgets(
        '${systemBack ? 'System Back' : 'Toolbar Back'} exits an intercepted page once',
        (tester) async {
      var intercepted = 0;
      final router = _TestRouter(Builder(builder: (context) {
        Future<void> goBack() async {
          await BackNavigationExecutor().execute(
            ActionConfig.fromJson({
              'actionType': 'BACK_NAVIGATION',
              'properties': {
                'forcePop': true,
                if (!systemBack) 'name': 'missingPage',
              },
            }),
            context,
            {},
          );
        }

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop && ++intercepted == 1) goBack();
          },
          child: Scaffold(
            body: TextButton(onPressed: goBack, child: const Text('Back')),
          ),
        );
      }));

      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
      await tester.pumpAndSettle();
      router.push(const PageRouteInfo('OverviewRoute'));
      await tester.pumpAndSettle();

      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Back'));
      }
      await tester.pumpAndSettle();

      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(intercepted, systemBack ? 1 : 0);
    });
  }
}

class _TestRouter extends RootStackRouter {
  _TestRouter(this.overview);

  final Widget overview;

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: const PageInfo('SearchRoute'), path: '/'),
        AutoRoute(page: const PageInfo('OverviewRoute'), path: '/overview'),
      ];

  @override
  Map<String, PageFactory> get pagesMap => {
        'SearchRoute': (data) => AutoRoutePage<void>(
              routeData: data,
              child: const Scaffold(body: Text('Search')),
            ),
        'OverviewRoute': (data) =>
            AutoRoutePage<void>(routeData: data, child: overview),
      };
}
