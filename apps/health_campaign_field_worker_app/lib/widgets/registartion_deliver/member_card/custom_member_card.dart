import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/ComponentTheme/digit_tag_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/digit_action_card.dart';
import 'package:digit_ui_components/widgets/atoms/digit_tag.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../../blocs/registration_deliver/app_localization.dart';
import '../../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../../models/registration_deliver_model/entities/additional_fields_type.dart';
import '../../../models/registration_deliver_model/entities/status.dart';
import '../../../pages/bednet_distribution/bednet_household_review.dart';
import '../../../pages/registration_deliver_pages/beneficiary_registration/refer_beneficiary_page.dart'
    show contextIsCommunityDistributor;
import '../../../router/app_router.dart';
import '../../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../../utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import '../../../utils/registration_deliver_utils/utils.dart';

/// Reloads overview when the ITN [MaterialPageRoute] stack is closed (same
/// event shape as [HouseholdOverviewReloadEvent] elsewhere in this file).
void _reloadHouseholdOverviewAfterItnFlow(BuildContext context) {
  if (!context.mounted) return;
  final projectId = RegistrationDeliverySingleton().projectId;
  final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType;
  if (projectId == null || beneficiaryType == null) return;
  try {
    context.read<HouseholdOverviewBloc>().add(
          HouseholdOverviewReloadEvent(
            projectId: projectId,
            projectBeneficiaryType: beneficiaryType,
            offset: 0,
            limit: 1000,
          ),
        );
  } catch (_) {}
}

class CustomMemberCard extends StatelessWidget {
  final String name;
  final String? gender;
  final int? years;
  final int? months;
  final bool isHead;
  final IndividualModel individual;
  final List<ProjectBeneficiaryModel>? projectBeneficiaries;
  final bool isDelivered;

  final VoidCallback setAsHeadAction;
  final VoidCallback editMemberAction;
  final VoidCallback deleteMemberAction;
  final RegistrationDeliveryLocalization localizations;
  final List<TaskModel>? tasks;
  final List<SideEffectModel>? sideEffects;
  final bool isNotEligible;
  final bool isBeneficiaryRefused;
  final bool isBeneficiaryAbsent;
  final String? projectBeneficiaryClientReferenceId;
  final VoidCallback? tbAssessmentAction;

  /// Household context for "Deliver ITN" → [BednetHouseholdReviewPage] (non-school flow).
  final HouseholdModel? bednetHousehold;
  final String? bednetHeadDisplayName;
  final int? bednetMemberCount;
  final int? bednetChildrenUnder5Count;

  /// Household additional field `e-Token` (and fallback from project beneficiary tag).
  final String? bednetDeliveryEToken;

  const CustomMemberCard({
    super.key,
    required this.individual,
    required this.name,
    this.gender,
    this.years,
    this.isHead = false,
    this.months,
    required this.localizations,
    required this.isDelivered,
    required this.setAsHeadAction,
    required this.editMemberAction,
    required this.deleteMemberAction,
    this.projectBeneficiaries,
    this.tasks,
    this.isNotEligible = false,
    this.projectBeneficiaryClientReferenceId,
    this.isBeneficiaryRefused = false,
    this.isBeneficiaryAbsent = false,
    this.sideEffects,
    this.tbAssessmentAction,
    this.bednetHousehold,
    this.bednetHeadDisplayName,
    this.bednetMemberCount,
    this.bednetChildrenUnder5Count,
    this.bednetDeliveryEToken,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType;
    final textTheme = theme.digitTextTheme(context);

    final tbTask = tasks?.lastWhereOrNull((t) =>
        t.status == Status.beneficiaryReferred.toValue() ||
        t.status == 'INELIGIBLE');

    return DigitCard(
        margin: const EdgeInsets.only(bottom: spacer2),
        cardType: CardType.secondary,
        children: [
          Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 1.8,
                          child: Padding(
                            padding: const EdgeInsets.all(spacer2),
                            child: Text(
                              name,
                              style: textTheme.headingM,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _shouldShowEditButton(context) && !isHead
                        ? Positioned(
                            child: Align(
                              alignment: Alignment.topRight,
                              child: DigitButton(
                                isDisabled:
                                    (projectBeneficiaries ?? []).isEmpty,
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (ctx) => DigitActionCard(
                                    onOutsideTap: () {
                                      Navigator.of(context, rootNavigator: true)
                                          .pop();
                                    },
                                    actions: [
                                      // DigitButton(
                                      //   prefixIcon: Icons.person,
                                      //   label: (RegistrationDeliverySingleton()
                                      //               .householdType ==
                                      //           HouseholdType.community)
                                      //       ? localizations
                                      //           .translate(i18.memberCard.assignAsClfhead)
                                      //       : localizations.translate(
                                      //           i18.memberCard.assignAsHouseholdhead,
                                      //         ),
                                      //   isDisabled: isHead ? true : false,
                                      //   onPressed: setAsHeadAction,
                                      //   type: DigitButtonType.secondary,
                                      //   size: DigitButtonSize.large,
                                      // ),
                                      DigitButton(
                                        prefixIcon: Icons.edit,
                                        label: localizations.translate(
                                          i18.memberCard.editIndividualDetails,
                                        ),
                                        onPressed: editMemberAction,
                                        type: DigitButtonType.secondary,
                                        size: DigitButtonSize.large,
                                      ),
                                      // DigitButton(
                                      //   prefixIcon: Icons.delete,
                                      //   label: localizations.translate(
                                      //     i18.memberCard.deleteIndividualActionText,
                                      //   ),
                                      //   isDisabled: isHead ? true : false,
                                      //   onPressed: deleteMemberAction,
                                      //   type: DigitButtonType.secondary,
                                      //   size: DigitButtonSize.large,
                                      // ),
                                    ],
                                  ),
                                ),
                                label: localizations.translate(
                                  i18.memberCard.editDetails,
                                ),
                                prefixIcon: Icons.edit,
                                type: DigitButtonType.tertiary,
                                size: DigitButtonSize.medium,
                              ),
                            ),
                          )
                        : const Offstage(),
                  ],
                ),
                Offstage(
                  offstage: isHead ? true : false,
                  child: Padding(
                    padding: const EdgeInsets.all(spacer2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          gender != null
                              ? localizations.translate(
                                  'CORE_COMMON_${gender?.toUpperCase()}')
                              : ' -- ',
                          style: textTheme.bodyS,
                        ),
                        Expanded(
                          child: Text(
                            years != null && months != null
                                ? " | $years ${localizations.translate(i18.memberCard.deliverDetailsYearText)} $months ${localizations.translate(i18.memberCard.deliverDetailsMonthsText)}"
                                : "|   --",
                            style: textTheme.bodyS,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Offstage(
                  offstage: isHead ? false : true,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Tag(
                      isIcon: true,
                      label: 'Household Head',
                      themeData: TagThemeData(
                        errorColor: theme.colorTheme.primary.primary2,
                        errorIcon: Icon(
                          Icons.error,
                          color: theme.colorTheme.primary.primary2,
                          size: 16,
                        ),
                      ),
                      type: TagType.error,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(left: spacer1, bottom: spacer2),
                  child: Offstage(
                    offstage: (isHead
                            ? true
                            : beneficiaryType != BeneficiaryType.individual) ||
                        tbTask != null,
                    child: !isDelivered ||
                            isBeneficiaryAbsent ||
                            isBeneficiaryRefused
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Tag(
                              isIcon: true,
                              label: localizations.translate(
                                isBeneficiaryAbsent
                                    ? i18.householdOverView
                                        .householdOverViewAbsentIconLabel
                                    : isBeneficiaryRefused
                                        ? i18.householdOverView
                                            .householdOverViewRefusedIconLabel
                                        : i18.householdOverView
                                            .householdOverViewNotDeliveredIconLabel,
                              ),
                              type: TagType.error,
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Tag(
                              isIcon: true,
                              label: localizations.translate(
                                i18.householdOverView
                                    .householdOverViewDeliveredIconLabel,
                              ),
                              type: TagType.success,
                            ),
                          ),
                  ),
                ),
                Offstage(
                  offstage: isHead || isDelivered,
                  child: Padding(
                    padding: const EdgeInsets.all(spacer1),
                    child: Column(
                      children: [
                        () {
                          if (tbTask != null) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Tag(
                                isIcon: true,
                                label: localizations
                                    .translate(tbTask.status ?? ''),
                                themeData: tbTask.status ==
                                        Status.beneficiaryReferred.toValue()
                                    ? TagThemeData(
                                        errorColor:
                                            theme.colorTheme.primary.primary2,
                                        errorIcon: Icon(
                                          Icons.error,
                                          color:
                                              theme.colorTheme.primary.primary2,
                                          size: 16,
                                        ),
                                      )
                                    : null,
                                type: tbTask.status ==
                                        Status.beneficiaryReferred.toValue()
                                    ? TagType.error
                                    : TagType.success,
                              ),
                            );
                          }
                          if (isNotEligible) return const Offstage();

                          // Role-based button:
                          // COMMUNITY_DISTRIBUTOR → "TB Assessment" → BeneficiaryChecklist
                          // All other roles      → "Deliver Interventions" → BeneficiaryDetails
                          final isCommunityDistributor =
                              contextIsCommunityDistributor(context);

                          return DigitButton(
                            mainAxisSize: MainAxisSize.max,
                            isDisabled: (projectBeneficiaries ?? []).isEmpty
                                ? true
                                : false,
                            type: DigitButtonType.primary,
                            size: DigitButtonSize.medium,
                            label: isCommunityDistributor
                                ? 'TB assessment'
                                : localizations.translate(
                                    i18.householdOverView
                                        .studentRecordDeliveryLabel,
                                  ),
                            onPressed: () {
                              final bloc =
                                  context.read<HouseholdOverviewBloc>();

                              bloc.add(
                                HouseholdOverviewEvent.selectedIndividual(
                                  individualModel: individual,
                                ),
                              );
                              bloc.add(HouseholdOverviewReloadEvent(
                                projectId:
                                    RegistrationDeliverySingleton().projectId!,
                                projectBeneficiaryType:
                                    RegistrationDeliverySingleton()
                                            .beneficiaryType ??
                                        BeneficiaryType.individual,
                              ));

                              if (isCommunityDistributor &&
                                  tbAssessmentAction != null) {
                                // Household flow with MDT/CD user → TB checklist
                                tbAssessmentAction!();
                              } else {
                                // School flow or non-CD user → Deliver Interventions
                                context.router.push(
                                  BeneficiaryDetailsRoute(),
                                );
                              }
                            },
                          );
                        }(),
                        const SizedBox(
                          height: 10,
                        ),
                        // (isNotEligible ||
                        //         !checkStatus(
                        //           tasks,
                        //           context.selectedCycle,
                        //         ) ||
                        //         isBeneficiaryRefused ||
                        //         isBeneficiaryAbsent)
                        //     ? const Offstage()
                        //     : DigitButton(
                        //         label: localizations.translate(
                        //           i18.memberCard.unableToDeliverLabel,
                        //         ),
                        //         isDisabled: (projectBeneficiaries ?? []).isEmpty
                        //             ? true
                        //             : false,
                        //         type: DigitButtonType.secondary,
                        //         size: DigitButtonSize.medium,
                        //         mainAxisSize: MainAxisSize.max,
                        //         onPressed: () async {
                        //           await showDialog(
                        //             context: context,
                        //             builder: (ctx) => DigitActionCard(
                        //               onOutsideTap: () {
                        //                 Navigator.of(
                        //                   context,
                        //                   rootNavigator: true,
                        //                 ).pop();
                        //               },
                        //               actions: [
                        //                 DigitButton(
                        //                   label: localizations.translate(
                        //                     i18.memberCard
                        //                         .beneficiaryRefusedLabel,
                        //                   ),
                        //                   type: DigitButtonType.secondary,
                        //                   size: DigitButtonSize.large,
                        //                   onPressed: () async {
                        //                     Navigator.of(context,
                        //                             rootNavigator: true)
                        //                         .pop();
                        //                     context
                        //                         .read<DeliverInterventionBloc>()
                        //                         .add(
                        //                           DeliverInterventionSubmitEvent(
                        //                             task: TaskModel(
                        //                               projectBeneficiaryClientReferenceId:
                        //                                   projectBeneficiaryClientReferenceId,
                        //                               clientReferenceId:
                        //                                   IdGen.i.identifier,
                        //                               tenantId:
                        //                                   RegistrationDeliverySingleton()
                        //                                       .tenantId,
                        //                               rowVersion: 1,
                        //                               auditDetails:
                        //                                   AuditDetails(
                        //                                 createdBy:
                        //                                     RegistrationDeliverySingleton()
                        //                                         .loggedInUserUuid!,
                        //                                 createdTime: context
                        //                                     .millisecondsSinceEpoch(),
                        //                               ),
                        //                               projectId:
                        //                                   RegistrationDeliverySingleton()
                        //                                       .projectId,
                        //                               status: Status
                        //                                   .beneficiaryRefused
                        //                                   .toValue(),
                        //                               clientAuditDetails:
                        //                                   ClientAuditDetails(
                        //                                 createdBy:
                        //                                     RegistrationDeliverySingleton()
                        //                                         .loggedInUserUuid!,
                        //                                 createdTime: context
                        //                                     .millisecondsSinceEpoch(),
                        //                                 lastModifiedBy:
                        //                                     RegistrationDeliverySingleton()
                        //                                         .loggedInUserUuid,
                        //                                 lastModifiedTime: context
                        //                                     .millisecondsSinceEpoch(),
                        //                               ),
                        //                               additionalFields:
                        //                                   TaskAdditionalFields(
                        //                                 version: 1,
                        //                                 fields: [
                        //                                   AdditionalField(
                        //                                     'taskStatus',
                        //                                     Status
                        //                                         .beneficiaryRefused
                        //                                         .toValue(),
                        //                                   ),
                        //                                 ],
                        //                               ),
                        //                               address: individual
                        //                                   .address?.first,
                        //                             ),
                        //                             isEditing: false,
                        //                             boundaryModel:
                        //                                 RegistrationDeliverySingleton()
                        //                                     .boundary!,
                        //                           ),
                        //                         );
                        //                     await Future<void>.delayed(
                        //                       const Duration(milliseconds: 500),
                        //                     );
                        //                     if (!context.mounted) return;
                        //                     context
                        //                         .read<HouseholdOverviewBloc>()
                        //                         .add(
                        //                           HouseholdOverviewReloadEvent(
                        //                             projectId:
                        //                                 RegistrationDeliverySingleton()
                        //                                     .projectId!,
                        //                             projectBeneficiaryType:
                        //                                 RegistrationDeliverySingleton()
                        //                                     .beneficiaryType!,
                        //                           ),
                        //                         );
                        //                   },
                        //                 ),
                        //                 DigitButton(
                        //                   label: localizations.translate(
                        //                     i18.memberCard
                        //                         .beneficiaryAbsentLabel,
                        //                   ),
                        //                   type: DigitButtonType.secondary,
                        //                   size: DigitButtonSize.large,
                        //                   onPressed: () async {
                        //                     Navigator.of(context,
                        //                             rootNavigator: true)
                        //                         .pop();
                        //                     context
                        //                         .read<DeliverInterventionBloc>()
                        //                         .add(
                        //                           DeliverInterventionSubmitEvent(
                        //                             task: TaskModel(
                        //                               projectBeneficiaryClientReferenceId:
                        //                                   projectBeneficiaryClientReferenceId,
                        //                               clientReferenceId:
                        //                                   IdGen.i.identifier,
                        //                               tenantId:
                        //                                   RegistrationDeliverySingleton()
                        //                                       .tenantId,
                        //                               rowVersion: 1,
                        //                               auditDetails:
                        //                                   AuditDetails(
                        //                                 createdBy:
                        //                                     RegistrationDeliverySingleton()
                        //                                         .loggedInUserUuid!,
                        //                                 createdTime: context
                        //                                     .millisecondsSinceEpoch(),
                        //                               ),
                        //                               projectId:
                        //                                   RegistrationDeliverySingleton()
                        //                                       .projectId,
                        //                               status: Status
                        //                                   .beneficiaryAbsent
                        //                                   .toValue(),
                        //                               clientAuditDetails:
                        //                                   ClientAuditDetails(
                        //                                 createdBy:
                        //                                     RegistrationDeliverySingleton()
                        //                                         .loggedInUserUuid!,
                        //                                 createdTime: context
                        //                                     .millisecondsSinceEpoch(),
                        //                                 lastModifiedBy:
                        //                                     RegistrationDeliverySingleton()
                        //                                         .loggedInUserUuid,
                        //                                 lastModifiedTime: context
                        //                                     .millisecondsSinceEpoch(),
                        //                               ),
                        //                               additionalFields:
                        //                                   TaskAdditionalFields(
                        //                                 version: 1,
                        //                                 fields: [
                        //                                   AdditionalField(
                        //                                     'taskStatus',
                        //                                     Status
                        //                                         .beneficiaryAbsent
                        //                                         .toValue(),
                        //                                   ),
                        //                                 ],
                        //                               ),
                        //                               address: individual
                        //                                   .address?.first,
                        //                             ),
                        //                             isEditing: false,
                        //                             boundaryModel:
                        //                                 RegistrationDeliverySingleton()
                        //                                     .boundary!,
                        //                           ),
                        //                         );
                        //                     await Future<void>.delayed(
                        //                       const Duration(milliseconds: 500),
                        //                     );
                        //                     if (!context.mounted) return;
                        //                     context
                        //                         .read<HouseholdOverviewBloc>()
                        //                         .add(
                        //                           HouseholdOverviewReloadEvent(
                        //                             projectId:
                        //                                 RegistrationDeliverySingleton()
                        //                                     .projectId!,
                        //                             projectBeneficiaryType:
                        //                                 RegistrationDeliverySingleton()
                        //                                     .beneficiaryType!,
                        //                           ),
                        //                         );
                        //                   },
                        //                 ),
                        //                 // DigitButton(
                        //                 //   label: localizations.translate(
                        //                 //     i18.memberCard
                        //                 //         .referBeneficiaryLabel,
                        //                 //   ),
                        //                 //   type: DigitButtonType.secondary,
                        //                 //   size: DigitButtonSize.large,
                        //                 //   onPressed: () async {
                        //                 //     Navigator.of(
                        //                 //       context,
                        //                 //       rootNavigator: true,
                        //                 //     ).pop();
                        //                 //     await context.router.push(
                        //                 //       ReferBeneficiaryRoute(
                        //                 //         projectBeneficiaryClientRefId:
                        //                 //             projectBeneficiaryClientReferenceId ??
                        //                 //                 '',
                        //                 //       ),
                        //                 //     );
                        //                 //   },
                        //                 // ),
                        //                 // DigitButton(
                        //                 //   label: localizations.translate(
                        //                 //     i18.memberCard
                        //                 //         .recordAdverseEventsLabel,
                        //                 //   ),
                        //                 //   isDisabled: tasks != null &&
                        //                 //           (tasks ?? []).isNotEmpty
                        //                 //       ? false
                        //                 //       : true,
                        //                 //   type: DigitButtonType.secondary,
                        //                 //   size: DigitButtonSize.large,
                        //                 //   mainAxisSize: MainAxisSize.max,
                        //                 //   onPressed: () async {
                        //                 //     Navigator.of(
                        //                 //       context,
                        //                 //       rootNavigator: true,
                        //                 //     ).pop();
                        //                 //     // await context.router.push(
                        //                 //     //   SideEffectsRoute(
                        //                 //     //     tasks: tasks!,
                        //                 //     //   ),
                        //                 //     // );
                        //                 //   },
                        //                 // ),
                        //               ],
                        //             ),
                        //           );
                        //         },
                        //       ),
                      ],
                    ),
                  ),
                ),
                // Removed secondary TB Assessment button.
              ]),
          Offstage(
            offstage: !isHead,
            child: Padding(
              padding: const EdgeInsets.all(spacer1),
              child: isDelivered
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Tag(
                        isIcon: true,
                        label: localizations.translate(
                          i18.memberCard.itnDeliveredTagLabel,
                        ),
                        type: TagType.success,
                      ),
                    )
                  : DigitButton(
                      mainAxisSize: MainAxisSize.max,
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.medium,
                      label: 'Record ITN Delivery',
                      onPressed: () {
                        final household = bednetHousehold;
                        if (household != null) {
                          try {
                            context.read<BednetDistributionBloc>().add(
                                  BednetDistributionEvent.updateSelectedSchool(
                                    school: household,
                                  ),
                                );
                          } catch (_) {}
                        }

                        final headName = () {
                          final h = bednetHeadDisplayName?.trim();
                          if (h != null && h.isNotEmpty) return h;
                          final fromIndividual =
                              individual.name?.givenName?.trim();
                          if (fromIndividual != null &&
                              fromIndividual.isNotEmpty) {
                            return fromIndividual;
                          }
                          return name.trim();
                        }();

                        final members = bednetMemberCount ?? 1;
                        final children = bednetChildrenUnder5Count ?? 0;

                        Navigator.of(context)
                            .push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => BlocProvider.value(
                                  value: context
                                      .read<BeneficiaryRegistrationBloc>(),
                                  child: BednetHouseholdReviewPage(
                                    headName: headName,
                                    memberCount: members < 1 ? 1 : members,
                                    childrenCount: children < 0 ? 0 : children,
                                    mobileNumber: individual.mobileNumber,
                                    householdEToken: bednetDeliveryEToken,
                                    bednetDeliveryHousehold: household,
                                    bednetDeliveryHead: individual,
                                  ),
                                ),
                              ),
                            )
                            .then((_) =>
                                _reloadHouseholdOverviewAfterItnFlow(context));
                      },
                    ),
            ),
          ),
        ]);
  }

  // void navigateToChecklist(BuildContext context, clientReferenceId) async {
  //   await context.router.push(
  //       BeneficiaryChecklistRoute(beneficiaryClientRefId: clientReferenceId));
  // }
  bool _shouldShowEditButton(BuildContext context) {
    return
        // !isCurrentCycleData(context, tasks ?? []) ||
        (tasks ?? [])
                .where((element) =>
                    element.status == Status.administeredSuccess.toValue() ||
                    element.status == Status.beneficiaryRefused.toValue() ||
                    element.status == Status.beneficiaryAbsent.toValue())
                .lastOrNull ==
            null;
  }

  bool isCurrentCycleData(BuildContext context, List<TaskModel> task) {
    if (task.isEmpty) return true;
    final currentCycle = context.selectedCycle;
    final taskCycleIndex = task.last.additionalFields?.fields
        .firstWhereOrNull(
          (e) => e.key == AdditionalFieldsType.cycleIndex.toValue(),
        )
        ?.value;
    if (taskCycleIndex != null && currentCycle != null) {
      if (int.tryParse(taskCycleIndex) == currentCycle.id) {
        return true;
      }
    }
    return false;
  }
}
