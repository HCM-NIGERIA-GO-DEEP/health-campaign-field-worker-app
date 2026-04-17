import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart'
    hide ReferralModel, ReferralSearchModel;
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/models/RadioButtonModel.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:digit_ui_components/widgets/atoms/digit_divider.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/atoms/selection_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/household_overview/household_overview.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/referral_management/referral_management.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_households.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/referral.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/registration_delivery_enums.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/constants.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/extensions/extensions.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/back_navigation_help_header.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';
import 'package:survey_form/survey_form.dart';

import '../../../models/registration_deliver_model/entities/status.dart';
import '../../../router/app_router.dart';
import '../beneficiary_registration/refer_beneficiary_page.dart';

@RoutePage()
class BeneficiaryChecklistPage extends LocalizedStatefulWidget {
  final String? beneficiaryClientRefId;
  final String? projectBeneficiaryClientRefId;
  final String? householdClientReferenceId;
  final String? administrativeAreaCode;
  final IndividualModel? screeningIndividual;

  const BeneficiaryChecklistPage({
    super.key,
    this.beneficiaryClientRefId,
    this.projectBeneficiaryClientRefId,
    this.householdClientReferenceId,
    this.administrativeAreaCode,
    this.screeningIndividual,
    super.appLocalizations,
  });

  @override
  State<BeneficiaryChecklistPage> createState() =>
      _BeneficiaryChecklistPageState();
}

class _BeneficiaryChecklistPageState
    extends LocalizedState<BeneficiaryChecklistPage> {
  String isStateChanged = '';
  var submitTriggered = false;
  var validFields = true;
  List<TextEditingController> controller = [];
  List<TextEditingController> additionalController = [];
  List<AttributesModel>? initialAttributes;
  ServiceDefinitionModel? selectedServiceDefinition;
  bool isControllersInitialized = false;
  List<int> visibleChecklistIndexes = [];
  GlobalKey<FormState> checklistFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    context.read<ServiceBloc>().add(
          ServiceSurveyFormEvent(
            value: Random().nextInt(100).toString(),
            submitTriggered: true,
          ),
        );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlocBuilder<ServiceDefinitionBloc, ServiceDefinitionState>(
          builder: (context, state) {
            state.mapOrNull(
              serviceDefinitionFetch: (value) {
                selectedServiceDefinition = value.serviceDefinitionList
                    .where((element) => element.code.toString().contains(
                        '${RegistrationDeliverySingleton().selectedProject!.name}.${RegistrationDeliveryEnums.eligibility.toValue()}'))
                    .toList()
                    .firstOrNull;

                initialAttributes = selectedServiceDefinition?.attributes;
                if (!isControllersInitialized) {
                  initialAttributes?.forEach((e) {
                    controller.add(TextEditingController());
                  });

                  // Set the flag to true after initializing controllers
                  isControllersInitialized = true;
                }
              },
            );

            return state.maybeMap(
              orElse: () => Text(state.runtimeType.toString()),
              serviceDefinitionFetch: (value) {
                return ScrollableContent(
                  header: Column(children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: spacer2),
                      child: BackNavigationHelpHeaderWidget(
                        showHelp: false,
                        handleBack: () {
                          //TODO: direct go back is not working, need to check
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ]),
                  enableFixedDigitButton: true,
                  footer: DigitCard(
                      margin: const EdgeInsets.only(top: spacer2),
                      children: [
                        DigitButton(
                          label: localizations
                              .translate(i18.common.coreCommonSubmit),
                          type: DigitButtonType.primary,
                          size: DigitButtonSize.large,
                          mainAxisSize: MainAxisSize.max,
                          onPressed: () async {
                            submitTriggered = true;

                            context.read<ServiceBloc>().add(
                                  const ServiceSurveyFormEvent(
                                    value: '',
                                    submitTriggered: true,
                                  ),
                                );
                            final isValid =
                                checklistFormKey.currentState?.validate();
                            if (!isValid!) {
                              return;
                            }
                            final itemsAttributes = initialAttributes;
                            var validChecklist = true;

                            for (int i = 0; i < controller.length; i++) {
                              final attr = itemsAttributes?[i];
                              if (attr == null) continue;
                              if (!_isAttributeRequiredForSubmit(i)) continue;

                              if (attr.dataType == 'SingleValueList' &&
                                  visibleChecklistIndexes.any((e) => e == i) &&
                                  controller[i].text == '') {
                                return;
                              }
                              if (attr.dataType == 'MultiValueList' &&
                                  !_multiValueListHasSelection(i)) {
                                return;
                              }
                              if (attr.dataType != 'SingleValueList' &&
                                  attr.dataType != 'MultiValueList' &&
                                  controller[i].text == '') {
                                return;
                              }
                              if (attr.dataType == 'Boolean' &&
                                  controller[i].text == '') {
                                setState(() {
                                  validFields = false;
                                  validChecklist = false;
                                });
                              }
                            }

                            if (!validChecklist) {
                              return;
                            }

                            final decidedFlow = _assessEligibilityPlanB();

                            showCustomPopup(
                                context: context,
                                builder: (popUpContext) => Popup(
                                        title: localizations.translate(i18
                                            .deliverIntervention.dialogTitle),
                                        type: PopUpType.simple,
                                        description: localizations
                                            .translate(
                                              i18.deliverIntervention
                                                  .beneficiaryChecklistDialogDescription,
                                            )
                                            .replaceFirst(
                                                '{}',
                                                localizations
                                                    .translate(decidedFlow)),
                                        actions: [
                                          DigitButton(
                                              label: localizations.translate(
                                                i18.beneficiaryDetails
                                                    .ctaProceed,
                                              ),
                                              onPressed: () async {
                                                final router = context.router;
                                                Navigator.of(context,
                                                        rootNavigator: true)
                                                    .pop();
                                                createSubmitRequest(
                                                    decidedFlow: decidedFlow);
                                                if (!context.mounted) return;
                                                await navigateToDecidedFlow(
                                                  context,
                                                  router,
                                                  decidedFlow,
                                                );
                                              },
                                              capitalizeLetters: false,
                                              type: DigitButtonType.primary,
                                              size: DigitButtonSize.large),
                                          DigitButton(
                                              label: localizations.translate(
                                                i18.common.coreCommonCancel,
                                              ),
                                              onPressed: () {
                                                Navigator.of(context,
                                                        rootNavigator: true)
                                                    .pop();
                                              },
                                              capitalizeLetters: false,
                                              type: DigitButtonType.secondary,
                                              size: DigitButtonSize.large)
                                        ]));
                          },
                        ),
                      ]),
                  children: [
                    Form(
                      key: checklistFormKey, //assigning key to form
                      child: DigitCard(
                          margin: const EdgeInsets.all(spacer2),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: spacer2),
                              child: Text(
                                '${localizations.translate(
                                  selectedServiceDefinition!.code.toString(),
                                )} ${localizations.translate(i18.checklist.checklist)}',
                                style: textTheme.headingXl.copyWith(
                                    color: theme.colorTheme.primary.primary2),
                              ),
                            ),
                            ...initialAttributes!.map((
                              e,
                            ) {
                              String? description = e.additionalFields?.fields
                                  .where((a) => a.key == 'helpText')
                                  .firstOrNull
                                  ?.value;
                              int index = (initialAttributes ?? []).indexOf(e);

                              return Column(children: [
                                if (e.dataType == 'String' &&
                                    !(e.code ?? '').contains('.')) ...[
                                  FormField<String>(
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (value) {
                                      if (((value == null || value == '') &&
                                          e.required == true)) {
                                        return localizations
                                            .translate("${e.code}_REQUIRED");
                                      }
                                      if (e.regex != null) {
                                        return (RegExp(e.regex!)
                                                .hasMatch(value!))
                                            ? null
                                            : localizations
                                                .translate("${e.code}_REGEX");
                                      }

                                      return null;
                                    },
                                    builder: (field) => Column(
                                      children: [
                                        LabeledField(
                                          label: localizations.translate(
                                            '${selectedServiceDefinition?.code}.${e.code}',
                                          ),
                                          description: description != null
                                              ? localizations.translate(
                                                  '${value.selectedServiceDefinition?.code}.$description',
                                                )
                                              : null,
                                          labelStyle: textTheme.headingM
                                              .copyWith(
                                                  color: theme
                                                      .colorTheme.text.primary),
                                          descriptionStyle: textTheme.bodyS
                                              .copyWith(
                                                  color: theme.colorTheme.text
                                                      .secondary),
                                          isRequired: e.required ?? false,
                                          capitalizedFirstLetter: false,
                                          child: DigitTextFormInput(
                                            onChange: (value) {
                                              field.didChange(value);
                                              controller[index].text = value;
                                              checklistFormKey.currentState
                                                  ?.validate();
                                            },
                                            isRequired: e.required ?? false,
                                            controller: controller[index],
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(
                                                "[a-zA-Z0-9]",
                                              )),
                                            ],
                                          ),
                                        ),
                                        const DigitDivider(),
                                      ],
                                    ),
                                  ),
                                ] else if (e.dataType == 'Number' &&
                                    !(e.code ?? '').contains('.')) ...[
                                  FormField<String>(
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (value) {
                                      if (((value == null || value == '') &&
                                          e.required == true)) {
                                        return localizations.translate(
                                          i18.common.corecommonRequired,
                                        );
                                      }
                                      if (e.regex != null) {
                                        return (RegExp(e.regex!)
                                                .hasMatch(value!))
                                            ? null
                                            : localizations
                                                .translate("${e.code}_REGEX");
                                      }

                                      return null;
                                    },
                                    builder: (field) => Column(
                                      children: [
                                        LabeledField(
                                          label: localizations
                                              .translate(
                                                '${value.selectedServiceDefinition?.code}.${e.code}',
                                              )
                                              .trim(),
                                          isRequired: e.required ?? false,
                                          capitalizedFirstLetter: false,
                                          labelStyle: textTheme.headingM
                                              .copyWith(
                                                  color: theme
                                                      .colorTheme.text.primary),
                                          descriptionStyle: textTheme.bodyS
                                              .copyWith(
                                                  color: theme.colorTheme.text
                                                      .secondary),
                                          description: description != null
                                              ? localizations.translate(
                                                  '${value.selectedServiceDefinition?.code}.$description',
                                                )
                                              : null,
                                          child: DigitTextFormInput(
                                            onChange: (value) {
                                              field.didChange(value);
                                              controller[index].text = value;
                                              checklistFormKey.currentState
                                                  ?.validate();
                                            },
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(
                                                "[0-9]",
                                              )),
                                            ],
                                            controller: controller[index],
                                          ),
                                        ),
                                        const DigitDivider()
                                      ],
                                    ),
                                  ),
                                ] else if (e.dataType == 'SingleValueList') ...[
                                  if (!(e.code ?? '').contains('.'))
                                    _buildSurveyForm(
                                        e,
                                        index,
                                        selectedServiceDefinition,
                                        context,
                                        description)
                                ] else if (e.dataType == 'MultiValueList' &&
                                    !(e.code ?? '').contains('.')) ...[
                                  if (_shouldShowMultiValueAttribute(e))
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.all(spacer2),
                                        child: Column(
                                          children: [
                                            LabeledField(
                                              label: localizations.translate(
                                                '${value.selectedServiceDefinition?.code}.${e.code}',
                                              ),
                                              description: description != null
                                                  ? localizations.translate(
                                                      '${value.selectedServiceDefinition?.code}.$description',
                                                    )
                                                  : null,
                                              labelStyle: textTheme.headingM
                                                  .copyWith(
                                                      color: theme.colorTheme
                                                          .text.primary),
                                              descriptionStyle: textTheme.bodyS
                                                  .copyWith(
                                                      color: theme.colorTheme
                                                          .text.secondary),
                                              isRequired: (e.required ??
                                                      false) &&
                                                  (e.code !=
                                                          'ADDITIONAL_SYMPTOMS' ||
                                                      _shouldShowAdditionalSymptomsSection()),
                                              child: BlocBuilder<ServiceBloc,
                                                  ServiceState>(
                                                builder: (context, state) {
                                                  return Column(
                                                    children: e.values!
                                                        .map((e) =>
                                                            DigitCheckbox(
                                                              label: e,
                                                              value: controller[
                                                                      index]
                                                                  .text
                                                                  .split('.')
                                                                  .contains(e),
                                                              onChanged:
                                                                  (value) {
                                                                context
                                                                    .read<
                                                                        ServiceBloc>()
                                                                    .add(
                                                                      ServiceSurveyFormEvent(
                                                                        value: e
                                                                            .toString(),
                                                                        submitTriggered:
                                                                            submitTriggered,
                                                                      ),
                                                                    );
                                                                final String
                                                                    ele;
                                                                var val =
                                                                    controller[
                                                                            index]
                                                                        .text
                                                                        .split(
                                                                            '.');
                                                                if (val
                                                                    .contains(
                                                                        e)) {
                                                                  val.remove(e);
                                                                  ele =
                                                                      val.join(
                                                                          ".");
                                                                } else {
                                                                  ele =
                                                                      "${controller[index].text}.$e";
                                                                }
                                                                controller[index]
                                                                        .value =
                                                                    TextEditingController
                                                                        .fromValue(
                                                                  TextEditingValue(
                                                                    text: ele,
                                                                  ),
                                                                ).value;
                                                                setState(() {});
                                                              },
                                                            ))
                                                        .toList(),
                                                  );
                                                },
                                              ),
                                            ),
                                            const DigitDivider(),
                                          ],
                                        ),
                                      ),
                                    ),
                                ] else if (e.dataType == 'Boolean') ...[
                                  if (!(e.code ?? '').contains('.'))
                                    DigitCard(
                                        cardType: CardType.primary,
                                        children: [
                                          Align(
                                            alignment: Alignment.topLeft,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(spacer2),
                                              child: LabeledField(
                                                label: localizations.translate(
                                                  '${selectedServiceDefinition?.code}.${e.code}',
                                                ),
                                                capitalizedFirstLetter: false,
                                                description: description != null
                                                    ? localizations.translate(
                                                        '${value.selectedServiceDefinition?.code}.$description',
                                                      )
                                                    : null,
                                                labelStyle: textTheme.headingM
                                                    .copyWith(
                                                        color: theme.colorTheme
                                                            .text.primary),
                                                descriptionStyle:
                                                    textTheme.bodyS.copyWith(
                                                        color: theme.colorTheme
                                                            .text.secondary),
                                                isRequired: e.required ?? false,
                                                child: BlocBuilder<ServiceBloc,
                                                    ServiceState>(
                                                  builder: (context, state) {
                                                    return FormField<bool>(
                                                      autovalidateMode:
                                                          AutovalidateMode
                                                              .onUserInteraction,
                                                      validator: (value) {
                                                        if (e.required ==
                                                                true &&
                                                            (controller[index]
                                                                        .text ==
                                                                    null ||
                                                                controller[index]
                                                                        .text ==
                                                                    '')) {
                                                          return localizations
                                                              .translate(
                                                            i18.common
                                                                .coreCommonReasonRequired,
                                                          );
                                                        }

                                                        return null;
                                                      },
                                                      builder: (field) =>
                                                          Column(
                                                        children: [
                                                          SelectionCard<bool>(
                                                            errorMessage:
                                                                field.errorText,
                                                            allowMultipleSelection:
                                                                false,
                                                            valueMapper:
                                                                (value) {
                                                              return value
                                                                  ? localizations
                                                                      .translate(
                                                                      i18.common
                                                                          .coreCommonYes,
                                                                    )
                                                                  : localizations
                                                                      .translate(
                                                                      i18.common
                                                                          .coreCommonNo,
                                                                    );
                                                            },
                                                            initialSelection: controller[
                                                                            index]
                                                                        .text ==
                                                                    'true'
                                                                ? [true]
                                                                : controller[index]
                                                                            .text ==
                                                                        'false'
                                                                    ? [false]
                                                                    : [],
                                                            options: const [
                                                              true,
                                                              false
                                                            ],
                                                            onSelectionChanged:
                                                                (curValue) {
                                                              field.didChange(
                                                                  curValue
                                                                      .first);
                                                              if (curValue
                                                                  .isNotEmpty) {
                                                                context
                                                                    .read<
                                                                        ServiceBloc>()
                                                                    .add(
                                                                      ServiceSurveyFormEvent(
                                                                        value: curValue
                                                                            .toString(),
                                                                        submitTriggered:
                                                                            submitTriggered,
                                                                      ),
                                                                    );
                                                                controller[index]
                                                                        .value =
                                                                    TextEditingValue(
                                                                  text: curValue
                                                                      .first
                                                                      .toString(),
                                                                );
                                                              }
                                                            },
                                                          ),
                                                          const DigitDivider(),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ]),
                                ],
                              ]);
                            }),
                          ]),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static const _yesAnswer = 'YES';
  static const _noAnswer = 'NO';

  /// QUES1–QUES6 in API [order], aligned with product rules.
  List<int> _sortedEligibilityQuestionIndices() {
    final list = initialAttributes ?? [];
    final entries = <({int idx, int order})>[];
    for (var i = 0; i < list.length; i++) {
      final c = list[i].code ?? '';
      if (RegExp(r'^QUES[1-6]$').hasMatch(c)) {
        entries.add((
          idx: i,
          order: int.tryParse(list[i].order ?? '') ?? 0,
        ));
      }
    }
    entries.sort((a, b) => a.order.compareTo(b.order));
    return entries.map((e) => e.idx).toList();
  }

  int? _additionalSymptomsAttributeIndex() =>
      initialAttributes?.indexWhere((a) => a.code == 'ADDITIONAL_SYMPTOMS');

  int _yesCountEligibilityQuestions() {
    var n = 0;
    for (final i in _sortedEligibilityQuestionIndices()) {
      if (controller[i].text.trim() == _yesAnswer) n++;
    }
    return n;
  }

  bool _shouldShowAdditionalSymptomsSection() =>
      _yesCountEligibilityQuestions() >= 2;

  bool _shouldShowMultiValueAttribute(AttributesModel e) {
    if (e.code != 'ADDITIONAL_SYMPTOMS') return true;
    return _shouldShowAdditionalSymptomsSection();
  }

  bool _multiValueListHasSelection(int index) {
    final t = controller[index].text.trim();
    if (t.isEmpty) return false;
    return t.split('.').where((s) => s.isNotEmpty).isNotEmpty;
  }

  bool _isAttributeRequiredForSubmit(int i) {
    final attr = initialAttributes?[i];
    if (attr?.required != true) return false;
    if (attr?.code == 'ADDITIONAL_SYMPTOMS') {
      return _shouldShowAdditionalSymptomsSection();
    }
    return true;
  }

  bool _isQ1YesRestNoEligibilityPattern() {
    final idx = _sortedEligibilityQuestionIndices();
    if (idx.length < 6) return false;
    if (controller[idx.first].text.trim() != _yesAnswer) return false;
    for (var j = 1; j < 6; j++) {
      if (controller[idx[j]].text.trim() != _noAnswer) return false;
    }
    return true;
  }

  /// Q1=Y and Q2–6=N → referral. ≥2 YES (after additional symptoms) → continue delivery.
  String _assessEligibilityPlanB() {
    if (_sortedEligibilityQuestionIndices().length < 6) {
      return Status.toAdminister.toValue();
    }
    if (_isQ1YesRestNoEligibilityPattern()) {
      return Status.beneficiaryReferred.toValue();
    }
    return Status.toAdminister.toValue();
  }

  /// Route args may omit [screeningIndividual] (auto_route / serialization). Resolve from bloc + members.
  String? _beneficiaryClientRefForLookup() =>
      widget.beneficiaryClientRefId ??
      widget.screeningIndividual?.clientReferenceId;

  HouseholdOverviewState? _tryHouseholdOverviewState(BuildContext context) {
    try {
      return context.read<HouseholdOverviewBloc>().state;
    } catch (_) {
      return null;
    }
  }

  IndividualModel? _resolveScreeningIndividual(BuildContext context) {
    if (widget.screeningIndividual != null) return widget.screeningIndividual;
    final ref = _beneficiaryClientRefForLookup();
    if (ref == null || ref.isEmpty) return null;
    final state = _tryHouseholdOverviewState(context);
    if (state == null) return null;
    final selected = state.selectedIndividual;
    if (selected != null && selected.clientReferenceId == ref) {
      return selected;
    }
    return state.householdMemberWrapper.members
        ?.firstWhereOrNull((m) => m.clientReferenceId == ref);
  }

  String? _resolveProjectBeneficiaryClientRefId(BuildContext context) {
    final fromRoute = widget.projectBeneficiaryClientRefId;
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final ref = _beneficiaryClientRefForLookup();
    if (ref == null || ref.isEmpty) return null;
    final state = _tryHouseholdOverviewState(context);
    final pbs = state?.householdMemberWrapper.projectBeneficiaries;
    return pbs
        ?.firstWhereOrNull((b) => b.beneficiaryClientReferenceId == ref)
        ?.clientReferenceId;
  }

  String _resolveHouseholdClientReferenceId(BuildContext context) {
    final fromRoute = widget.householdClientReferenceId;
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final state = _tryHouseholdOverviewState(context);
    return state?.householdMemberWrapper.household?.clientReferenceId ?? '';
  }

  String _resolveAdministrativeAreaCode(BuildContext context) {
    final fromRoute = widget.administrativeAreaCode;
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final state = _tryHouseholdOverviewState(context);
    final addr = state?.householdMemberWrapper.headOfHousehold?.address;
    final code = (addr != null && addr.isNotEmpty)
        ? addr.first.locality?.code
        : null;
    return code ?? RegistrationDeliverySingleton().boundary?.code ?? '';
  }

  /// TB referral screen needs individual + project beneficiary; household may be empty for some households.
  bool _canNavigateToTbRefer(BuildContext context) {
    final individual = _resolveScreeningIndividual(context);
    final pb = _resolveProjectBeneficiaryClientRefId(context);
    return individual != null && (pb != null && pb.isNotEmpty);
  }

  List<String> _referralReasonCodesFromChecklist() {
    final reasons = <String>[];
    final idx = _sortedEligibilityQuestionIndices();
    if (idx.isNotEmpty && controller[idx.first].text.trim() == _yesAnswer) {
      reasons.add('TB_COUGH_TWO_WEEKS');
    }
    for (var i = 1; i < idx.length; i++) {
      if (controller[idx[i]].text.trim() == _yesAnswer) {
        reasons.add('TB_SCREENING_Q${i + 1}');
      }
    }
    if (reasons.isEmpty) reasons.add('ELIGIBILITY_SCREENING');
    return reasons;
  }

  Map<String, dynamic> _checklistPayloadMap(String decidedFlow) {
    final idx = _sortedEligibilityQuestionIndices();
    final map = <String, dynamic>{
      'decidedFlow': decidedFlow,
      'serviceDefinitionCode': selectedServiceDefinition?.code,
    };
    for (var i = 0; i < idx.length; i++) {
      final code = initialAttributes?[idx[i]].code ?? 'QUES${i + 1}';
      map[code] = controller[idx[i]].text.trim();
    }
    final ai = _additionalSymptomsAttributeIndex();
    if (ai != null &&
        (_shouldShowAdditionalSymptomsSection() ||
            controller[ai].text.trim().isNotEmpty)) {
      map['ADDITIONAL_SYMPTOMS'] = controller[ai].text.trim();
    }
    map['childClientReferenceId'] = widget.beneficiaryClientRefId;
    return map;
  }

  void _clearAdditionalSymptomsIfHidden() {
    final ai = _additionalSymptomsAttributeIndex();
    if (ai == null) return;
    if (!_shouldShowAdditionalSymptomsSection()) {
      controller[ai].clear();
    }
  }

  List<AttributesModel> getNextQuestions(
    String parentCode,
    List<AttributesModel> checklistItems,
  ) {
    final childCodePrefix = '$parentCode.';
    final nextCheckLists = checklistItems.where((item) {
      return item.code!.startsWith(childCodePrefix) &&
          item.code?.split('.').length == parentCode.split('.').length + 2;
    }).toList();

    return nextCheckLists;
  }

  int countDots(String inputString) {
    int dotCount = 0;
    for (int i = 0; i < inputString.length; i++) {
      if (inputString[i] == '.') {
        dotCount++;
      }
    }

    return dotCount;
  }

  Widget _buildSurveyForm(
      AttributesModel item,
      int index,
      ServiceDefinitionModel? selectedServiceDefinition,
      BuildContext context,
      String? description) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    /* Check the data type of the attribute*/
    if (item.dataType == 'SingleValueList') {
      final childItems = getNextQuestions(
        item.code.toString(),
        initialAttributes ?? [],
      );
      List<int> excludedIndexes = [];

      // Ensure the current index is added to visible indexes and not excluded
      if (!visibleChecklistIndexes.contains(index) &&
          !excludedIndexes.contains(index)) {
        visibleChecklistIndexes.add(index);
      }

      // Determine excluded indexes
      for (int i = 0; i < (initialAttributes ?? []).length; i++) {
        if (!visibleChecklistIndexes.contains(i)) {
          excludedIndexes.add(i);
        }
      }

      return Align(
        alignment: Alignment.topLeft,
        child: Column(
          children: [
            LabeledField(
                charCondition: true,
                capitalizedFirstLetter: false,
                label: localizations.translate(
                  '${selectedServiceDefinition?.code}.${item.code}',
                ),
                description: description != null
                    ? localizations.translate(
                        '${selectedServiceDefinition?.code}.$description',
                      )
                    : null,
                labelStyle: textTheme.headingM
                    .copyWith(color: theme.colorTheme.text.primary),
                descriptionStyle: textTheme.bodyS
                    .copyWith(color: theme.colorTheme.text.secondary),
                isRequired: item.required ?? false,
                child: Column(children: [
                  BlocBuilder<ServiceBloc, ServiceState>(
                    builder: (context, state) {
                      return Align(
                          alignment: Alignment.topLeft,
                          child: FormField(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value1) {
                                if (item.required == true &&
                                    (controller[index].text == null ||
                                        controller[index].text == '')) {
                                  return localizations.translate(
                                    i18.common.coreCommonReasonRequired,
                                  );
                                }

                                return null;
                              },
                              builder: (field) => RadioList(
                                    radioDigitButtons: item.values != null
                                        ? item.values!
                                            .where((e) =>
                                                e !=
                                                i18.checklist.notSelectedKey)
                                            .toList()
                                            .map((item) => RadioButtonModel(
                                                  code: item,
                                                  name: localizations.translate(
                                                    '${selectedServiceDefinition?.code}.${item.trim()}',
                                                  ),
                                                ))
                                            .toList()
                                        : [],
                                    errorMessage: field.errorText,
                                    sentenceCaseEnabled: false,
                                    groupValue: controller[index].text.trim(),
                                    onChanged: (value) {
                                      field.didChange(value);
                                      context.read<ServiceBloc>().add(
                                            ServiceSurveyFormEvent(
                                              value: Random()
                                                  .nextInt(100)
                                                  .toString(),
                                              submitTriggered: submitTriggered,
                                            ),
                                          );
                                      setState(() {
                                        // Clear child controllers and update visibility
                                        for (final matchingChildItem
                                            in childItems) {
                                          final childIndex = initialAttributes
                                              ?.indexOf(matchingChildItem);
                                          if (childIndex != null) {
                                            // controller[childIndex].clear();
                                            visibleChecklistIndexes.removeWhere(
                                                (v) => v == childIndex);
                                          }
                                        }

                                        // Update the current controller's value
                                        controller[index].value =
                                            TextEditingController.fromValue(
                                          TextEditingValue(
                                            text: value!.code,
                                          ),
                                        ).value;

                                        if (excludedIndexes.isNotEmpty) {
                                          for (int i = 0;
                                              i < excludedIndexes.length;
                                              i++) {
                                            // Clear excluded child controllers
                                            if (item.dataType !=
                                                'SingleValueList') {
                                              // controller[excludedIndexes[i]].value =
                                              //     TextEditingController.fromValue(
                                              //   const TextEditingValue(
                                              //     text: '',
                                              //   ),
                                              // ).value;
                                            }
                                          }
                                        }
                                        _clearAdditionalSymptomsIfHidden();
                                        // Remove corresponding controllers based on the removed attributes
                                      });
                                    },
                                  )));
                    },
                  ),
                  BlocBuilder<ServiceBloc, ServiceState>(
                    builder: (context, state) {
                      return (controller[index].text ==
                                  item.values?[1].trim() &&
                              item.dataType != 'SingleValueList')
                          ? Padding(
                              padding: const EdgeInsets.only(
                                left: spacer1,
                                right: spacer1,
                                bottom: spacer4,
                              ),
                              child: FormField<String>(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (value1) {
                                  if (item.required == true &&
                                      (additionalController[index].text ==
                                              null ||
                                          additionalController[index].text ==
                                              '')) {
                                    return localizations.translate(
                                      i18.common.coreCommonReasonRequired,
                                    );
                                  }

                                  return null;
                                },
                                builder: (field) {
                                  return LabeledField(
                                      label: localizations.translate(
                                        '${selectedServiceDefinition?.code}.${item.code}.ADDITIONAL_FIELD',
                                      ),
                                      description: description != null
                                          ? localizations.translate(
                                              '${selectedServiceDefinition?.code}.$description',
                                            )
                                          : null,
                                      labelStyle: textTheme.headingM.copyWith(
                                          color: theme.colorTheme.text.primary),
                                      descriptionStyle: textTheme.bodyS
                                          .copyWith(
                                              color: theme
                                                  .colorTheme.text.secondary),
                                      isRequired: item.required ?? false,
                                      capitalizedFirstLetter: false,
                                      child: DigitTextFormInput(
                                        onChange: (value) {
                                          field.didChange(value);
                                          additionalController[index].text =
                                              value;
                                        },
                                        errorMessage: field.errorText,
                                        maxLength: 1000,
                                        charCount: true,
                                        controller: additionalController[index],
                                      ));
                                },
                              ),
                            )
                          : const SizedBox();
                    },
                  ),
                  if (childItems.isNotEmpty &&
                      controller[index].text.trim().isNotEmpty) ...[
                    _buildNestedSurveyForm(
                      item.code.toString(),
                      index,
                      controller[index].text.trim(),
                      context,
                      description,
                    ),
                  ],
                ])),
            const DigitDivider(),
          ],
        ),
      );
    } else if (item.dataType == 'String') {
      return FormField<String>(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (((controller[index].text == '') && item.required == true)) {
              return localizations.translate("${item.code}_REQUIRED");
            }
            if (item.regex != null) {
              return (RegExp(item.regex!).hasMatch(controller[index].text!))
                  ? null
                  : localizations.translate("${item.code}_REGEX");
            }

            return null;
          },
          builder: (field) {
            return Column(
              children: [
                LabeledField(
                  label: localizations.translate(
                    '${selectedServiceDefinition?.code}.${item.code}',
                  ),
                  description: description != null
                      ? localizations.translate(
                          '${selectedServiceDefinition?.code}.$description',
                        )
                      : null,
                  labelStyle: textTheme.headingM
                      .copyWith(color: theme.colorTheme.text.primary),
                  descriptionStyle: textTheme.bodyS
                      .copyWith(color: theme.colorTheme.text.secondary),
                  isRequired: item.required ?? false,
                  capitalizedFirstLetter: false,
                  child: DigitTextFormInput(
                    maxLength: 1000,
                    charCount: true,
                    onChange: (value) {
                      field.didChange(value);
                      controller[index].text = value;
                    },
                    errorMessage: field.errorText,
                    controller: controller[index],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(
                        "[a-zA-Z0-9 ]",
                      )),
                    ],
                  ),
                ),
                const DigitDivider(),
              ],
            );
          });
    } else if (item.dataType == 'Number') {
      return FormField<String>(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (((controller[index].text == '') && item.required == true)) {
              return localizations.translate(
                i18.common.corecommonRequired,
              );
            }
            if (item.regex != null) {
              return (RegExp(item.regex!).hasMatch(controller[index].text!))
                  ? null
                  : localizations.translate("${item.code}_REGEX");
            }

            return null;
          },
          builder: (field) {
            return Column(
              children: [
                LabeledField(
                  label: localizations
                      .translate(
                        '${selectedServiceDefinition?.code}.${item.code}',
                      )
                      .trim(),
                  description: description != null
                      ? localizations.translate(
                          '${selectedServiceDefinition?.code}.$description',
                        )
                      : null,
                  labelStyle: textTheme.headingM
                      .copyWith(color: theme.colorTheme.text.primary),
                  descriptionStyle: textTheme.bodyS
                      .copyWith(color: theme.colorTheme.text.secondary),
                  isRequired: item.required ?? false,
                  capitalizedFirstLetter: false,
                  child: DigitTextFormInput(
                    onChange: (value) {
                      field.didChange(value);
                      controller[index].text = value;
                    },
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(
                        "[0-9]",
                      )),
                    ],
                    errorMessage: field.errorText,
                    controller: controller[index],
                  ),
                ),
                const DigitDivider(),
              ],
            );
          });
    } else if (item.dataType == 'MultiValueList') {
      return Align(
        alignment: Alignment.topLeft,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(spacer2),
              child: LabeledField(
                label: localizations.translate(
                  '${selectedServiceDefinition?.code}.${item.code}',
                ),
                description: description != null
                    ? localizations.translate(
                        '${selectedServiceDefinition?.code}.$description',
                      )
                    : null,
                labelStyle: textTheme.headingM
                    .copyWith(color: theme.colorTheme.text.primary),
                descriptionStyle: textTheme.bodyS
                    .copyWith(color: theme.colorTheme.text.secondary),
                isRequired: item.required ?? false,
                capitalizedFirstLetter: false,
                child: BlocBuilder<ServiceBloc, ServiceState>(
                  builder: (context, state) {
                    return Column(
                      children: item.values!
                          .map((e) => DigitCheckbox(
                                label: localizations.translate(
                                    '${selectedServiceDefinition?.code}.${e}'),
                                value: controller[index]
                                    .text
                                    .split('.')
                                    .contains(e),
                                onChanged: (value) {
                                  context.read<ServiceBloc>().add(
                                        ServiceSurveyFormEvent(
                                          value: e.toString(),
                                          submitTriggered: submitTriggered,
                                        ),
                                      );
                                  final String ele;
                                  var val = controller[index].text.split('.');
                                  if (val.contains(e)) {
                                    val.remove(e);
                                    ele = val.join(".");
                                  } else {
                                    ele = "${controller[index].text}.$e";
                                  }
                                  controller[index].value =
                                      TextEditingController.fromValue(
                                    TextEditingValue(
                                      text: ele,
                                    ),
                                  ).value;
                                },
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
            ),
            const DigitDivider(),
          ],
        ),
      );
    } else if (item.dataType == 'Boolean') {
      return Align(
        alignment: Alignment.topLeft,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(spacer2),
              child: LabeledField(
                label: localizations.translate(
                  '${selectedServiceDefinition?.code}.${item.code}',
                ),
                description: description != null
                    ? localizations.translate(
                        '${selectedServiceDefinition?.code}.$description',
                      )
                    : null,
                labelStyle: textTheme.headingM
                    .copyWith(color: theme.colorTheme.text.primary),
                descriptionStyle: textTheme.bodyS
                    .copyWith(color: theme.colorTheme.text.secondary),
                isRequired: item.required ?? false,
                capitalizedFirstLetter: false,
                child: BlocBuilder<ServiceBloc, ServiceState>(
                  builder: (context, state) {
                    return FormField<bool>(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (item.required == true &&
                            (controller[index].text == null ||
                                controller[index].text == '')) {
                          return localizations.translate(
                            i18.common.coreCommonReasonRequired,
                          );
                        }

                        return null;
                      },
                      builder: (field) => SelectionCard(
                        errorMessage: field.errorText,
                        allowMultipleSelection: false,
                        valueMapper: (value) {
                          return value
                              ? localizations.translate(
                                  i18.common.coreCommonYes,
                                )
                              : localizations.translate(
                                  i18.common.coreCommonNo,
                                );
                        },
                        initialSelection: const [false],
                        options: const [true, false],
                        onSelectionChanged: (value) {
                          field.didChange(value.first);
                          context.read<ServiceBloc>().add(
                                ServiceSurveyFormEvent(
                                  value: value.toString(),
                                  submitTriggered: submitTriggered,
                                ),
                              );
                          if (value.isNotEmpty) {
                            controller[index].value = TextEditingValue(
                              text: value.first.toString(),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            const DigitDivider(),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  // Function to build nested SurveyForm for child attributes
  Widget _buildNestedSurveyForm(String parentCode, int parentIndex,
      String parentControllerValue, BuildContext context, String? description) {
    // Retrieve child items for the given parent code
    final childItems = getNextQuestions(
      parentCode,
      initialAttributes ?? [],
    );

    return Column(
      children: [
        // Build cards for each matching child attribute
        for (final matchingChildItem in childItems.where((childItem) =>
            childItem.code!.startsWith('$parentCode.$parentControllerValue.')))
          DigitCard(
            margin: const EdgeInsets.only(
                bottom: spacer2, left: spacer2, right: spacer2),
            cardType: CardType.secondary,
            children: [
              _buildSurveyForm(
                  matchingChildItem,
                  initialAttributes?.indexOf(matchingChildItem) ?? parentIndex,
                  // Pass parentIndex here as we're building at the same level
                  selectedServiceDefinition,
                  context,
                  description)
            ],
          ),
      ],
    );
  }

  void createSubmitRequest({String? decidedFlow}) {
    List<ServiceAttributesModel> attributes = [];
    var referenceId = IdGen.i.identifier;
    for (int i = 0; i < controller.length; i++) {
      final attribute = initialAttributes;
      final attr = attribute?[i];
      final isHiddenAdditional = attr?.code == 'ADDITIONAL_SYMPTOMS' &&
          !_shouldShowAdditionalSymptomsSection();
      attributes.add(ServiceAttributesModel(
        attributeCode: '${attr?.code}',
        dataType: attr?.dataType,
        clientReferenceId: IdGen.i.identifier,
        referenceId: referenceId,
        value: isHiddenAdditional
            ? i18.checklist.notSelectedKey
            : attr?.dataType != 'SingleValueList'
                ? controller[i].text.toString().trim().isNotEmpty
                    ? controller[i].text.toString()
                    : ''
                : visibleChecklistIndexes.contains(i)
                    ? controller[i].text.toString()
                    : i18.checklist.notSelectedKey,
        rowVersion: 1,
        tenantId: attr?.tenantId,
        additionalDetails: null,
      ));
    }

    context.read<ServiceBloc>().add(
          ServiceCreateEvent(
            serviceModel: ServiceModel(
              createdAt: DigitDateUtils.getDateFromTimestamp(
                DateTime.now().toLocal().millisecondsSinceEpoch,
                dateFormat: Constants.checklistViewDateFormat,
              ),
              tenantId: selectedServiceDefinition?.tenantId,
              clientId: referenceId,
              serviceDefId: selectedServiceDefinition?.id,
              attributes: attributes,
              rowVersion: 1,
              accountId: RegistrationDeliverySingleton().projectId,
              additionalDetails: {
                "boundaryCode": RegistrationDeliverySingleton().boundary?.code
              },
              additionalFields: ServiceAdditionalFields(version: 1, fields: [
                AdditionalField(
                    'relatedClientReferenceId', widget.beneficiaryClientRefId),
                AdditionalField('localityCode',
                    RegistrationDeliverySingleton().boundary!.code),
                if (decidedFlow != null)
                  AdditionalField('decidedFlow', decidedFlow)
              ]),
              auditDetails: AuditDetails(
                createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
                createdTime: DateTime.now().millisecondsSinceEpoch,
              ),
              clientAuditDetails: ClientAuditDetails(
                createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
                createdTime: DateTime.now().millisecondsSinceEpoch,
                lastModifiedBy:
                    RegistrationDeliverySingleton().loggedInUserUuid!,
                lastModifiedTime: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
          ),
        );
  }

  Future<void> navigateToDecidedFlow(
    BuildContext navigatorContext,
    StackRouter router,
    String decidedFlow,
  ) async {
    final needsPostChecklistNav =
        decidedFlow == Status.beneficiaryReferred.toValue() ||
            decidedFlow == Status.toAdminister.toValue();

    if (_canNavigateToTbRefer(navigatorContext) && needsPostChecklistNav) {
      if (!navigatorContext.mounted) return;
      final individual = _resolveScreeningIndividual(navigatorContext)!;
      final pbId = _resolveProjectBeneficiaryClientRefId(navigatorContext)!;
      await Navigator.of(navigatorContext, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) {
            final tbChild = TbReferBeneficiaryPage(
              appLocalizations: localizations,
              projectBeneficiaryClientRefId: pbId,
              individual: individual,
              householdClientReferenceId:
                  _resolveHouseholdClientReferenceId(navigatorContext),
              administrativeAreaCode:
                  _resolveAdministrativeAreaCode(navigatorContext),
              referralReasons: _referralReasonCodesFromChecklist(),
              tbScreeningPayload: jsonEncode(_checklistPayloadMap(decidedFlow)),
            );
            final referralRepo = navigatorContext.repository<ReferralModel,
                ReferralSearchModel>(navigatorContext);
            try {
              return MultiBlocProvider(
                providers: [
                  BlocProvider<DeliverInterventionBloc>.value(
                    value: navigatorContext.read<DeliverInterventionBloc>(),
                  ),
                  BlocProvider<SearchHouseholdsBloc>.value(
                    value: navigatorContext.read<SearchHouseholdsBloc>(),
                  ),
                  BlocProvider<HouseholdOverviewBloc>.value(
                    value: navigatorContext.read<HouseholdOverviewBloc>(),
                  ),
                  BlocProvider<ReferralBloc>(
                    create: (_) => ReferralBloc(
                      const ReferralState(),
                      referralRepository: referralRepo,
                    ),
                  ),
                ],
                child: tbChild,
              );
            } catch (_) {
              return BlocProvider<ReferralBloc>(
                create: (c) => ReferralBloc(
                  const ReferralState(),
                  referralRepository: c.repository<ReferralModel,
                      ReferralSearchModel>(c),
                ),
                child: tbChild,
              );
            }
          },
        ),
      );
      if (navigatorContext.mounted) {
        router.maybePop();
      }
      return;
    }

    if (decidedFlow == Status.beneficiaryReferred.toValue()) {
      router.push(BeneficiaryDetailsRoute());
      return;
    }
    if (decidedFlow == Status.toAdminister.toValue()) {
      router.push(BeneficiaryDetailsRoute());
    }
  }
}
