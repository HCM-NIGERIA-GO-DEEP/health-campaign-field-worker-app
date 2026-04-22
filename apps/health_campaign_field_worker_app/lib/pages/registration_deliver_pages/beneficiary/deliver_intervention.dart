import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:digit_data_model/data/repositories/package_repository/local/stock.dart';
import '../../../data/registration_deliver_repo/local/task.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/component_utils.dart';
import 'package:digit_ui_components/widgets/atoms/digit_stepper.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_households.dart';
import 'package:health_campaign_field_worker_app/models/bednet_distribution/bednet_distribution_models.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/additional_fields_type.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/deliver_strategy_type.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/status.dart';
import 'package:health_campaign_field_worker_app/router/app_router.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import 'package:health_campaign_field_worker_app/utils/stock_calculation_utils.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/back_navigation_help_header.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/beneficiary/resource_beneficiary_card.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../../models/entities/roles_type.dart';
import '../../../models/registration_deliver_model/entities/registration_delivery_enums.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../widgets/registartion_deliver/component_wrapper/product_variant_bloc_wrapper.dart';

@RoutePage()
class DeliverInterventionPage extends LocalizedStatefulWidget {
  final bool isEditing;

  const DeliverInterventionPage({
    super.key,
    super.appLocalizations,
    this.isEditing = false,
  });

  @override
  State<DeliverInterventionPage> createState() =>
      DeliverInterventionPageState();
}

class DeliverInterventionPageState
    extends LocalizedState<DeliverInterventionPage> {
  // Constants for form control keys
  static const _resourceDeliveredKey = 'resourceDelivered';
  static const _quantityDistributedKey = 'quantityDistributed';
  static const _deliveryCommentKey = 'deliveryComment';
  static const _doseAdministrationKey = 'doseAdministered';
  static const _dateOfAdministrationKey = 'dateOfAdministration';
  final clickedStatus = ValueNotifier<bool>(false);
  bool? shouldSubmit = false;

  // Variable to track dose administration status
  bool doseAdministered = false;

  // List of controllers for form elements
  final List _controllers = [];

// Initialize the currentStep variable to keep track of the current step in a process.
  int currentStep = 0;

  @override
  void initState() {
    context.read<LocationBloc>().add(const LoadLocationEvent());
    super.initState();
  }

  Future<void> handleCapturedLocationState(
      LocationState locationState,
      BuildContext context,
      DeliverInterventionState deliverInterventionState,
      FormGroup form,
      HouseholdMemberWrapper householdMember,
      ProjectBeneficiaryModel projectBeneficiary) async {
    final lat = locationState.latitude;
    final long = locationState.longitude;
    final deliverInterventionBloc = context.read<DeliverInterventionBloc>();
    final submitState = deliverInterventionBloc.stream.firstWhere(
      (state) => !state.loading,
    );
    deliverInterventionBloc.add(
      DeliverInterventionSubmitEvent(
          task: _getTaskModel(
            context,
            form: form,
            oldTask: RegistrationDeliverySingleton().beneficiaryType ==
                    BeneficiaryType.household
                ? deliverInterventionState.tasks?.lastOrNull
                : null,
            projectBeneficiaryClientReferenceId:
                projectBeneficiary.clientReferenceId,
            dose: deliverInterventionState.dose,
            cycle: deliverInterventionState.cycle,
            deliveryStrategy: DeliverStrategyType.direct.toValue(),
            address: householdMember.members?.first.address?.first,
            latitude: lat,
            longitude: long,
            household: householdMember.household,
          ),
          isEditing: (deliverInterventionState.tasks ?? []).isNotEmpty &&
                  RegistrationDeliverySingleton().beneficiaryType ==
                      BeneficiaryType.household
              ? true
              : false,
          boundaryModel: RegistrationDeliverySingleton().boundary!,
          navigateToSummary: false,
          householdMemberWrapper: householdMember),
    );
    await submitState;
    if (!context.mounted) return;
    await _refreshStockInHandAfterTaskSave(context);
    if (!context.mounted) return;
    final household = householdMember.household;
    if (household?.isSchoolHousehold ?? false) {
      context.router.push(BeneficiaryAcknowledgementRoute());
    } else {
      context.router.push(
        HouseholdAcknowledgementRoute(enableViewHousehold: false),
      );
    }
  }

  Future<void> _refreshStockInHandAfterTaskSave(BuildContext context) async {
    await _resolveStockInHandForBednet(context);
    if (!mounted) return;
    setState(() {});
  }

  Future<int?> _resolveStockInHandForBednet(BuildContext context) async {
    final projectId = RegistrationDeliverySingleton().projectId;
    if (projectId == null || projectId.isEmpty) return null;

    final facilityId = await _resolveCurrentFacilityId(context);
    final productVariantId = await _resolveBednetProductVariantId(context);
    if (facilityId == null ||
        facilityId.isEmpty ||
        productVariantId == null ||
        productVariantId.isEmpty) {
      return null;
    }

    final stockRepo =
        context.read<LocalRepository<StockModel, StockSearchModel>>()
            as StockLocalRepository;
    final taskRepo = context.read<LocalRepository<TaskModel, TaskSearchModel>>()
        as TaskLocalRepository;

    final receivedStocks = await stockRepo.search(
      StockSearchModel(receiverId: facilityId),
    );
    final sentStocks = await stockRepo.search(
      StockSearchModel(senderId: facilityId),
    );

    final allStocksMap = <String, StockModel>{};
    for (final stock in receivedStocks) {
      allStocksMap[stock.clientReferenceId] = stock;
    }
    for (final stock in sentStocks) {
      allStocksMap[stock.clientReferenceId] = stock;
    }

    final allStocks = allStocksMap.values.toList();
    final tasks = await taskRepo.search(
      TaskSearchModel(projectId: projectId),
      context.loggedInUserUuid,
    );
    final isDistributor = context.loggedInUserRoles
        .any((role) => role.code == RolesType.distributor.toValue());
    final effectiveMap =
        StockCalculationUtils.calculateEffectiveStockInHandForProducts(
      stockList: allStocks,
      tasks: tasks,
      facilityId: facilityId,
      productIds: [productVariantId],
      loggedInUserUuid: context.loggedInUserUuid,
      bednetStatusKey: kBednetTaskAdministrationStatusKey,
      bednetSuccessStatus: kBednetTaskAdministrationSuccessStatus,
      fallbackPupilsPresentKey: kBednetTaskPupilsPresentKey,
      fallbackItnDeliveredKey: 'itnDeliveredCount',
      singleFallbackProductId: productVariantId,
      isDistributor: isDistributor,
    );
    return effectiveMap[productVariantId]?.toInt();
  }

  Future<String?> _resolveCurrentFacilityId(BuildContext context) async {
    final projectId = context.projectId;
    if (projectId.isEmpty) return null;

    final isDistributor = context.loggedInUserRoles
        .any((role) => role.code == RolesType.distributor.toValue());
    if (isDistributor) {
      return context.loggedInUserUuid;
    }

    final projectFacilityRepo = context.read<
        LocalRepository<ProjectFacilityModel, ProjectFacilitySearchModel>>();
    final projectFacilities = await projectFacilityRepo.search(
      ProjectFacilitySearchModel(projectId: [projectId]),
    );

    final currentFacilities = projectFacilities.where((pf) {
      final facilityLevel =
          _additionalFieldValue(pf.additionalFields?.fields, 'facilityLevel');
      return facilityLevel.isEmpty || facilityLevel.toLowerCase() == 'current';
    }).toList();

    if (currentFacilities.isNotEmpty) return currentFacilities.first.facilityId;
    if (projectFacilities.isNotEmpty) return projectFacilities.first.facilityId;
    return null;
  }

  Future<String?> _resolveBednetProductVariantId(BuildContext context) async {
    final projectId = context.projectId;
    if (projectId.isEmpty) return null;

    final projectResourceRepo = context.read<
        LocalRepository<ProjectResourceModel, ProjectResourceSearchModel>>();
    final resources = await projectResourceRepo.search(
      ProjectResourceSearchModel(projectId: [projectId]),
    );
    if (resources.isEmpty) return null;

    ProjectResourceModel? preferred;
    for (final resource in resources) {
      final name = resource.resource.name?.toLowerCase() ?? '';
      if (name.contains('bednet') ||
          name.contains('llin') ||
          (name.contains('net') && name.contains('bed'))) {
        preferred = resource;
        break;
      }
    }
    preferred ??= resources.first;
    return preferred.resource.productVariantId;
  }

  String _additionalFieldValue(List<AdditionalField>? fields, String key) {
    if (fields == null) return '';
    return fields
            .firstWhereOrNull((field) => field.key == key)
            ?.value
            ?.toString() ??
        '';
  }

  void handleLocationState(
      LocationState locationState,
      BuildContext context,
      DeliverInterventionState deliverInterventionState,
      FormGroup form,
      HouseholdMemberWrapper householdMember,
      ProjectBeneficiaryModel projectBeneficiary) {
    if (context.mounted) {
      DigitComponentsUtils.showDialog(
        context,
        localizations.translate(i18.common.locationCapturing),
        DialogType.inProgress,
      );

      Future.delayed(const Duration(seconds: 2), () {
        // After delay, hide the initial dialog
        DigitComponentsUtils.hideDialog(context);
        handleCapturedLocationState(
            locationState,
            context,
            deliverInterventionState,
            form,
            householdMember,
            projectBeneficiary);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    List<StepperData> generateSteps(int numberOfDoses) {
      return List.generate(numberOfDoses, (index) {
        return StepperData(
          title:
              '${localizations.translate(i18.deliverIntervention.dose)}${index + 1}',
        );
      });
    }

    return ProductVariantBlocWrapper(
      child: BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
        builder: (context, state) {
          final householdMemberWrapper = state.householdMemberWrapper;

          final projectBeneficiary =
              RegistrationDeliverySingleton().beneficiaryType !=
                      BeneficiaryType.individual
                  ? [householdMemberWrapper.projectBeneficiaries!.first]
                  : householdMemberWrapper.projectBeneficiaries
                      ?.where(
                        (element) =>
                            element.beneficiaryClientReferenceId ==
                            state.selectedIndividual?.clientReferenceId,
                      )
                      .toList();

          return Scaffold(
            body: state.loading
                ? const Center(child: CircularProgressIndicator())
                : BlocBuilder<DeliverInterventionBloc,
                    DeliverInterventionState>(
                    builder: (context, deliveryInterventionState) {
                      List<DeliveryProductVariant>? productVariants =
                          RegistrationDeliverySingleton()
                                      .selectedProject
                                      ?.additionalDetails
                                      ?.projectType
                                      ?.cycles
                                      ?.isNotEmpty ==
                                  true
                              ? (fetchProductVariant(
                                      RegistrationDeliverySingleton()
                                              .selectedProject
                                              ?.additionalDetails
                                              ?.projectType
                                              ?.cycles![
                                                  deliveryInterventionState
                                                          .cycle -
                                                      1]
                                              .deliveries?[
                                          deliveryInterventionState.dose - 1],
                                      state.selectedIndividual,
                                      state.householdMemberWrapper.household)
                                  ?.productVariants)
                              : RegistrationDeliverySingleton()
                                  .selectedProject
                                  ?.additionalDetails
                                  ?.projectType
                                  ?.resources
                                  ?.map((r) => DeliveryProductVariant(
                                      productVariantId: r.productVariantId,
                                      name: ''))
                                  .toList();

                      final int numberOfDoses = (RegistrationDeliverySingleton()
                                  .projectType
                                  ?.cycles
                                  ?.isNotEmpty ==
                              true)
                          ? (RegistrationDeliverySingleton()
                                  .projectType
                                  ?.cycles?[deliveryInterventionState.cycle - 1]
                                  .deliveries
                                  ?.length) ??
                              0
                          : 0;

                      generateSteps(numberOfDoses);
                      // if ((productVariants ?? []).isEmpty && context.mounted) {
                      //   SchedulerBinding.instance.addPostFrameCallback((_) {
                      //     showCustomPopup(
                      //         context: context,
                      //         builder: (popUpContext) => Popup(
                      //                 title: localizations.translate(
                      //                   i18.common.noResultsFound,
                      //                 ),
                      //                 description: localizations.translate(
                      //                   i18.deliverIntervention
                      //                       .checkForProductVariantsConfig,
                      //                 ),
                      //                 type: PopUpType.alert,
                      //                 actions: [
                      //                   DigitButton(
                      //                     label: localizations.translate(
                      //                       i18.common.coreCommonOk,
                      //                     ),
                      //                     onPressed: () {
                      //                       context.router.maybePop();
                      //                       Navigator.of(popUpContext).pop();
                      //                     },
                      //                     type: DigitButtonType.primary,
                      //                     size: DigitButtonSize.large,
                      //                   ),
                      //                 ]));
                      //   });
                      // }

                      return BlocBuilder<ProductVariantBloc,
                          ProductVariantState>(
                        builder: (context, productState) {
                          return productState.maybeWhen(
                            orElse: () => const Offstage(),
                            fetched: (productVariantsValue) {
                              final variant = productState.whenOrNull(
                                fetched: (productVariants) {
                                  return productVariants;
                                },
                              );

                              return ReactiveFormBuilder(
                                form: () => buildForm(
                                  context,
                                  productVariants,
                                  variant,
                                ),
                                builder: (context, form, child) {
                                  return ScrollableContent(
                                    enableFixedDigitButton: true,
                                    footer: BlocBuilder<DeliverInterventionBloc,
                                        DeliverInterventionState>(
                                      builder: (context, state) {
                                        return DigitCard(
                                            margin: const EdgeInsets.only(
                                                top: spacer2),
                                            children: [
                                              ValueListenableBuilder(
                                                valueListenable: clickedStatus,
                                                builder: (context,
                                                    bool isClicked, _) {
                                                  return BlocBuilder<
                                                          LocationBloc,
                                                          LocationState>(
                                                      builder: (context,
                                                          locationState) {
                                                    return DigitButton(
                                                      label: localizations
                                                          .translate(
                                                        i18.common
                                                            .coreCommonSubmit,
                                                      ),
                                                      type: DigitButtonType
                                                          .primary,
                                                      size:
                                                          DigitButtonSize.large,
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      isDisabled: isClicked,
                                                      onPressed: () async {
                                                        final deliveredProducts =
                                                            ((form.control(_resourceDeliveredKey)
                                                                        as FormArray)
                                                                    .value
                                                                as List<
                                                                    ProductVariantModel?>);
                                                        hasEmptyOrNullResources(
                                                            deliveredProducts);
                                                        hasEmptyOrZeroQuantity(
                                                            form);
                                                        hasDuplicateResources(
                                                          deliveredProducts,
                                                          form,
                                                        );

                                                        // if (hasEmptyResources) {
                                                        //   Toast.showToast(
                                                        //       context,
                                                        //       message: localizations
                                                        //           .translate(i18
                                                        //               .deliverIntervention
                                                        //               .resourceDeliveredValidation),
                                                        //       type: ToastType
                                                        //           .error);
                                                        // } else if (hasDuplicates) {
                                                        //   Toast.showToast(
                                                        //       context,
                                                        //       message: localizations
                                                        //           .translate(i18
                                                        //               .deliverIntervention
                                                        //               .resourceDuplicateValidation),
                                                        //       type: ToastType
                                                        //           .error);
                                                        // } else if (hasZeroQuantity) {
                                                        //   Toast.showToast(
                                                        //       context,
                                                        //       message: localizations
                                                        //           .translate(i18
                                                        //               .deliverIntervention
                                                        //               .resourceCannotBeZero),
                                                        //       type: ToastType
                                                        //           .error);
                                                        // } else {
                                                        final submit =
                                                            await showDialog<
                                                                bool>(
                                                          context: context,
                                                          builder: (ctx) =>
                                                              Popup(
                                                            title: localizations
                                                                .translate(i18
                                                                    .deliverIntervention
                                                                    .dialogTitle),
                                                            description: localizations
                                                                .translate(i18
                                                                    .deliverIntervention
                                                                    .dialogContent),
                                                            actions: [
                                                              DigitButton(
                                                                  label: localizations
                                                                      .translate(i18
                                                                          .common
                                                                          .coreCommonSubmit),
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            context,
                                                                            rootNavigator:
                                                                                true)
                                                                        .pop(
                                                                            true);
                                                                  },
                                                                  type: DigitButtonType
                                                                      .primary,
                                                                  size: DigitButtonSize
                                                                      .large),
                                                              DigitButton(
                                                                  label: localizations
                                                                      .translate(i18
                                                                          .common
                                                                          .coreCommonCancel),
                                                                  onPressed: () => Navigator.of(
                                                                          context,
                                                                          rootNavigator:
                                                                              true)
                                                                      .pop(
                                                                          false),
                                                                  type: DigitButtonType
                                                                      .secondary,
                                                                  size: DigitButtonSize
                                                                      .large),
                                                            ],
                                                          ),
                                                        );
                                                        if (submit ?? false) {
                                                          context
                                                              .read<
                                                                  LocationBloc>()
                                                              .add(
                                                                  const LoadLocationEvent());
                                                          handleLocationState(
                                                            locationState,
                                                            context,
                                                            deliveryInterventionState,
                                                            form,
                                                            householdMemberWrapper,
                                                            projectBeneficiary!
                                                                .first,
                                                          );
                                                        }
                                                        // }
                                                      },
                                                    );
                                                  });
                                                },
                                              ),
                                            ]);
                                      },
                                    ),
                                    header: const Column(children: [
                                      Padding(
                                        padding:
                                            EdgeInsets.only(bottom: spacer2),
                                        child: BackNavigationHelpHeaderWidget(
                                          showHelp: false,
                                        ),
                                      ),
                                    ]),
                                    children: [
                                      Column(
                                        children: [
                                          DigitCard(
                                              margin:
                                                  const EdgeInsets.all(spacer2),
                                              children: [
                                                Text(
                                                  localizations.translate(
                                                    i18.deliverIntervention
                                                        .deliverInterventionLabel,
                                                  ),
                                                  style: textTheme.headingXl
                                                      .copyWith(
                                                          color: theme
                                                              .colorTheme
                                                              .primary
                                                              .primary2),
                                                ),
                                                // if (RegistrationDeliverySingleton()
                                                //         .beneficiaryType ==
                                                //     BeneficiaryType.individual)
                                                //   ReactiveWrapperField(
                                                //     formControlName:
                                                //         _doseAdministrationKey,
                                                //     builder: (field) =>
                                                //         LabeledField(
                                                //       label: localizations
                                                //           .translate(i18
                                                //               .deliverIntervention
                                                //               .currentCycle),
                                                //       child: DigitTextFormInput(
                                                //         readOnly: true,
                                                //         keyboardType:
                                                //             TextInputType
                                                //                 .number,
                                                //         initialValue: form
                                                //             .control(
                                                //                 _doseAdministrationKey)
                                                //             .value,
                                                //       ),
                                                //     ),
                                                //   ),
                                                // if (numberOfDoses > 1)
                                                //   SizedBox(
                                                //     height: MediaQuery.sizeOf(
                                                //                 context)
                                                //             .height *
                                                //         0.07,
                                                //     child: DigitStepper(
                                                //       activeIndex:
                                                //           deliveryInterventionState
                                                //                   .dose -
                                                //               1,
                                                //       stepperList: steps,
                                                //       inverted: true,
                                                //     ),
                                                //   ),
                                                // ReactiveWrapperField(
                                                //   formControlName:
                                                //       _dateOfAdministrationKey,
                                                //   builder: (field) =>
                                                //       LabeledField(
                                                //     label:
                                                //         localizations.translate(
                                                //       i18.householdDetails
                                                //           .dateOfRegistrationLabel,
                                                //     ),
                                                //     child: DigitDateFormInput(
                                                //       readOnly: true,
                                                //       initialValue: DateFormat(
                                                //               'dd MMM yyyy')
                                                //           .format(form
                                                //               .control(
                                                //                   _dateOfAdministrationKey)
                                                //               .value)
                                                //           .toString(),
                                                //       confirmText: localizations
                                                //           .translate(
                                                //         i18.common.coreCommonOk,
                                                //       ),
                                                //       cancelText: localizations
                                                //           .translate(
                                                //         i18.common
                                                //             .coreCommonCancel,
                                                //       ),
                                                //     ),
                                                //   ),
                                                // ),
                                              ]),
                                          DigitCard(
                                              margin:
                                                  const EdgeInsets.all(spacer2),
                                              children: [
                                                Text(
                                                  localizations.translate(
                                                    i18.deliverIntervention
                                                        .deliverInterventionResourceLabel,
                                                  ),
                                                  style: textTheme.headingXl
                                                      .copyWith(
                                                          color: theme
                                                              .colorTheme
                                                              .primary
                                                              .primary2),
                                                ),
                                                ..._controllers.map((e) =>
                                                    ResourceBeneficiaryCard(
                                                      form: form,
                                                      cardIndex: _controllers
                                                          .indexOf(e),
                                                      totalItems:
                                                          _controllers.length,
                                                      isReadOnly:
                                                          RegistrationDeliverySingleton()
                                                                  .beneficiaryType ==
                                                              BeneficiaryType
                                                                  .individual,
                                                      onDelete: (index) {
                                                        (form.control(
                                                          _resourceDeliveredKey,
                                                        ) as FormArray)
                                                            .removeAt(
                                                          index,
                                                        );
                                                        (form.control(
                                                          _quantityDistributedKey,
                                                        ) as FormArray)
                                                            .removeAt(
                                                          index,
                                                        );
                                                        _controllers.removeAt(
                                                          index,
                                                        );
                                                        setState(() {
                                                          _controllers;
                                                        });
                                                      },
                                                    )),
                                              ]),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  addController(FormGroup form) {
    (form.control(_resourceDeliveredKey) as FormArray)
        .add(FormControl<ProductVariantModel>());
    (form.control(_quantityDistributedKey) as FormArray)
        .add(FormControl<int>(value: 0, validators: [Validators.min(1)]));
  }

  bool hasEmptyOrZeroQuantity(FormGroup form) {
    final quantityDistributedArray =
        form.control(_quantityDistributedKey) as FormArray;

    // Check if any quantity is zero or null
    return quantityDistributedArray.value?.any((e) => e == 0 || e == null) ??
        true;
  }

  bool hasEmptyOrNullResources(List<ProductVariantModel?> deliveredProducts) {
    final Map<String?, List<ProductVariantModel?>> groupedVariants = {};
    if (deliveredProducts.isNotEmpty) {
      for (final variant in deliveredProducts) {
        final productId = variant?.productId;
        if (productId != null) {
          groupedVariants.putIfAbsent(productId, () => []);
          groupedVariants[productId]?.add(variant);
        }
      }
      bool hasDuplicateProductIdOrNoProductId =
          deliveredProducts.any((ele) => ele?.productId == null);

      return hasDuplicateProductIdOrNoProductId;
    }

    return true;
  }

  bool hasDuplicateResources(
      List<ProductVariantModel?> deliveredProducts, FormGroup form) {
    final resourceDeliveredArray =
        form.control(_resourceDeliveredKey) as FormArray;
    final Set<String?> uniqueProductIds = {};

    for (int i = 0; i < resourceDeliveredArray.value!.length; i++) {
      final productId = deliveredProducts[i]?.id;
      if (productId != null) {
        if (uniqueProductIds.contains(productId)) {
          // Duplicate found
          return true;
        } else {
          uniqueProductIds.add(productId);
        }
      }
    }
    return false;
  }

  // ignore: long-parameter-list
  TaskModel _getTaskModel(
    BuildContext context, {
    required FormGroup form,
    TaskModel? oldTask,
    int? cycle,
    int? dose,
    String? deliveryStrategy,
    String? projectBeneficiaryClientReferenceId,
    AddressModel? address,
    HouseholdModel? household,
    double? latitude,
    double? longitude,
  }) {
    // Initialize task with oldTask if available, or create a new one
    var task = oldTask;
    var clientReferenceId = task?.clientReferenceId ?? IdGen.i.identifier;
    task ??= TaskModel(
      projectBeneficiaryClientReferenceId: projectBeneficiaryClientReferenceId,
      clientReferenceId: clientReferenceId,
      address: address?.copyWith(
        relatedClientReferenceId: clientReferenceId,
      ),
      tenantId: RegistrationDeliverySingleton().tenantId,
      rowVersion: 1,
      createdBy: RegistrationDeliverySingleton().loggedInUserUuid,
      auditDetails: AuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
      ),
      clientAuditDetails: ClientAuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
      ),
      createdDate: context.millisecondsSinceEpoch(),
    );

    // Extract productvariantList from the form
    final productvariantList =
        ((form.control(_resourceDeliveredKey) as FormArray).value
            as List<ProductVariantModel?>);
    final deliveryComment = form.control(_deliveryCommentKey).value as String?;
    // Update the task with information from the form and other context
    task = task.copyWith(
      projectId: RegistrationDeliverySingleton().projectId,
      resources: productvariantList
          .map((e) => TaskResourceModel(
                taskclientReferenceId: clientReferenceId,
                clientReferenceId: IdGen.i.identifier,
                productVariantId: e?.id,
                isDelivered: true,
                taskId: task?.id,
                tenantId: RegistrationDeliverySingleton().tenantId,
                rowVersion: oldTask?.rowVersion ?? 1,
                quantity: (((form.control(_quantityDistributedKey) as FormArray)
                        .value)?[productvariantList.indexOf(e)])
                    .toString(),
                clientAuditDetails: ClientAuditDetails(
                  createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
                  createdTime: context.millisecondsSinceEpoch(),
                ),
                auditDetails: AuditDetails(
                  createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
                  createdTime: context.millisecondsSinceEpoch(),
                ),
              ))
          .toList(),
    );

    var bednetCount = 0;
    for (final resource in task.resources ?? <TaskResourceModel>[]) {
      bednetCount += int.tryParse(resource.quantity.toString()) ?? 0;
    }

    task = task.copyWith(
      address: address?.copyWith(
        relatedClientReferenceId: clientReferenceId,
        id: null,
      ),
      status: Status.administeredSuccess.toValue(),
      additionalFields: TaskAdditionalFields(
        version: task.additionalFields?.version ?? 1,
        fields: [
          AdditionalField(
            RegistrationDeliveryEnums.name.toValue(),
            RegistrationDeliverySingleton().loggedInUser?.name,
          ),
          AdditionalField(
            AdditionalFieldsType.dateOfDelivery.toValue(),
            DateTime.now().millisecondsSinceEpoch.toString(),
          ),
          AdditionalField(
            AdditionalFieldsType.dateOfAdministration.toValue(),
            DateTime.now().millisecondsSinceEpoch.toString(),
          ),
          AdditionalField(
            AdditionalFieldsType.dateOfVerification.toValue(),
            DateTime.now().millisecondsSinceEpoch.toString(),
          ),
          AdditionalField(
            AdditionalFieldsType.cycleIndex.toValue(),
            "0${cycle ?? 1}",
          ),
          AdditionalField(
            AdditionalFieldsType.doseIndex.toValue(),
            "0${dose ?? 1}",
          ),
          AdditionalField(
            AdditionalFieldsType.deliveryStrategy.toValue(),
            deliveryStrategy,
          ),
          AdditionalField(
            kBednetTaskAdministrationStatusKey,
            kBednetTaskAdministrationSuccessStatus,
          ),
          AdditionalField(
            kBednetTaskDistributionDateKey,
            DateTime.now().millisecondsSinceEpoch,
          ),
          if (latitude != null)
            AdditionalField(
              AdditionalFieldsType.latitude.toValue(),
              latitude,
            ),
          if (longitude != null)
            AdditionalField(
              AdditionalFieldsType.longitude.toValue(),
              longitude,
            ),
          if (deliveryComment != null &&
              deliveryComment.trim().toString().isNotEmpty)
            AdditionalField(
              AdditionalFieldsType.deliveryComment.toValue(),
              deliveryComment,
            ),
          AdditionalField(
            AdditionalFieldsType.isSchool.toValue(),
            household?.isSchoolHousehold ?? false,
          ),
          if (household != null) ...[
            AdditionalField(
              'householdClientReferenceId',
              household.clientReferenceId,
            ),
            AdditionalField(
              'schoolId',
              household.additionalFields?.fields
                      .firstWhereOrNull((e) => e.key == 'schoolId')
                      ?.value
                      ?.toString() ??
                  '',
            ),
            AdditionalField(
              'schoolName',
              household.bednetDisplayName,
            ),
          ],
          AdditionalField('bednetCount', bednetCount),
        ],
      ),
    );

    return task;
  }

// This method builds a form used for delivering interventions.

  FormGroup buildForm(
    BuildContext context,
    List<DeliveryProductVariant>? productVariants,
    List<ProductVariantModel>? variants,
  ) {
    final bloc = context.read<DeliverInterventionBloc>().state;
    final overViewbloc = context.read<HouseholdOverviewBloc>().state;
    _controllers.forEachIndexed((index, element) {
      _controllers.removeAt(index);
    });

    // Add controllers for each product variant to the _controllers list.
    if (_controllers.isEmpty) {
      final int r = RegistrationDeliverySingleton()
                  .selectedProject
                  ?.additionalDetails
                  ?.projectType
                  ?.cycles ==
              null
          ? 1
          : fetchProductVariant(
                      RegistrationDeliverySingleton()
                          .selectedProject
                          ?.additionalDetails
                          ?.projectType
                          ?.cycles![bloc.cycle - 1]
                          .deliveries?[bloc.dose - 1],
                      overViewbloc.selectedIndividual,
                      overViewbloc.householdMemberWrapper.household)
                  ?.productVariants
                  ?.length ??
              0;

      _controllers.addAll(List.generate(r, (index) => index)
          .mapIndexed((index, element) => index));
    }

    return fb.group(<String, Object>{
      _doseAdministrationKey: FormControl<String>(
        value:
            '${localizations.translate(i18.deliverIntervention.cycle)} ${bloc.cycle == 0 ? (bloc.cycle + 1) : bloc.cycle}'
                .toString(),
        validators: [],
      ),
      _deliveryCommentKey: FormControl<String>(
        value: RegistrationDeliverySingleton().beneficiaryType !=
                BeneficiaryType.individual
            ? (bloc.tasks?.lastOrNull?.additionalFields?.fields
                            .where((a) =>
                                a.key ==
                                AdditionalFieldsType.deliveryComment.toValue())
                            .toList() ??
                        [])
                    .isNotEmpty
                ? bloc.tasks?.lastOrNull?.additionalFields?.fields
                    .where((a) =>
                        a.key == AdditionalFieldsType.deliveryComment.toValue())
                    .first
                    .value
                : ''
            : null,
        validators: [],
      ),
      _dateOfAdministrationKey:
          FormControl<DateTime>(value: DateTime.now(), validators: []),
      _resourceDeliveredKey: FormArray<ProductVariantModel>(
        [
          ..._controllers.map((e) => FormControl<ProductVariantModel>(
                value: variants != null && variants.length < _controllers.length
                    ? variants.last
                    : (variants != null &&
                            _controllers.indexOf(e) < variants.length
                        ? variants.firstWhereOrNull(
                            (element) =>
                                element.id ==
                                productVariants
                                    ?.elementAt(_controllers.indexOf(e))
                                    .productVariantId,
                          )
                        : null),
              )),
        ],
      ),
      _quantityDistributedKey: FormArray<int>([
        ..._controllers.mapIndexed(
          (i, e) => FormControl<int>(
            value: RegistrationDeliverySingleton().beneficiaryType !=
                    BeneficiaryType.individual
                ? int.tryParse(
                    bloc.tasks?.lastOrNull?.resources?.elementAt(i).quantity ??
                        '0',
                  )
                : 1,
            validators: [Validators.min(1)],
          ),
        ),
      ]),
    });
  }
}
