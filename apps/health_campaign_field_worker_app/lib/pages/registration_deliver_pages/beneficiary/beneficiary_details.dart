import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/atoms/table_cell.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_table.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/bednet_distribution/bednet_distribution.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/app_localization.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/household_overview/household_overview.dart';
import 'package:health_campaign_field_worker_app/models/bednet_distribution/bednet_distribution_models.dart';
import 'package:health_campaign_field_worker_app/models/entities/additional_fields_type.dart'
    as household_af;
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/additional_fields_type.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/status.dart';
import 'package:health_campaign_field_worker_app/pages/bednet_distribution/bednet_household_review.dart';
import 'package:health_campaign_field_worker_app/pages/registration_deliver_pages/beneficiary/widgets/past_delivery.dart';
import 'package:health_campaign_field_worker_app/router/app_router.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/back_navigation_help_header.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/component_wrapper/product_variant_bloc_wrapper.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/table_card/table_card.dart';
import 'package:intl/intl.dart';
import 'package:recase/recase.dart';

import 'widgets/record_delivery_cycle.dart';

@RoutePage()
class BeneficiaryDetailsPage extends LocalizedStatefulWidget {
  const BeneficiaryDetailsPage({
    super.key,
    super.appLocalizations,
  });

  @override
  State<BeneficiaryDetailsPage> createState() => BeneficiaryDetailsPageState();
}

class BeneficiaryDetailsPageState
    extends LocalizedState<BeneficiaryDetailsPage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = RegistrationDeliveryLocalization.of(context);
    final router = context.router;
    final textTheme = theme.digitTextTheme(context);

    return ProductVariantBlocWrapper(
      child: BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
        builder: (context, state) {
          final householdMemberWrapper = state.householdMemberWrapper;
          // Filtering project beneficiaries based on the selected individual
          final projectBeneficiary =
              RegistrationDeliverySingleton().beneficiaryType !=
                      BeneficiaryType.individual
                  ? [householdMemberWrapper.projectBeneficiaries?.first]
                  : householdMemberWrapper.projectBeneficiaries
                      ?.where(
                        (element) =>
                            element.beneficiaryClientReferenceId ==
                            state.selectedIndividual?.clientReferenceId,
                      )
                      .toList();

          // Extracting task data related to the selected project beneficiary

          final taskData = state.householdMemberWrapper.tasks
              ?.where((element) =>
                  element.projectBeneficiaryClientReferenceId ==
                  projectBeneficiary?.first?.clientReferenceId)
              .toList();
          final bloc = context.read<DeliverInterventionBloc>();
          final lastDose = taskData != null && taskData.isNotEmpty
              ? taskData.last.additionalFields?.fields
                      .firstWhereOrNull(
                        (e) =>
                            e.key == AdditionalFieldsType.doseIndex.toValue(),
                      )
                      ?.value ??
                  '1'
              : '0';
          final lastCycle = taskData != null && taskData.isNotEmpty
              ? taskData.last.additionalFields?.fields
                      .firstWhereOrNull(
                        (e) =>
                            e.key == AdditionalFieldsType.cycleIndex.toValue(),
                      )
                      ?.value ??
                  '1'
              : '1';

          // [TODO] Need to move this to Bloc Lisitner or consumer
          if (RegistrationDeliverySingleton().projectType != null) {
            bloc.add(
              DeliverInterventionEvent.setActiveCycleDose(
                lastDose: taskData != null && taskData.isNotEmpty
                    ? int.tryParse(
                          lastDose,
                        ) ??
                        1
                    : 0,
                lastCycle: taskData != null && taskData.isNotEmpty
                    ? int.tryParse(
                          lastCycle,
                        ) ??
                        1
                    : 1,
                individualModel: state.selectedIndividual,
                projectType: RegistrationDeliverySingleton().projectType!,
              ),
            );
          }

          // Building the table content based on the DeliverInterventionState

          return BlocBuilder<ProductVariantBloc, ProductVariantState>(
            builder: (context, productState) {
              return productState.maybeWhen(
                  orElse: () => const Offstage(),
                  fetched: (productVariantsValue) {
                    final variant = productState.whenOrNull(
                      fetched: (productVariants) {
                        return productVariants;
                      },
                    );

                    return Scaffold(
                      body: ScrollableContent(
                        enableFixedDigitButton: true,
                        header: const Column(children: [
                          BackNavigationHelpHeaderWidget(),
                        ]),
                        footer: BlocBuilder<DeliverInterventionBloc,
                            DeliverInterventionState>(
                          builder: (context, deliverState) {
                            final isItnHousehold =
                                RegistrationDeliverySingleton().beneficiaryType ==
                                    BeneficiaryType.household;
                            if (isItnHousehold) {
                              return DigitCard(
                                margin:
                                    const EdgeInsets.only(top: spacer2),
                                children: [
                                  DigitButton(
                                    label: localizations.translate(
                                      i18.beneficiaryDetails.recordDelivery,
                                    ),
                                    type: DigitButtonType.primary,
                                    size: DigitButtonSize.large,
                                    mainAxisSize: MainAxisSize.max,
                                    onPressed: () =>
                                        _pushBednetHouseholdItnFlow(
                                      context,
                                      state,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final projectType =
                                RegistrationDeliverySingleton().projectType;
                            final cycles = projectType?.cycles;

                            return cycles != null && cycles.isNotEmpty
                                // ? deliverState.hasCycleArrived
                                    ? DigitCard(
                                        margin:
                                            const EdgeInsets.only(top: spacer2),
                                        children: [
                                            DigitButton(
                                              label:
                                                  '${localizations.translate(i18.beneficiaryDetails.recordDelivery)} ',
                                                  // '${(deliverState.cycle == 0 ? (deliverState.cycle + 1) : deliverState.cycle).toString()} ${localizations.translate(i18.deliverIntervention.dose)} ',
                                                  // '${(deliverState.dose).toString()}',
                                              type: DigitButtonType.primary,
                                              size: DigitButtonSize.large,
                                              mainAxisSize: MainAxisSize.max,
                                              onPressed: () async {
                                                final selectedCycle = cycles
                                                    .firstWhereOrNull((c) =>
                                                        c.id ==
                                                        deliverState.cycle);
                                                if (selectedCycle != null) {
                                                  bloc.add(
                                                    DeliverInterventionEvent
                                                        .selectFutureCycleDose(
                                                      dose: deliverState.dose,
                                                      cycle:
                                                          RegistrationDeliverySingleton()
                                                              .projectType!
                                                              .cycles!
                                                              .firstWhere((c) =>
                                                                  c.id ==
                                                                  deliverState
                                                                      .cycle),
                                                      individualModel: state
                                                          .selectedIndividual,
                                                    ),
                                                  );
                                                  showCustomPopup(
                                                    context: context,
                                                    builder: (popUpContext) => Popup(
                                                        title: localizations
                                                            .translate(i18
                                                                .beneficiaryDetails
                                                                .resourcesTobeDelivered),
                                                        type: PopUpType.simple,
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        additionalWidgets: [
                                                          buildTableContent(
                                                              deliverState,
                                                              context,
                                                              variant,
                                                              state
                                                                  .selectedIndividual,
                                                              state
                                                                  .householdMemberWrapper
                                                                  .household),
                                                        ],
                                                        actions: [
                                                          DigitButton(
                                                              label: localizations
                                                                  .translate(i18
                                                                      .beneficiaryDetails
                                                                      .ctaProceed),
                                                              onPressed: () {
                                                                Navigator.of(
                                                                  context,
                                                                  rootNavigator:
                                                                      true,
                                                                ).pop();
                                                                router.push(
                                                                  DeliverInterventionRoute(),
                                                                );
                                                              },
                                                              type:
                                                                  DigitButtonType
                                                                      .primary,
                                                              size:
                                                                  DigitButtonSize
                                                                      .large),
                                                        ]),
                                                  );
                                                }
                                              },
                                            ),
                                          ])
                                    // : const SizedBox.shrink()
                                : DigitCard(
                                    margin: const EdgeInsets.only(top: spacer2),
                                    children: [
                                        DigitButton(
                                          label: localizations.translate(i18
                                              .householdOverView
                                              .householdOverViewActionText),
                                          type: DigitButtonType.primary,
                                          size: DigitButtonSize.large,
                                          mainAxisSize: MainAxisSize.max,
                                          onPressed: () {
                                            // context.router.push(
                                            //     DeliverInterventionRoute());
                                          },
                                        ),
                                      ]);
                          },
                        ),
                        children: [
                          DigitCard(
                              margin: const EdgeInsets.all(spacer2),
                              children: [
                                Text(
                                  localizations.translate(i18.beneficiaryDetails
                                      .beneficiarysDetailsLabelText),
                                  style: textTheme.headingXl.copyWith(
                                      color: theme.colorTheme.primary.primary2),
                                ),
                                DigitTableCard(
                                  element: {
                                    localizations.translate(
                                      RegistrationDeliverySingleton()
                                                  .beneficiaryType !=
                                              BeneficiaryType.individual
                                          ? i18.householdOverView
                                              .householdOverViewHouseholdHeadLabel
                                          : i18.common.coreCommonName,
                                    ): RegistrationDeliverySingleton()
                                                .beneficiaryType !=
                                            BeneficiaryType.individual
                                        ? householdMemberWrapper
                                            .headOfHousehold?.name?.givenName
                                        : state.selectedIndividual?.name
                                                ?.givenName ??
                                            '--',
                                    
                                    localizations.translate(
                                      i18.common.coreCommonAge,
                                    ): () {
                                      final dob =
                                          RegistrationDeliverySingleton()
                                                      .beneficiaryType !=
                                                  BeneficiaryType.individual
                                              ? householdMemberWrapper
                                                  .headOfHousehold?.dateOfBirth
                                              : state.selectedIndividual
                                                  ?.dateOfBirth;
                                      if (dob == null || dob.isEmpty) {
                                        return '--';
                                      }

                                      final int years =
                                          DigitDateUtils.calculateAge(
                                        DigitDateUtils
                                                .getFormattedDateToDateTime(
                                              dob,
                                            ) ??
                                            DateTime.now(),
                                      ).years;
                                      final int months =
                                          DigitDateUtils.calculateAge(
                                        DigitDateUtils
                                                .getFormattedDateToDateTime(
                                              dob,
                                            ) ??
                                            DateTime.now(),
                                      ).months;

                                      return "$years ${localizations.translate(i18.memberCard.deliverDetailsYearText)} ${localizations.translate(months.toString().toUpperCase())} ${localizations.translate(i18.memberCard.deliverDetailsMonthsText)}";
                                    }(),
                                    localizations.translate(
                                      i18.common.coreCommonGender,
                                    ): RegistrationDeliverySingleton()
                                                .beneficiaryType !=
                                            BeneficiaryType.individual
                                        ? householdMemberWrapper.headOfHousehold
                                            ?.gender?.name.sentenceCase
                                        : state.selectedIndividual?.gender?.name
                                                .sentenceCase ??
                                            '--',
                                    
                                    localizations.translate(i18
                                        .deliverIntervention
                                        .dateOfRegistrationLabel): () {
                                      final date = projectBeneficiary
                                          ?.first?.dateOfRegistration;

                                      final registrationDate =
                                          DateTime.fromMillisecondsSinceEpoch(
                                        date ??
                                            DateTime.now()
                                                .millisecondsSinceEpoch,
                                      );

                                      return DateFormat('dd MMMM yyyy')
                                          .format(registrationDate);
                                    }(),
                                  },
                                ),
                              ]),
                          if (RegistrationDeliverySingleton().beneficiaryType ==
                              BeneficiaryType.household)
                            _buildItnHouseholdDeliveryCard(
                              context,
                              taskData,
                            )
                          else if ((RegistrationDeliverySingleton()
                                      .projectType
                                      ?.cycles ??
                                  [])
                              .isNotEmpty)
                            DigitCard(
                                margin: const EdgeInsets.all(spacer2),
                                children: RegistrationDeliverySingleton()
                                            .projectType
                                            ?.cycles !=
                                        null
                                    ? [
                                        BlocBuilder<DeliverInterventionBloc,
                                            DeliverInterventionState>(
                                          builder: (context, deliverState) {
                                            return Column(
                                              children: [
                                                (RegistrationDeliverySingleton()
                                                                .projectType
                                                                ?.cycles ??
                                                            [])
                                                        .isNotEmpty
                                                    ? RecordDeliveryCycle(
                                                        projectCycles:
                                                            RegistrationDeliverySingleton()
                                                                    .projectType
                                                                    ?.cycles ??
                                                                [],
                                                        taskData:
                                                            taskData ?? [],
                                                        individualModel: state
                                                            .selectedIndividual,
                                                      )
                                                    : const Offstage(),
                                              ],
                                            );
                                          },
                                        ),
                                      ]
                                    : [])
                        ],
                      ),
                    );
                  },
                  empty: () => Center(
                        child: Text(
                          localizations.translate(
                            i18.deliverIntervention
                                .checkForProductVariantsConfig,
                          ),
                        ),
                      ));
            },
          );
        },
      ),
    );
  }

  Widget _buildItnHouseholdDeliveryCard(
    BuildContext context,
    List<TaskModel>? taskData,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final t = taskData?.lastOrNull;
    final delivered =
        t?.status == Status.administeredSuccess.toValue();
    int? completedMs;
    final raw = t?.additionalFields?.fields
        .firstWhereOrNull((f) => f.key == kBednetTaskDistributionDateKey)
        ?.value;
    if (raw is int) {
      completedMs = raw;
    } else if (raw is num) {
      completedMs = raw.toInt();
    }

    return DigitCard(
      margin: const EdgeInsets.all(spacer2),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            localizations.translate(i18.beneficiaryDetails.currentCycleLabel),
            style: textTheme.headingL.copyWith(
              color: theme.colorTheme.primary.primary2,
            ),
          ),
        ),
        const SizedBox(height: spacer2),
        SizedBox(
          height: 120,
          width: MediaQuery.of(context).size.width,
          child: DigitTable(
            enableBorder: true,
            withRowDividers: true,
            withColumnDividers: true,
            showSelectedState: false,
            showPagination: false,
            highlightedRows: const [0],
            columns: [
              DigitTableColumn(
                header: localizations
                    .translate(i18.beneficiaryDetails.itnDeliveryNoColumnHeader),
                cellValue: 'delivery',
              ),
              DigitTableColumn(
                header: localizations
                    .translate(i18.beneficiaryDetails.beneficiaryStatus),
                cellValue: 'status',
              ),
              DigitTableColumn(
                header: localizations.translate(
                  i18.beneficiaryDetails.beneficiaryCompletedOn,
                ),
                cellValue: 'completedOn',
              ),
            ],
            rows: [
              DigitTableRow(
                tableRow: [
                  DigitTableData(
                    localizations.translate(
                      i18.beneficiaryDetails.itnFirstDeliveryRowLabel,
                    ),
                    cellKey: 'delivery',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  DigitTableData(
                    localizations.translate(
                      delivered
                          ? Status.administeredSuccess.toValue()
                          : Status.toAdminister.toValue(),
                    ),
                    cellKey: 'status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: delivered
                          ? DigitTheme.instance.colorScheme.onSurfaceVariant
                          : DigitTheme.instance.colorScheme.error,
                    ),
                  ),
                  DigitTableData(
                    completedMs != null
                        ? DateFormat('dd MMM yyyy').format(
                            DateTime.fromMillisecondsSinceEpoch(completedMs),
                          )
                        : '--',
                    cellKey: 'completedOn',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _pushBednetHouseholdItnFlow(
    BuildContext context,
    HouseholdOverviewState state,
  ) {
    final wrapper = state.householdMemberWrapper;
    final household = wrapper.household;
    final head = wrapper.headOfHousehold ?? state.selectedIndividual;
    if (household == null || head == null) return;

    try {
      context.read<BednetDistributionBloc>().add(
            BednetDistributionEvent.updateSelectedSchool(school: household),
          );
    } catch (_) {}

    BeneficiaryRegistrationBloc bloc;
    try {
      bloc = context.read<BeneficiaryRegistrationBloc>();
    } catch (_) {
      return;
    }

    final headName = head.name?.givenName?.trim() ?? '';
    final members = household.memberCount ?? 1;
    final children = _childrenUnder5FromHouseholdFields(household);
    final eToken = _eTokenFromHousehold(wrapper.household);

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: BednetHouseholdReviewPage(
            headName: headName.isEmpty ? ' ' : headName,
            memberCount: members < 1 ? 1 : members,
            childrenCount: children < 0 ? 0 : children,
            mobileNumber: head.mobileNumber,
            householdEToken: eToken,
            bednetDeliveryHousehold: household,
            bednetDeliveryHead: head,
          ),
        ),
      ),
    );
  }

  int _childrenUnder5FromHouseholdFields(HouseholdModel household) {
    final fields = household.additionalFields?.fields;
    if (fields == null) return 0;
    return int.tryParse(
          fields
              .firstWhere(
                (f) =>
                    f.key ==
                    household_af.AdditionalFieldsType.childrenUnder5.toValue(),
                orElse: () => AdditionalField(
                  household_af.AdditionalFieldsType.childrenUnder5.toValue(),
                  '0',
                ),
              )
              .value
              .toString(),
        ) ??
        0;
  }

  String? _eTokenFromHousehold(HouseholdModel? household) {
    final raw = household?.additionalFields?.fields
        .firstWhere(
          (f) => f.key == household_af.AdditionalFieldsType.eToken.toValue(),
          orElse: () =>
              AdditionalField(household_af.AdditionalFieldsType.eToken.toValue(), ''),
        )
        .value
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}
