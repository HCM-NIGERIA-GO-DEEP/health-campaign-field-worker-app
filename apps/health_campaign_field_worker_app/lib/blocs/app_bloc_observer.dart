import 'package:digit_crud_bloc/bloc/crud_bloc.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (!kDebugMode) return;
    if (bloc is LocationBloc) return;
    // CrudBloc/FlowCrudBloc states carry full search result graphs
    // (households, individuals, tasks, ...). Logging their nextState here
    // means AppLogger.debugPrint()-wraps that entire object on every single
    // transition — including every pagination page load — which can take
    // 10+ seconds for a normal-sized result set and freezes the UI thread
    // long enough that loading indicators never get a chance to paint.
    if (bloc is CrudBloc) return;

    AppLogger.instance.info(
      transition.nextState,
      title: '${bloc.runtimeType}.onTransition: ${transition.event}',
    );
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (!kDebugMode || bloc.runtimeType.toString().endsWith('Bloc')) return;

    AppLogger.instance.info(
      change.nextState,
      title: '${bloc.runtimeType}.onChange',
    );
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (!kDebugMode) return;

    AppLogger.instance.error(
      title: bloc.runtimeType.toString(),
      stackTrace: stackTrace,
    );
  }
}
