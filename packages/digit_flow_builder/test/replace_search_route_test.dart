import 'package:auto_route/auto_route.dart';
import 'package:digit_flow_builder/navigation_service/navigation_service.dart';
import 'package:digit_flow_builder/router/flow_builder_routes.gm.dart';
import 'package:flutter/material.dart' hide NavigationMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returning from delivery replaces the old search instance',
      (tester) async {
    final router = _TestRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();

    router.push(FlowBuilderHomeRoute(
      pageName: 'searchBeneficiary',
      navigationParams: {'query': 'old query'},
    ));
    await tester.pumpAndSettle();
    router.push(FlowBuilderHomeRoute(pageName: 'deliverySuccess'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Fresh search'), findsOneWidget);
    expect(router.stack.map((page) => page.name),
        ['HomeRoute', FlowBuilderHomeRoute.name]);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(router.stack.map((page) => page.name), ['HomeRoute']);
  });
}

class _TestRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: const PageInfo('HomeRoute'), path: '/'),
        AutoRoute(page: FlowBuilderHomeRoute.page, path: '/flow'),
      ];

  @override
  Map<String, PageFactory> get pagesMap => {
        'HomeRoute': (data) => AutoRoutePage<void>(
              routeData: data,
              child: const Scaffold(body: Text('Home')),
            ),
        FlowBuilderHomeRoute.name: (data) {
          final args = data.argsAs<FlowBuilderHomeRouteArgs>();
          return AutoRoutePage<void>(
            routeData: data,
            child: Builder(builder: (context) {
              if (args.pageName == 'searchBeneficiary') {
                return Scaffold(
                  body: Text(
                      args.navigationParams?['query'] as String? ?? 'Fresh search'),
                );
              }
              return PopScope(
                canPop: false,
                onPopInvoked: (didPop) {
                  if (didPop) return;
                  FlowBuilderNavigationService(context, {
                    'searchBeneficiary': (_) =>
                        FlowBuilderHomeRoute(pageName: 'searchBeneficiary'),
                  }).navigateTo(
                    type: 'TEMPLATE',
                    name: 'searchBeneficiary',
                    navigationMode: NavigationMode.popUntilAndReplace,
                    popUntilPageName: 'searchBeneficiary',
                  );
                },
                child: const Scaffold(body: Text('Delivery acknowledgement')),
              );
            }),
          );
        },
      };
}
