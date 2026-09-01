import 'package:digit_analytics/digit_analytics.dart';
import 'package:digit_flow_builder/router/flow_builder_routes.gm.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:flutter/cupertino.dart';

class AppRouterObserver extends NavigatorObserver {
  static const _base = 'appRouter';

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLogger.instance.info(
      '${route.settings.name} -> ${previousRoute?.settings.name}',
      title: '$_base.didPop',
    );
  }

  @override
  void didPush(Route route, Route<dynamic>? previousRoute) {
    AppLogger.instance.info(
      '${previousRoute?.settings.name} -> ${route.settings.name}',
      title: '$_base.didPush',
    );
    _logScreenView(route);
  }

  @override
  void didRemove(Route route, Route<dynamic>? previousRoute) {
    AppLogger.instance.info(
      '${route.settings.name}',
      title: '$_base.didRemove',
    );
  }

  @override
  void didReplace({Route? newRoute, Route<dynamic>? oldRoute}) {
    AppLogger.instance.info(
      '${oldRoute?.settings.name} -X- ${newRoute?.settings.name}',
      title: '$_base.didReplace',
    );
    if (newRoute != null) _logScreenView(newRoute);
  }

  void _logScreenView(Route<dynamic> route) {
    final screenName = _resolveScreenName(route);
    if (screenName == null || screenName.isEmpty) return;

    AnalyticsService.instance.logEvent('screen_view', {
      'screen_name': screenName,
    });
  }

  /// `digit_flow_builder`'s dynamic pages all share the single route name
  /// `FlowBuilderHomeRoute` (see `flow_builder_routes.gm.dart`) — the actual
  /// page being shown only lives in the route's `pageName` argument. Without
  /// this, every step of every flow (registration, checklists, attendance,
  /// etc.) logs the same indistinguishable "FlowBuilderHomeRoute" screen
  /// view.
  String? _resolveScreenName(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == FlowBuilderHomeRoute.name) {
      final args = route.settings.arguments;
      if (args is FlowBuilderHomeRouteArgs) {
        return '$name/${args.pageName}';
      }
    }
    return name;
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    AppLogger.instance.info(
      '${previousRoute?.settings.name} -+- ${route.settings.name}',
      title: '$_base.didStartUserGesture',
    );
  }

  @override
  void didStopUserGesture() {
    AppLogger.instance.info(
      'Stopped gesture',
      title: '$_base.didStopUserGesture',
    );
  }
}
