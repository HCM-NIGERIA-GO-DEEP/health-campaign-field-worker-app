import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data/repositories/package_repository/oplog/oplog.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:survey_form/survey_form.dart';

import '../../blocs/app_initialization/app_initialization.dart';
import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../blocs/localization/localization.dart';
import '../../data/local_store/app_shared_preferences.dart';
import '../../utils/constants.dart';
import '../../blocs/registration_deliver/search_households/household_global_seach.dart';
import '../../blocs/registration_deliver/search_households/individual_global_search.dart';
import '../../blocs/registration_deliver/search_households/search_bloc_common_wrapper.dart';
import '../../blocs/registration_deliver/search_households/search_households.dart';
import '../../blocs/registration_deliver/search_households/tag_by_search.dart';
import '../../data/registration_deliver_repo/local/household_global_search.dart';
import '../../data/registration_deliver_repo/local/individual_global_search.dart';
import '../../data/registration_deliver_repo/local/registration_delivery_address.dart';
import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../router/app_router.dart';
import '../../utils/environment_config.dart';
import '../../utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/utils.dart';

DateTime? _lastBednetLocalizationRequestAt;

/// Loads registration-delivery modules for the bednet flow. Invoked from
/// [BednetDistributionWrapperPage.wrappedRoute] as soon as the shell is
/// entered so localization work starts before nested routes build; avoids a
/// post-frame delay where [RegistrationDeliveryLocalization.translate] falls
/// back to raw keys.
///
/// [BeneficiaryTypeSelectionPage] may call this as well when opened outside the
/// bednet shell (legacy route); a short debounce avoids duplicate bloc events
/// when both the wrapper and that page mount in the same navigation.
void requestBednetRegistrationLocalizationModules(BuildContext context) {
  final now = DateTime.now();
  if (_lastBednetLocalizationRequestAt != null &&
      now.difference(_lastBednetLocalizationRequestAt!) <
          const Duration(milliseconds: 800)) {
    return;
  }
  _lastBednetLocalizationRequestAt = now;

  final locale = AppSharedPreferences().getSelectedLocale;
  if (locale == null) return;
  context.read<LocalizationBloc>().add(
        LocalizationEvent.onLoadLocalization(
          module: 'hcm-household,hcm-closedhousehold,hcm-beneficiary,'
              'hcm-member,hcm-delivery,hcm-home,hcm-common,hcm-scanner',
          tenantId: envConfig.variables.tenantId,
          locale: locale,
          path: Constants.localizationApiPath,
        ),
      );
}

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
        requestBednetRegistrationLocalizationModules(context);
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

    final singleton = RegistrationDeliverySingleton();
    final projectId = singleton.projectId;
    final beneficiaryType = singleton.beneficiaryType;
    final userUid = singleton.loggedInUserUuid;
    if (projectId == null || beneficiaryType == null || userUid == null) {
      return const Material(
        child: Center(
          child: Text('Registration session not initialized'),
        ),
      );
    }

    final sql = context.read<LocalSqlDataStore>();
    final isar = context.read<Isar>();
    final addressRepository = context.read<RegistrationDeliveryAddressRepo>();
    final individualGlobalSearchRepository = IndividualGlobalSearchRepository(
      sql,
      IndividualOpLogManager(isar),
    );
    final houseHoldGlobalSearchRepository = HouseHoldGlobalSearchRepository(
      sql,
      HouseholdOpLogManager(isar),
    );

    final individual = context.repository<IndividualModel, IndividualSearchModel>();
    final household = context.repository<HouseholdModel, HouseholdSearchModel>();
    final householdMember =
        context.repository<HouseholdMemberModel, HouseholdMemberSearchModel>();
    final projectBeneficiary =
        context.repository<ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>();
    final task = context.repository<TaskModel, TaskSearchModel>();
    final sideEffect =
        context.repository<SideEffectModel, SideEffectSearchModel>();
    final referral = context.repository<ReferralModel, ReferralSearchModel>();
    final serviceDefinition = context.repository<ServiceDefinitionModel,
        ServiceDefinitionSearchModel>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => BednetDistributionBloc(
            householdLocalRepository: context
                .read<LocalRepository<HouseholdModel, HouseholdSearchModel>>(),
          )..add(
              BednetDistributionEvent.initialize(
                boundaryCode: context.boundary.code ?? '',
              ),
            ),
        ),
        BlocProvider(
          create: (_) => SearchHouseholdsBloc(
            userUid: userUid,
            projectId: projectId,
            individual: individual,
            householdMember: householdMember,
            household: household,
            projectBeneficiary: projectBeneficiary,
            taskDataRepository: task,
            beneficiaryType: beneficiaryType,
            sideEffectDataRepository: sideEffect,
            addressRepository: addressRepository,
            referralDataRepository: referral,
            individualGlobalSearchRepository: individualGlobalSearchRepository,
            houseHoldGlobalSearchRepository: houseHoldGlobalSearchRepository,
          ),
        ),
        BlocProvider(
          create: (_) => TagSearchBloc(
            userUid: userUid,
            projectId: projectId,
            individual: individual,
            householdMember: householdMember,
            household: household,
            projectBeneficiary: projectBeneficiary,
            taskDataRepository: task,
            beneficiaryType: beneficiaryType,
            sideEffectDataRepository: sideEffect,
            addressRepository: addressRepository,
            referralDataRepository: referral,
            individualGlobalSearchRepository: individualGlobalSearchRepository,
            houseHoldGlobalSearchRepository: houseHoldGlobalSearchRepository,
          ),
        ),
        BlocProvider(
          create: (_) => IndividualGlobalSearchBloc(
            userUid: userUid,
            projectId: projectId,
            individual: individual,
            householdMember: householdMember,
            household: household,
            projectBeneficiary: projectBeneficiary,
            taskDataRepository: task,
            beneficiaryType: beneficiaryType,
            sideEffectDataRepository: sideEffect,
            addressRepository: addressRepository,
            referralDataRepository: referral,
            individualGlobalSearchRepository: individualGlobalSearchRepository,
            houseHoldGlobalSearchRepository: houseHoldGlobalSearchRepository,
          ),
        ),
        BlocProvider(
          create: (_) => HouseHoldGlobalSearchBloc(
            userUid: userUid,
            projectId: projectId,
            individual: individual,
            householdMember: householdMember,
            household: household,
            projectBeneficiary: projectBeneficiary,
            taskDataRepository: task,
            beneficiaryType: beneficiaryType,
            sideEffectDataRepository: sideEffect,
            addressRepository: addressRepository,
            referralDataRepository: referral,
            individualGlobalSearchRepository: individualGlobalSearchRepository,
            houseHoldGlobalSearchRepository: houseHoldGlobalSearchRepository,
          ),
        ),
        Provider<SearchBlocWrapper>(
          create: (ctx) => SearchBlocWrapper(
            searchHouseholdsBloc: ctx.read<SearchHouseholdsBloc>(),
            tagSearchBloc: ctx.read<TagSearchBloc>(),
            individualGlobalSearchBloc: ctx.read<IndividualGlobalSearchBloc>(),
            houseHoldGlobalSearchBloc: ctx.read<HouseHoldGlobalSearchBloc>(),
          ),
        ),
        BlocProvider(
          create: (_) => LocationBloc(location: Location()),
        ),
        BlocProvider(
          create: (_) => ServiceDefinitionBloc(
            const ServiceDefinitionEmptyState(),
            serviceDefinitionDataRepository: serviceDefinition,
          )..add(const ServiceDefinitionFetchEvent()),
        ),
      ],
      child: Theme(
        data: squareTheme,
        child: _BednetLocationPrewarm(child: this),
      ),
    );
  }
}

/// Dispatches [LoadLocationEvent] once when the bednet shell builds so
/// [SearchBeneficiaryPage]'s proximity switch (shown when latitude is set) is
/// not delayed until after navigating from [BeneficiaryTypeSelectionPage].
class _BednetLocationPrewarm extends StatefulWidget {
  const _BednetLocationPrewarm({required this.child});

  final Widget child;

  @override
  State<_BednetLocationPrewarm> createState() => _BednetLocationPrewarmState();
}

class _BednetLocationPrewarmState extends State<_BednetLocationPrewarm> {
  bool _dispatched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dispatched) return;
    _dispatched = true;
    context.read<LocationBloc>().add(const LoadLocationEvent());
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
