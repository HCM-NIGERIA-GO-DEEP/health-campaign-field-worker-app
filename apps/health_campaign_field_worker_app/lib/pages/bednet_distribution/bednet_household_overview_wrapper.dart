import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data/repositories/package_repository/oplog/oplog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'package:survey_form/survey_form.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import '../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../blocs/registration_deliver/search_households/household_global_seach.dart';
import '../../blocs/registration_deliver/search_households/individual_global_search.dart';
import '../../blocs/registration_deliver/search_households/search_bloc_common_wrapper.dart';
import '../../blocs/registration_deliver/search_households/search_households.dart';
import '../../blocs/registration_deliver/search_households/tag_by_search.dart';
import '../../data/registration_deliver_repo/local/household_global_search.dart';
import '../../data/registration_deliver_repo/local/individual_global_search.dart';
import '../../data/registration_deliver_repo/local/registration_delivery_address.dart';
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/utils.dart';

@RoutePage()
class BednetHouseholdOverviewWrapperPage extends StatelessWidget
    implements AutoRouteWrapper {
  const BednetHouseholdOverviewWrapperPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    final school = context.read<BednetDistributionBloc>().state.selectedSchool;
    if (school == null) {
      return const Material(
        child: Center(child: Text('No school selected')),
      );
    }

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

    final individual =
        context.repository<IndividualModel, IndividualSearchModel>(context);
    final household =
        context.repository<HouseholdModel, HouseholdSearchModel>(context);
    final householdMember = context
        .repository<HouseholdMemberModel, HouseholdMemberSearchModel>(context);
    final projectBeneficiary = context.repository<
        ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>(context);
    final task = context.repository<TaskModel, TaskSearchModel>(context);
    final sideEffect =
        context.repository<SideEffectModel, SideEffectSearchModel>(context);
    final referral =
        context.repository<ReferralModel, ReferralSearchModel>(context);
    final serviceDefinition = context.repository<ServiceDefinitionModel,
        ServiceDefinitionSearchModel>(context);

    final taskBeneficiaryRefs = beneficiaryType == BeneficiaryType.individual
        ? null
        : <String>[school.clientReferenceId];

    return MultiBlocProvider(
      providers: [
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
          create: (_) => ServiceDefinitionBloc(
            const ServiceDefinitionEmptyState(),
            serviceDefinitionDataRepository: serviceDefinition,
          )..add(const ServiceDefinitionFetchEvent()),
        ),
        BlocProvider(
          create: (_) => HouseholdOverviewBloc(
            HouseholdOverviewState(
              householdMemberWrapper: HouseholdMemberWrapper(household: school),
            ),
            projectBeneficiaryRepository: projectBeneficiary,
            householdRepository: household,
            individualRepository: individual,
            householdMemberRepository: householdMember,
            taskDataRepository: task,
            sideEffectDataRepository: sideEffect,
            referralDataRepository: referral,
            beneficiaryType: beneficiaryType,
            individualGlobalSearchRepository: individualGlobalSearchRepository,
          ),
        ),
        BlocProvider(
          create: (_) => DeliverInterventionBloc(
            const DeliverInterventionState(isEditing: false),
            taskRepository: task,
          )..add(
              DeliverInterventionSearchEvent(
                taskSearch: TaskSearchModel(
                  projectBeneficiaryClientReferenceId: taskBeneficiaryRefs,
                ),
              ),
            ),
        ),
      ],
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) => const AutoRouter();
}
