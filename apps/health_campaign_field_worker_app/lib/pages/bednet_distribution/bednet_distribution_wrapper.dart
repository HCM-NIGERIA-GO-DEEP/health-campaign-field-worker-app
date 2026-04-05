import 'package:digit_data_model/data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/app_initialization/app_initialization.dart';
import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../router/app_router.dart';
import '../../utils/environment_config.dart';
import '../../utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/utils.dart';

@RoutePage()
class BednetDistributionWrapperPage extends StatelessWidget
    implements AutoRouteWrapper {
  const BednetDistributionWrapperPage({super.key});

  static const _squareShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.zero,
  );

  @override
  Widget build(BuildContext context) {
    return const AutoRouter();
  }

  @override
  Widget wrappedRoute(BuildContext context) {
    final initState = context.read<AppInitializationBloc>().state;
    final bednetShell = initState.maybeWhen(
      initialized: (appConfiguration, _, __) {
        _syncRegistrationDeliverySingleton(context, appConfiguration);
        return _bednetShell(context, baseTheme: Theme.of(context));
      },
      orElse: () => const Material(
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    return bednetShell;
  }

  Widget _bednetShell(BuildContext context, {required ThemeData baseTheme}) {
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

void _syncRegistrationDeliverySingleton(
  BuildContext context,
  AppConfiguration appConfiguration,
) {
  final rd = RegistrationDeliverySingleton();
  rd.setTenantId(envConfig.variables.tenantId);
  rd.setBoundary(boundary: context.boundary);
  rd.setInitialData(
    loggedInUserUuid: context.loggedInUserUuid,
    maxRadius: appConfiguration.maxRadius ?? 5000,
    projectId: context.projectId,
    selectedBeneficiaryType: context.beneficiaryType,
    projectType: context.selectedProjectType,
    selectedProject: context.selectedProject,
    genderOptions:
        appConfiguration.genderOptions?.map((e) => e.code).toList(),
    idTypeOptions:
        appConfiguration.idTypeOptions?.map((e) => e.code).toList(),
    householdDeletionReasonOptions: appConfiguration
        .householdDeletionReasonOptions
        ?.map((e) => e.code)
        .toList(),
    householdMemberDeletionReasonOptions: appConfiguration
        .householdMemberDeletionReasonOptions
        ?.map((e) => e.code)
        .toList(),
    deliveryCommentOptions: appConfiguration.deliveryCommentOptions
        ?.map((e) => e.code)
        .toList(),
    symptomsTypes:
        appConfiguration.symptomsTypes?.map((e) => e.code).toList(),
    searchHouseHoldFilter: appConfiguration.searchHouseHoldFilters
        ?.where((e) => e.active)
        .map((e) => e.code)
        .toList(),
    searchCLFFilters: appConfiguration.searchCLFFilters
        ?.where((e) => e.active)
        .map((e) => e.code)
        .toList(),
    referralReasons:
        appConfiguration.referralReasons?.map((e) => e.code).toList(),
    houseStructureTypes:
        appConfiguration.houseStructureTypes?.map((e) => e.code).toList(),
    refusalReasons:
        appConfiguration.refusalReasons?.map((e) => e.code).toList(),
    loggedInUser: context.loggedInUserModel,
  );
}
