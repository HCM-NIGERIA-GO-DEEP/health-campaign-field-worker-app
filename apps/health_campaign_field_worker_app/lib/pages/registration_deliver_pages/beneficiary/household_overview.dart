import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/household_type.dart';
import 'package:digit_ui_components/enum/app_enums.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/theme/digit_theme.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:digit_ui_components/widgets/atoms/digit_action_card.dart';
import 'package:digit_ui_components/widgets/atoms/digit_button.dart';
import 'package:digit_ui_components/widgets/atoms/digit_chip.dart';
import 'package:digit_ui_components/widgets/atoms/digit_search_bar.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:digit_ui_components/widgets/scrollable_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import '../../../models/bednet_distribution/bednet_distribution_models.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/status.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/back_navigation_help_header.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/status_filter/status_filter.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/table_card/table_card.dart';
import 'package:survey_form/survey_form.dart';

import '../../../router/app_router.dart';
import '../../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../../blocs/registration_deliver/search_households/search_bloc_common_wrapper.dart';
import '../../../blocs/registration_deliver/search_households/search_households.dart';
import '../../../models/registration_deliver_model/entities/registration_delivery_enums.dart';
import '../../../utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import '../../../widgets/registartion_deliver/member_card/member_card.dart';

@RoutePage()
class HouseholdOverviewPage extends LocalizedStatefulWidget {
  const HouseholdOverviewPage({super.key, super.appLocalizations});

  @override
  State<HouseholdOverviewPage> createState() => _HouseholdOverviewPageState();
}

class _HouseholdOverviewPageState
    extends LocalizedState<HouseholdOverviewPage> {
  final TextEditingController searchController = TextEditingController();
  int offset = 0;
  int limit = 1000;

  String? householdClientReferenceId;

  List<String> selectedFilters = [];

  @override
  void initState() {
    callReloadEvent(offset: offset, limit: limit);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType!;
    final textTheme = theme.digitTextTheme(context);

    return PopScope(
      onPopInvoked: (didPop) async {
        context
            .read<SearchBlocWrapper>()
            .searchHouseholdsBloc
            .add(const SearchHouseholdsClearEvent());
        context.router.maybePop();
      },
      child: BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
        builder: (ctx, state) {
          return Scaffold(
            body: state.loading
                ? const Center(child: CircularProgressIndicator())
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollUpdateNotification) {
                        final metrics = scrollNotification.metrics;
                        if (metrics.atEdge && metrics.pixels != 0) {
                          if (state.offset != null) {
                            callReloadEvent(
                                offset: state.offset ?? 0, limit: limit);
                          }
                        }
                      }
                      //Return true to allow the notification to continue to be dispatched to further ancestors.
                      return true;
                    },
                    child: ScrollableContent(
                      header: Padding(
                        padding: const EdgeInsets.only(bottom: spacer2),
                        child: BackNavigationHelpHeaderWidget(
                          handleBack: () {
                            context
                                .read<SearchHouseholdsBloc>()
                                .add(const SearchHouseholdsEvent.clear());
                          },
                        ),
                      ),
                      enableFixedDigitButton: true,
                      footer: DigitCard(
                        margin: const EdgeInsets.only(top: spacer2),
                        children: [
                          DigitButton(
                            mainAxisSize: MainAxisSize.max,
                            onPressed: () => addIndividual(
                              context,
                              state.householdMemberWrapper.household!,
                            ),
                            label: localizations.translate(
                              i18.householdOverView
                                  .householdOverViewAddStudentText,
                            ),
                            type: DigitButtonType.primary,
                            size: DigitButtonSize.large,
                          )
                        ],
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              // Padding(
                              //   padding: const EdgeInsets.all(spacer2),
                              //   child: Text(
                              //     localizations.translate(i18.householdOverView
                              //         .householdOverViewChildLabel),
                              //     style: textTheme.headingM.copyWith(
                              //         color: theme.colorTheme.primary.primary2),
                              //   ),
                              // ),
                              // Padding(
                              //   padding: const EdgeInsets.only(
                              //       top: spacer2,
                              //       bottom: spacer4,
                              //       left: spacer2,
                              //       right: spacer2),
                              //   child: Row(
                              //     children: [
                              //       Expanded(
                              //         child: DigitSearchBar(
                              //           controller: searchController,
                              //           hintText: localizations.translate(
                              //             i18.common.searchByName,
                              //           ),
                              //           textCapitalization:
                              //               TextCapitalization.words,
                              //           onChanged: (value) {
                              //             if (value.length >= 3) {
                              //               callReloadEvent(
                              //                   offset: 0, limit: 10);
                              //             } else if (searchController
                              //                 .value.text.isEmpty) {
                              //               callReloadEvent(
                              //                   offset: 0, limit: 10);
                              //             }
                              //           },
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                              // ),
                              DigitCard(
                                  margin: const EdgeInsets.all(spacer2),
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        if ((state.householdMemberWrapper
                                                    .projectBeneficiaries ??
                                                [])
                                            .isNotEmpty)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: DigitButton(
                                              onPressed: () {
                                                final projectId =
                                                    RegistrationDeliverySingleton()
                                                        .projectId!;

                                                final bloc = context.read<
                                                    HouseholdOverviewBloc>();
                                                bloc.add(
                                                  HouseholdOverviewReloadEvent(
                                                    projectId: projectId,
                                                    projectBeneficiaryType:
                                                        beneficiaryType,
                                                  ),
                                                );
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) =>
                                                      DigitActionCard(
                                                    actions: [
                                                      DigitButton(
                                                        capitalizeLetters:
                                                            false,
                                                        prefixIcon: Icons.edit,
                                                        label: (RegistrationDeliverySingleton()
                                                                    .householdType ==
                                                                HouseholdType
                                                                    .community)
                                                            ? localizations
                                                                .translate(i18
                                                                    .householdOverView
                                                                    .clfOverViewEditLabel)
                                                            : localizations
                                                                .translate(
                                                                i18.householdOverView
                                                                    .householdOverViewEditLabel,
                                                              ),
                                                        type: DigitButtonType
                                                            .secondary,
                                                        size: DigitButtonSize
                                                            .large,
                                                        onPressed: () async {
                                                          Navigator.of(
                                                            context,
                                                            rootNavigator: true,
                                                          ).pop();

                                                          HouseholdMemberWrapper
                                                              wrapper = state
                                                                  .householdMemberWrapper;

                                                          final timestamp = wrapper
                                                              .headOfHousehold
                                                              ?.clientAuditDetails
                                                              ?.createdTime;
                                                          final date = DateTime
                                                              .fromMillisecondsSinceEpoch(
                                                            timestamp ??
                                                                DateTime.now()
                                                                    .millisecondsSinceEpoch,
                                                          );

                                                          final address =
                                                              wrapper.household
                                                                  ?.address;

                                                          if (address == null)
                                                            return;

                                                          final projectBeneficiary = state
                                                              .householdMemberWrapper
                                                              .projectBeneficiaries
                                                              ?.firstWhereOrNull(
                                                            (element) =>
                                                                element
                                                                    .beneficiaryClientReferenceId ==
                                                                wrapper
                                                                    .household
                                                                    ?.clientReferenceId,
                                                          );

                                                          // await context.router.root
                                                          //     .push(
                                                          //   BeneficiaryRegistrationWrapperRoute(
                                                          //     initialState:
                                                          //         BeneficiaryRegistrationEditHouseholdState(
                                                          //       addressModel:
                                                          //           address,
                                                          //       individualModel: state
                                                          //               .householdMemberWrapper
                                                          //               .members ??
                                                          //           [],
                                                          //       householdModel: state
                                                          //           .householdMemberWrapper
                                                          //           .household!,
                                                          //       registrationDate:
                                                          //           date,
                                                          //       projectBeneficiaryModel:
                                                          //           projectBeneficiary,
                                                          //     ),
                                                          //     children: [
                                                          //       HouseholdLocationRoute(),
                                                          //     ],
                                                          //   ),
                                                          // );
                                                          callReloadEvent(
                                                              offset: 0,
                                                              limit: 10);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              label: (RegistrationDeliverySingleton()
                                                          .householdType ==
                                                      HouseholdType.community)
                                                  ? localizations.translate(i18
                                                      .householdOverView
                                                      .clfOverViewEditIconText)
                                                  : localizations.translate(
                                                      i18.householdOverView
                                                          .householdOverViewEditIconText,
                                                    ),
                                              type: DigitButtonType.tertiary,
                                              size: DigitButtonSize.medium,
                                              prefixIcon: Icons.edit,
                                              capitalizeLetters: false,
                                            ),
                                          ),

                                        ///Old UI Format
                                        // BlocBuilder<DeliverInterventionBloc,
                                        //     DeliverInterventionState>(
                                        //   builder: (ctx, deliverInterventionState) =>
                                        //       Offstage(
                                        //     offstage: beneficiaryType ==
                                        //         BeneficiaryType.individual,
                                        //     child: Align(
                                        //       alignment: Alignment.centerLeft,
                                        //       child: DigitIconButton(
                                        //         icon: getStatusAttributes(state,
                                        //             deliverInterventionState)['icon'],
                                        //         iconText: localizations.translate(
                                        //           getStatusAttributes(state,
                                        //                   deliverInterventionState)[
                                        //               'textLabel'],
                                        //         ), // [TODO: map task status accordingly based on projectBeneficiaries and tasks]
                                        //         iconTextColor: getStatusAttributes(state,
                                        //             deliverInterventionState)['color'],
                                        //         iconColor: getStatusAttributes(state,
                                        //             deliverInterventionState)['color'],
                                        //       ),
                                        //     ),
                                        //   ),
                                        // ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.all(spacer2),
                                            child: Text(
                                              RegistrationDeliverySingleton()
                                                              .householdType !=
                                                          null &&
                                                      RegistrationDeliverySingleton()
                                                              .householdType ==
                                                          HouseholdType
                                                              .community
                                                  ? localizations.translate(i18
                                                      .householdOverView
                                                      .clfOverviewLabel)
                                                  : localizations.translate(i18
                                                      .householdOverView
                                                      .householdOverViewLabel),
                                              style: textTheme.headingXl
                                                  .copyWith(
                                                      color: theme.colorTheme
                                                          .primary.primary2),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: spacer2,
                                            right: spacer2,
                                          ),
                                          child: BlocBuilder<
                                                  DeliverInterventionBloc,
                                                  DeliverInterventionState>(
                                              builder: (ctx,
                                                  deliverInterventionState) {
                                            bool shouldShowStatus =
                                                beneficiaryType ==
                                                    BeneficiaryType.household;

                                            if (RegistrationDeliverySingleton()
                                                    .householdType ==
                                                HouseholdType.community) {
                                              return Column(
                                                children: [
                                                  DigitTableCard(element: {
                                                    localizations.translate(i18
                                                        .householdOverView
                                                        .instituteNameLabel): state
                                                            .householdMemberWrapper
                                                            .household
                                                            ?.address
                                                            ?.buildingName ??
                                                        localizations.translate(
                                                            i18.common
                                                                .coreCommonNA),
                                                    localizations.translate(
                                                      i18.deliverIntervention
                                                          .memberCountText,
                                                    ): state
                                                        .householdMemberWrapper
                                                        .household
                                                        ?.memberCount,
                                                    localizations.translate(
                                                      i18.householdLocation
                                                          .administrationAreaFormLabel,
                                                    ): localizations.translate(state
                                                            .householdMemberWrapper
                                                            .headOfHousehold
                                                            ?.address
                                                            ?.first
                                                            .locality
                                                            ?.code ??
                                                        i18.common
                                                            .coreCommonNA),
                                                  }),
                                                ],
                                              );
                                            }

                                            return Column(
                                              children: [
                                                DigitTableCard(
                                                  element: {
                                                    localizations.translate(i18
                                                            .householdOverView
                                                            .householdOverViewHouseholdHeadNameLabel):
                                                        () {
                                                      final headName =
                                                          bednetHouseholdHeadDisplayName(
                                                        household: state
                                                            .householdMemberWrapper
                                                            .household,
                                                        headOfHousehold: state
                                                            .householdMemberWrapper
                                                            .headOfHousehold,
                                                      );
                                                      return headName.isNotEmpty
                                                          ? headName
                                                          : localizations
                                                              .translate(
                                                              i18.common
                                                                  .coreCommonNA,
                                                            );
                                                    }(),
                                                    localizations.translate(
                                                      i18.householdLocation
                                                          .administrationAreaFormLabel,
                                                    ): () {
                                                      final localityCode = state
                                                          .householdMemberWrapper
                                                          .headOfHousehold
                                                          ?.address
                                                          ?.first
                                                          .locality
                                                          ?.code;
                                                      if (localityCode !=
                                                              null &&
                                                          localityCode
                                                              .isNotEmpty) {
                                                        return localizations
                                                            .translate(
                                                                localityCode);
                                                      }
                                                      final community = state
                                                          .householdMemberWrapper
                                                          .household
                                                          ?.bednetCommunity
                                                          .trim();
                                                      if (community != null &&
                                                          community
                                                              .isNotEmpty &&
                                                          community != '—') {
                                                        return community;
                                                      }
                                                      return localizations
                                                          .translate(
                                                        i18.common.coreCommonNA,
                                                      );
                                                    }(),
                                                    localizations.translate(
                                                      i18.deliverIntervention
                                                          .memberCountText,
                                                    ): state
                                                            .householdMemberWrapper
                                                            .household
                                                            ?.memberCount ??
                                                        state
                                                            .householdMemberWrapper
                                                            .household
                                                            ?.bednetPupilCount,
                                                    if (shouldShowStatus)
                                                      localizations.translate(i18
                                                              .beneficiaryDetails
                                                              .status):
                                                          localizations
                                                              .translate(
                                                        getStatusAttributes(
                                                                state,
                                                                deliverInterventionState)[
                                                            'textLabel'],
                                                      )
                                                  },
                                                ),
                                              ],
                                            );
                                          }),
                                        ),

                                        Column(
                                          children: (state
                                                      .householdMemberWrapper
                                                      .members ??
                                                  [])
                                              .map(
                                            (e) {
                                              final wrapper =
                                                  state.householdMemberWrapper;
                                              final isHead = wrapper
                                                          .headOfHousehold
                                                          ?.clientReferenceId ==
                                                      e.clientReferenceId ||
                                                  _isBednetSchoolHeadMember(
                                                    e,
                                                    wrapper.household,
                                                    wrapper.headOfHousehold,
                                                  );
                                              final projectBeneficiaryId = state
                                                  .householdMemberWrapper
                                                  .projectBeneficiaries
                                                  ?.firstWhereOrNull((b) =>
                                                      b.beneficiaryClientReferenceId ==
                                                      e.clientReferenceId)
                                                  ?.clientReferenceId;

                                              final projectBeneficiary = state
                                                  .householdMemberWrapper
                                                  .projectBeneficiaries
                                                  ?.where(
                                                    (element) =>
                                                        element
                                                            .beneficiaryClientReferenceId ==
                                                        (RegistrationDeliverySingleton()
                                                                    .beneficiaryType ==
                                                                BeneficiaryType
                                                                    .individual
                                                            ? e
                                                                .clientReferenceId
                                                            : state
                                                                .householdMemberWrapper
                                                                .household
                                                                ?.clientReferenceId),
                                                  )
                                                  .toList();

                                              final taskData = (projectBeneficiary ??
                                                          [])
                                                      .isNotEmpty
                                                  ? state.householdMemberWrapper
                                                      .tasks
                                                      ?.where((element) =>
                                                          element
                                                              .projectBeneficiaryClientReferenceId ==
                                                          projectBeneficiary
                                                              ?.first
                                                              .clientReferenceId)
                                                      .toList()
                                                  : null;
                                              final referralData =
                                                  (projectBeneficiary ?? [])
                                                          .isNotEmpty
                                                      ? state
                                                          .householdMemberWrapper
                                                          .referrals
                                                          ?.where((element) =>
                                                              element
                                                                  .projectBeneficiaryClientReferenceId ==
                                                              projectBeneficiary
                                                                  ?.first
                                                                  .clientReferenceId)
                                                          .toList()
                                                      : null;
                                              final sideEffectData = taskData !=
                                                          null &&
                                                      taskData.isNotEmpty
                                                  ? state.householdMemberWrapper
                                                      .sideEffects
                                                      ?.where((element) =>
                                                          element
                                                              .taskClientReferenceId ==
                                                          taskData.lastOrNull
                                                              ?.clientReferenceId)
                                                      .toList()
                                                  : null;
                                              final ageInYears = e
                                                          .dateOfBirth !=
                                                      null
                                                  ? DigitDateUtils.calculateAge(
                                                      DigitDateUtils
                                                              .getFormattedDateToDateTime(
                                                            e.dateOfBirth!,
                                                          ) ??
                                                          DateTime.now(),
                                                    ).years
                                                  : 0;
                                              final ageInMonths = e
                                                          .dateOfBirth !=
                                                      null
                                                  ? DigitDateUtils.calculateAge(
                                                      DigitDateUtils
                                                              .getFormattedDateToDateTime(
                                                            e.dateOfBirth!,
                                                          ) ??
                                                          DateTime.now(),
                                                    ).months
                                                  : 0;
                                              final currentCycle =
                                                  RegistrationDeliverySingleton()
                                                      .projectType
                                                      ?.cycles
                                                      ?.firstWhereOrNull(
                                                        (e) =>
                                                            (e.startDate) <
                                                                DateTime.now()
                                                                    .millisecondsSinceEpoch &&
                                                            (e.endDate) >
                                                                DateTime.now()
                                                                    .millisecondsSinceEpoch,
                                                      );

                                              final isBeneficiaryRefused =
                                                  checkIfBeneficiaryRefused(
                                                taskData,
                                              );
                                              final isBeneficiaryReferred =
                                                  checkIfBeneficiaryReferred(
                                                referralData,
                                                currentCycle,
                                              );

                                              return MemberCard(
                                                isHead: isHead,
                                                individual: e,
                                                projectBeneficiaries:
                                                    projectBeneficiary ?? [],
                                                tasks: taskData,
                                                sideEffects: sideEffectData,
                                                editMemberAction: () async {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop();

                                                  final address = e.address;
                                                  if (address == null ||
                                                      address.isEmpty) {
                                                    return;
                                                  }

                                                  final projectBeneficiaryModel =
                                                      state
                                                          .householdMemberWrapper
                                                          .projectBeneficiaries
                                                          ?.firstWhereOrNull(
                                                    (element) =>
                                                        element
                                                            .beneficiaryClientReferenceId ==
                                                        (RegistrationDeliverySingleton()
                                                                    .beneficiaryType ==
                                                                BeneficiaryType
                                                                    .individual
                                                            ? e
                                                                .clientReferenceId
                                                            : state
                                                                .householdMemberWrapper
                                                                .household
                                                                ?.clientReferenceId),
                                                  );

                                                  await context.router.push(
                                                    BednetIndividualDetailsWrapperRoute(
                                                      householdModel: state
                                                          .householdMemberWrapper
                                                          .household!,
                                                      addressModel:
                                                          address.first,
                                                      individualModel: e,
                                                      projectBeneficiaryModel:
                                                          projectBeneficiaryModel,
                                                      isHeadOfHousehold: isHead,
                                                    ),
                                                  );

                                                  callReloadEvent(
                                                      offset: 0, limit: 10);
                                                },
                                                setAsHeadAction: () {
                                                  ctx
                                                      .read<
                                                          HouseholdOverviewBloc>()
                                                      .add(
                                                        HouseholdOverviewSetAsHeadEvent(
                                                          individualModel: e,
                                                          projectId:
                                                              RegistrationDeliverySingleton()
                                                                  .projectId!,
                                                          householdModel: state
                                                              .householdMemberWrapper
                                                              .household!,
                                                          projectBeneficiaryType:
                                                              beneficiaryType,
                                                        ),
                                                      );

                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop();
                                                },
                                                deleteMemberAction: () {
                                                  showCustomPopup(
                                                    context: context,
                                                    builder: (BuildContext
                                                            context) =>
                                                        Popup(
                                                            title: localizations
                                                                .translate(i18
                                                                    .householdOverView
                                                                    .householdOverViewActionCardTitle),
                                                            type: PopUpType
                                                                .simple,
                                                            actions: [
                                                          DigitButton(
                                                              label: localizations
                                                                  .translate(i18
                                                                      .householdOverView
                                                                      .householdOverViewPrimaryActionLabel),
                                                              onPressed: () {
                                                                Navigator.of(
                                                                  context,
                                                                  rootNavigator:
                                                                      true,
                                                                )
                                                                  ..pop()
                                                                  ..pop();
                                                                context
                                                                    .read<
                                                                        HouseholdOverviewBloc>()
                                                                    .add(
                                                                      HouseholdOverviewEvent
                                                                          .selectedIndividual(
                                                                        individualModel:
                                                                            e,
                                                                      ),
                                                                    );
                                                                // context.router.push(
                                                                //   ReasonForDeletionRoute(
                                                                //     isHousholdDelete:
                                                                //         false,
                                                                //   ),
                                                                // );
                                                              },
                                                              type:
                                                                  DigitButtonType
                                                                      .primary,
                                                              size:
                                                                  DigitButtonSize
                                                                      .large),
                                                          DigitButton(
                                                              label: localizations
                                                                  .translate(i18
                                                                      .householdOverView
                                                                      .householdOverViewSecondaryActionLabel),
                                                              onPressed: () {
                                                                Navigator.of(
                                                                  context,
                                                                  rootNavigator:
                                                                      true,
                                                                ).pop();
                                                              },
                                                              type:
                                                                  DigitButtonType
                                                                      .tertiary,
                                                              size:
                                                                  DigitButtonSize
                                                                      .large)
                                                        ]),
                                                  );
                                                },
                                                isNotEligible:
                                                    // RegistrationDeliverySingleton()
                                                    //             .projectType
                                                    //             ?.cycles !=
                                                    //         null
                                                    //     ? !checkEligibilityForAgeAndSideEffect(
                                                    //         DigitDOBAgeConvertor(
                                                    //           years: ageInYears,
                                                    //           months:
                                                    //               ageInMonths,
                                                    //         ),
                                                    //         RegistrationDeliverySingleton()
                                                    //             .projectType,
                                                    //         (taskData ?? [])
                                                    //                 .isNotEmpty
                                                    //             ? taskData
                                                    //                 ?.lastOrNull
                                                    //             : null,
                                                    //         sideEffectData,
                                                    //       )
                                                    //     : 
                                                        false,
                                                name: e.name?.givenName ??
                                                    ' - - ',
                                                years: (e.dateOfBirth == null
                                                    ? null
                                                    : DigitDateUtils
                                                        .calculateAge(
                                                        DigitDateUtils
                                                                .getFormattedDateToDateTime(
                                                              e.dateOfBirth!,
                                                            ) ??
                                                            DateTime.now(),
                                                      ).years),
                                                months: (e.dateOfBirth == null
                                                    ? null
                                                    : DigitDateUtils
                                                        .calculateAge(
                                                        DigitDateUtils
                                                                .getFormattedDateToDateTime(
                                                              e.dateOfBirth!,
                                                            ) ??
                                                            DateTime.now(),
                                                      ).months),
                                                gender: e.gender?.name,
                                                // isBeneficiaryRefused:
                                                //     isBeneficiaryRefused &&
                                                //         !checkStatus(
                                                //           taskData,
                                                //           currentCycle,
                                                //         ),
                                                // isBeneficiaryReferred:
                                                //     isBeneficiaryReferred,
                                                isDelivered: taskData == null
                                                    ? false
                                                    : taskData.isNotEmpty &&
                                                            !checkStatus(
                                                              taskData,
                                                              currentCycle,
                                                            )
                                                        ? true
                                                        : false,
                                                localizations: localizations,
                                                projectBeneficiaryClientReferenceId:
                                                    projectBeneficiaryId,
                                              );
                                            },
                                          ).toList(),
                                        ),
                                      ],
                                    ),
                                    // DigitButton(
                                    //   mainAxisSize: MainAxisSize.max,
                                    //   onPressed: () => addIndividual(
                                    //     context,
                                    //     state.householdMemberWrapper.household!,
                                    //   ),
                                    //   label: localizations.translate(
                                    //     i18.householdOverView
                                    //         .householdOverViewAddActionText,
                                    //   ),
                                    //   prefixIcon: Icons.add_circle,
                                    //   type: DigitButtonType.tertiary,
                                    //   size: DigitButtonSize.large,
                                    // ),
                                  ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  addIndividual(BuildContext context, HouseholdModel household) async {
    final address = household.address;

    if (address == null) return;

    await context.router.push(
      BednetIndividualDetailsWrapperRoute(
        householdModel: household,
        addressModel: address,
      ),
    );
  }

  bool isOutsideProjectDateRange() {
    final project = RegistrationDeliverySingleton().selectedProject;

    if (project?.startDate != null && project?.endDate != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final startDate = project!.startDate!;
      final endDate = project.endDate!;

      return now < startDate || now > endDate;
    }

    return false;
  }

  getStatusAttributes(HouseholdOverviewState state,
      DeliverInterventionState deliverInterventionState) {
    var textLabel =
        i18.householdOverView.householdOverViewNotRegisteredIconLabel;
    var color = DigitTheme.instance.colorScheme.error;
    var icon = Icons.info_rounded;

    if ((state.householdMemberWrapper.projectBeneficiaries ?? []).isNotEmpty) {
      textLabel = state.householdMemberWrapper.tasks?.isNotEmpty ?? false
          ? getTaskStatus(state.householdMemberWrapper.tasks ?? []).toValue() ==
                  Status.administeredSuccess.toValue()
              ? '${RegistrationDeliverySingleton().selectedProject!.projectType}_${getTaskStatus(state.householdMemberWrapper.tasks ?? []).toValue()}'
              : getTaskStatus(state.householdMemberWrapper.tasks ?? [])
                  .toValue()
          : Status.registered.toValue();

      color = state.householdMemberWrapper.tasks?.isNotEmpty ?? false
          ? (state.householdMemberWrapper.tasks?.lastOrNull?.status ==
                  Status.administeredSuccess.toValue()
              ? DigitTheme.instance.colorScheme.onSurfaceVariant
              : DigitTheme.instance.colorScheme.error)
          : DigitTheme.instance.colorScheme.onSurfaceVariant;

      icon = state.householdMemberWrapper.tasks?.isNotEmpty ?? false
          ? (state.householdMemberWrapper.tasks?.lastOrNull?.status ==
                  Status.administeredSuccess.toValue()
              ? Icons.check_circle
              : Icons.info_rounded)
          : Icons.check_circle;
    } else {
      textLabel = i18.householdOverView.householdOverViewNotRegisteredIconLabel;
      color = DigitTheme.instance.colorScheme.error;
      icon = Icons.info_rounded;
    }

    return {'textLabel': textLabel, 'color': color, 'icon': icon};
  }

  void navigateToChecklist(
      BuildContext ctx, String beneficiaryClientRefId) async {
    // await context.router.push(BeneficiaryChecklistRoute(
    // beneficiaryClientRefId: beneficiaryClientRefId));
  }

  void callReloadEvent({
    required int offset,
    required int limit,
  }) {
    if (mounted) {
      final bloc = context.read<HouseholdOverviewBloc>();

      bloc.add(
        HouseholdOverviewReloadEvent(
          projectId: RegistrationDeliverySingleton().projectId!,
          projectBeneficiaryType:
              RegistrationDeliverySingleton().beneficiaryType!,
          offset: offset,
          limit: limit,
          searchByName: searchController.text.trim().length > 2
              ? searchController.text.trim()
              : null,
          selectedFilter: selectedFilters,
        ),
      );
    }
  }

  getFilterIconNLabel() {
    return {
      'label': localizations.translate(
        i18.searchBeneficiary.filterLabel,
      ),
      'icon': Icons.filter_alt
    };
  }

  showFilterDialog() async {
    var filters = await showDialog(
        context: context,
        builder: (ctx) => Popup(
              title: getFilterIconNLabel()['label'],
              titleIcon: Icon(
                getFilterIconNLabel()['icon'],
                color: DigitTheme.instance.colorScheme.primary,
              ),
              onCrossTap: () {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop();
              },
              // additionalWidgets: [
              //   StatusFilter(
              //     selectedFilters: selectedFilters,
              //   ),
              // ]
            ));

    if (filters != null && filters.isNotEmpty) {
      selectedFilters.clear();
      selectedFilters.addAll(filters);
      callReloadEvent(offset: 0, limit: 10);
    } else {
      setState(() {
        selectedFilters = [];
      });

      callReloadEvent(offset: 0, limit: 10);
    }
  }

  String getStatus(String selectedFilter) {
    final statusMap = {
      Status.delivered.toValue(): Status.delivered,
      Status.notAdministered.toValue(): Status.notAdministered,
      Status.visited.toValue(): Status.visited,
      Status.notVisited.toValue(): Status.notVisited,
      Status.beneficiaryRefused.toValue(): Status.beneficiaryRefused,
      Status.beneficiaryReferred.toValue(): Status.beneficiaryReferred,
      Status.administeredSuccess.toValue(): Status.administeredSuccess,
      Status.administeredFailed.toValue(): Status.administeredFailed,
      Status.inComplete.toValue(): Status.inComplete,
      Status.toAdminister.toValue(): Status.toAdminister,
      Status.closeHousehold.toValue(): Status.closeHousehold,
      Status.registered.toValue(): Status.registered,
      Status.notRegistered.toValue(): Status.notRegistered,
    };

    var mappedStatus = statusMap.entries
        .where((element) => element.value.name == selectedFilter)
        .first
        .key;
    if (mappedStatus != null) {
      return mappedStatus;
    } else {
      return selectedFilter;
    }
  }

  /// When there is no DB head (e.g. school household), match [bednetSchoolHead] to a member's given name.
  bool _isBednetSchoolHeadMember(
    IndividualModel member,
    HouseholdModel? household,
    IndividualModel? headOfHousehold,
  ) {
    if (headOfHousehold != null) return false;
    if (household == null) return false;
    final schoolHead = household.bednetSchoolHead.trim();
    if (schoolHead.isEmpty || schoolHead == 'N/A') return false;
    final given = member.name?.givenName?.trim();
    if (given == null || given.isEmpty) return false;
    final sh = schoolHead.toLowerCase();
    final g = given.toLowerCase();
    return sh == g || sh.startsWith('$g ');
  }

  getFilters() {
    bool hasFilters;
    if (RegistrationDeliverySingleton().householdType ==
        HouseholdType.community) {
      hasFilters = RegistrationDeliverySingleton().searchCLFFilters != null &&
          RegistrationDeliverySingleton().searchCLFFilters!.isNotEmpty;
    } else {
      hasFilters =
          RegistrationDeliverySingleton().searchHouseHoldFilter != null &&
              RegistrationDeliverySingleton().searchHouseHoldFilter!.isNotEmpty;
    }
    return hasFilters;
  }
}
