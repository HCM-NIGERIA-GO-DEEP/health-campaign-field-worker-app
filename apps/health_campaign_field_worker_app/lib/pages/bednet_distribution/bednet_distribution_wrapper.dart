import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../router/app_router.dart';
import '../../utils/extensions/extensions.dart';

@RoutePage()
class BednetDistributionWrapperPage extends StatelessWidget
    implements AutoRouteWrapper {
  const BednetDistributionWrapperPage({super.key});

  static final _squareShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.zero,
  );

  @override
  Widget build(BuildContext context) {
    return const AutoRouter();
  }

  @override
  Widget wrappedRoute(BuildContext context) {
    final boundaryCode = context.boundaryOrNull?.code ?? '';
    context.read<BednetDistributionBloc>().add(
          BednetDistributionEvent.initialize(
            boundaryCode: boundaryCode,
          ),
        );

    final baseTheme = Theme.of(context);
    final squareTheme = baseTheme.copyWith(
      cardTheme: baseTheme.cardTheme.copyWith(shape: _squareShape),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: _squareShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: _squareShape),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder:
            const OutlineInputBorder(borderRadius: BorderRadius.zero),
        focusedBorder:
            const OutlineInputBorder(borderRadius: BorderRadius.zero),
        errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        focusedErrorBorder:
            const OutlineInputBorder(borderRadius: BorderRadius.zero),
      ),
    );

    return Theme(
      data: squareTheme,
      child: this,
    );
  }
}
