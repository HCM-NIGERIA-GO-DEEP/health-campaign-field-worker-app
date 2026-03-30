import 'package:digit_data_model/data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../data/repositories/bednet_distribution_repository.dart';
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

    return BlocProvider(
      create: (_) => BednetDistributionBloc(
        householdLocalRepository: context
            .read<LocalRepository<HouseholdModel, HouseholdSearchModel>>(),
        individualLocalRepository: context
            .read<LocalRepository<IndividualModel, IndividualSearchModel>>(),
        bednetDistributionRepository: BednetDistributionRepository(
          individualLocalRepository: context.read<
              LocalRepository<IndividualModel, IndividualSearchModel>>(),
          householdMemberLocalRepository: context.read<
              LocalRepository<HouseholdMemberModel,
                  HouseholdMemberSearchModel>>(),
          projectBeneficiaryLocalRepository: context.read<
              LocalRepository<ProjectBeneficiaryModel,
                  ProjectBeneficiarySearchModel>>(),
          taskLocalRepository:
              context.read<LocalRepository<TaskModel, TaskSearchModel>>(),
          projectResourceLocalRepository: context.read<
              LocalRepository<ProjectResourceModel,
                  ProjectResourceSearchModel>>(),
        ),
      )..add(
          BednetDistributionEvent.initialize(
            boundaryCode: context.boundary.code ?? '',
          ),
        ),
      child: Theme(
        data: squareTheme,
        child: this,
      ),
    );
  }
}
