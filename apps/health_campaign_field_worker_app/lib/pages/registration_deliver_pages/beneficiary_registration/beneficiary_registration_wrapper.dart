// import 'package:auto_route/auto_route.dart';
// import 'package:digit_data_model/models/entities/individual.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
// import 'package:health_campaign_field_worker_app/blocs/registration_deliver/household_overview/household_overview.dart';
// import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_households.dart';
// import 'package:health_campaign_field_worker_app/data/registration_deliver_repo/local/individual_global_search.dart';
// import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/household.dart';
// import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/household_member.dart';
// import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/project_beneficiary.dart';
// import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/referral.dart';
// import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/task.dart';
// import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';

// import '../../../models/registration_deliver_model/entities/side_effect.dart';
// import '../../../utils/registration_deliver_utils/extensions/extensions.dart';

// @RoutePage()
// class BeneficiaryRegistrationWrapperPage extends StatelessWidget
//     implements AutoRouteWrapper {
//   final BeneficiaryRegistrationState initialState;

//   const BeneficiaryRegistrationWrapperPage({
//     super.key,
//     required this.initialState,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return const AutoRouter();
//   }

//   @override
//   Widget wrappedRoute(BuildContext context) {
//     final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType;
//     final individual =
//         context.repository<IndividualModel, IndividualSearchModel>(context);

//     final household =
//         context.repository<HouseholdModel, HouseholdSearchModel>(context);

//     final householdMember = context
//         .repository<HouseholdMemberModel, HouseholdMemberSearchModel>(context);

//     final projectBeneficiary = context.repository<ProjectBeneficiaryModel,
//         ProjectBeneficiarySearchModel>(context);
//     final task = context.repository<TaskModel, TaskSearchModel>(context);
//     final sideEffect =
//         context.repository<SideEffectModel, SideEffectSearchModel>(context);
//     final referral =
//         context.repository<ReferralModel, ReferralSearchModel>(context);

//     final individualGlobalSearch =
//         context.read<IndividualGlobalSearchRepository>();

//     return BlocProvider(
//       create: (_) => HouseholdOverviewBloc(
//           HouseholdOverviewState(
//             householdMemberWrapper: HouseholdMemberWrapper(
//               household: initialState.householdModel,
//               headOfHousehold: initialState.maybeWhen(
//                   orElse: () => null,
//                   editHousehold: (addressModel,
//                           householdModel,
//                           individualModel,
//                           registrationDate,
//                           projectBeneficiaryModel,
//                           loading,
//                           headOfHousehold) =>
//                       headOfHousehold),
//               members: initialState.maybeWhen(
//                 orElse: () => null,
//                 editHousehold: (addressModel,
//                         householdModel,
//                         individualModel,
//                         registrationDate,
//                         projectBeneficiaryModel,
//                         loading,
//                         headOfHousehold) =>
//                     individualModel,
//               ),
//               projectBeneficiaries: initialState.maybeWhen(
//                 orElse: () => null,
//                 editHousehold: (addressModel,
//                         householdModel,
//                         individualModel,
//                         registrationDate,
//                         projectBeneficiaryModel,
//                         loading,
//                         headOfHousehold) =>
//                     projectBeneficiaryModel != null
//                         ? [projectBeneficiaryModel]
//                         : [],
//               ),
//             ),
//           ),
//           individualRepository: individual,
//           householdRepository: household,
//           householdMemberRepository: householdMember,
//           projectBeneficiaryRepository: projectBeneficiary,
//           beneficiaryType: RegistrationDeliverySingleton().beneficiaryType!,
//           taskDataRepository: task,
//           sideEffectDataRepository: sideEffect,
//           individualGlobalSearchRepository: individualGlobalSearch,
//           referralDataRepository: referral
//           )
//         ..add(HouseholdOverviewReloadEvent(
//             projectId: RegistrationDeliverySingleton().selectedProject!.id,
//             projectBeneficiaryType:
//                 RegistrationDeliverySingleton().beneficiaryType!)),
//       child: BlocProvider(
//         create: (context) => BeneficiaryRegistrationBloc(
//           initialState,
//           individualRepository: individual,
//           householdRepository: household,
//           householdMemberRepository: householdMember,
//           projectBeneficiaryRepository: projectBeneficiary,
//           taskDataRepository: task,
//           beneficiaryType: beneficiaryType!,
//         ),
//         child: this,
//       ),
//     );
//   }
// }
