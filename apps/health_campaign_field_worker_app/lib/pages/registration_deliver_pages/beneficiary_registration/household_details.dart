import 'dart:math' show max;

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/registration_deliver_utils/constants.dart';
import '../../../widgets/registartion_deliver/localized.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../models/entities/additional_fields_type.dart';

import '../../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../../blocs/registration_deliver/search_households/search_households.dart';
import '../../../pages/bednet_distribution/bednet_household_review.dart';
import '../../../router/app_router.dart';
import '../../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../../utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import '../../../utils/registration_deliver_utils/utils.dart';
import '../../../widgets/registartion_deliver/back_navigation_help_header.dart';

@RoutePage()
class HouseHoldDetailsPage extends LocalizedStatefulWidget {
  const HouseHoldDetailsPage({
    super.key,
    super.appLocalizations,
  });

  @override
  State<HouseHoldDetailsPage> createState() => HouseHoldDetailsPageState();
}

class HouseHoldDetailsPageState extends LocalizedState<HouseHoldDetailsPage> {
  static const _dateOfRegistrationKey = 'dateOfRegistration';
  static const _nameOfIndividualKey = 'nameOfIndividual';
  static const _mobileNumberKey = 'mobileNumber';
  static const _memberCountKey = 'memberCount';
  static const _childrenCountKey = 'childrenCount';
  final TextEditingController _dateController = TextEditingController();

  /// When true, [BlocListener] opens [HouseholdAcknowledgementRoute] after persist
  /// (normal household registration from search → location → this page).
  bool _pendingHouseholdAcknowledgementNavigation = false;

  bool _isHouseholdDetailsViewOnly(BeneficiaryRegistrationState state) {
    return state.maybeMap(
      persisted: (p) => !p.isEdit,
      orElse: () => false,
    );
  }

  void _onBackToSearch(BuildContext context) {
    context
        .read<SearchHouseholdsBloc>()
        .add(const SearchHouseholdsEvent.clear());
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BeneficiaryRegistrationBloc>();
    final textTheme = theme.digitTextTheme(context);

    return BlocListener<BeneficiaryRegistrationBloc,
        BeneficiaryRegistrationState>(
      listenWhen: (previous, current) =>
          _pendingHouseholdAcknowledgementNavigation &&
          current.mapOrNull(persisted: (_) => true) != null,
      listener: (context, state) {
        state.mapOrNull(
          persisted: (value) async {
            if (!_pendingHouseholdAcknowledgementNavigation) return;
            _pendingHouseholdAcknowledgementNavigation = false;
            final nav = Navigator.of(context);
            final household = value.householdModel;
            final householdId = household.clientReferenceId;
            final headName =
                value.individualModel?.name?.givenName?.trim() ?? '';
            final memberCount = household.memberCount ?? 1;
            final eToken = BednetHouseholdReviewPage.syntheticEToken(
              headName: headName.isEmpty ? ' ' : headName,
              memberCount: memberCount,
            );

            await _persistBednetETokenAfterRegistration(
              context: context,
              householdModel: value.householdModel,
              projectBeneficiaryModel: value.projectBeneficiaryModel,
              eToken: eToken,
            );
            if (!context.mounted) return;

            // [BednetHouseholdOverviewWrapperPage] reads selectedSchool in wrappedRoute.
            // Dispatching [updateSelectedSchool] and pushing in the same turn can run
            // navigation before the bloc emits — then selectedSchool is still null.
            bool selectedMatches(BednetDistributionState s) {
              if (s.selectedSchool == null) return false;
              if (householdId.isNotEmpty) {
                return s.selectedSchool!.clientReferenceId == householdId;
              }
              return identical(s.selectedSchool, household);
            }

            try {
              final bednetBloc = context.read<BednetDistributionBloc>();
              bednetBloc.add(
                BednetDistributionEvent.updateSelectedSchool(school: household),
              );
              // Wait until [selectedSchool] matches — do not use [stream.firstWhere]:
              // the bloc stream does not replay the current state, so if the emit
              // happens before we subscribe, [firstWhere] never completes and we
              // never navigate (first-time household submit appeared to "do nothing").
              const step = Duration(milliseconds: 16);
              for (var i = 0; i < 50; i++) {
                if (selectedMatches(bednetBloc.state)) break;
                await Future<void>.delayed(step);
              }
            } catch (_) {
              // No BednetDistributionBloc above this route (unexpected in bednet flow).
            }

            if (!context.mounted) return;

            if (nav.canPop()) nav.pop();
            if (nav.canPop()) nav.pop();

            if (!context.mounted) return;

            // General acknowledgement after registration — not [BednetSuccessPage],
            // which is reserved for after ITN delivery ([BednetInformHouseholdPage]).
            await context.router.root.navigate(
              BednetHouseholdOverviewWrapperRoute(
                children: [
                  HouseholdAcknowledgementRoute(),
                ],
              ),
            );
          },
        );
      },
      child: Scaffold(
        body: ReactiveFormBuilder(
          form: () => buildForm(bloc.state),
          builder: (context, form, child) {
            return BlocBuilder<BeneficiaryRegistrationBloc,
                BeneficiaryRegistrationState>(
              builder: (context, registrationState) {
                final viewOnly = _isHouseholdDetailsViewOnly(registrationState);
                if (viewOnly) {
                  form.markAsDisabled();
                } else {
                  form.markAsEnabled();
                }

                return ScrollableContent(
                  header: const Column(children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: spacer2),
                      child: BackNavigationHelpHeaderWidget(showHelp: false),
                    ),
                  ]),
                  enableFixedDigitButton: true,
                  footer: DigitCard(
                      margin: const EdgeInsets.only(top: spacer2),
                      children: [
                        if (viewOnly)
                          DigitButton(
                            label: localizations.translate(
                              i18.acknowledgementSuccess.actionLabelText,
                            ),
                            type: DigitButtonType.primary,
                            size: DigitButtonSize.large,
                            mainAxisSize: MainAxisSize.max,
                            onPressed: () => _onBackToSearch(context),
                          )
                        else
                          DigitButton(
                            label: registrationState.mapOrNull(
                                  editHousehold: (value) => localizations
                                      .translate(i18.common.coreCommonSave),
                                ) ??
                                localizations.translate(
                                    i18.householdDetails.actionLabel),
                            type: DigitButtonType.primary,
                            size: DigitButtonSize.large,
                            mainAxisSize: MainAxisSize.max,
                            onPressed: () async {
                              form.markAllAsTouched();
                              if (!form.valid) return;

                              final memberCount =
                                  form.control(_memberCountKey).value as int;
                              final childrenCount =
                                  form.control(_childrenCountKey).value as int;
                              if (childrenCount >= memberCount) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      localizations.translate(
                                        i18.householdDetails
                                            .childrenMustBeLessThanMemberCount,
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              final dateOfRegistration = form
                                  .control(_dateOfRegistrationKey)
                                  .value as DateTime;
                              final headName = form
                                  .control(_nameOfIndividualKey)
                                  .value as String;
                              final mobile = form
                                  .control(_mobileNumberKey)
                                  .value as String?;

                              await registrationState.maybeWhen(
                                orElse: () async {},
                                create: (
                                  addressModel,
                                  householdModel,
                                  individualModel,
                                  projectBeneficiaryModel,
                                  registrationDate,
                                  searchQuery,
                                  loading,
                                  isHeadOfHousehold,
                                ) async {
                                  final submit = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => Popup(
                                      title: localizations.translate(
                                        i18.deliverIntervention.dialogTitle,
                                      ),
                                      description: localizations.translate(
                                        i18.deliverIntervention.dialogContent,
                                      ),
                                      actions: [
                                        DigitButton(
                                          label: localizations.translate(
                                            i18.common.coreCommonSubmit,
                                          ),
                                          onPressed: () {
                                            Navigator.of(context,
                                                    rootNavigator: true)
                                                .pop(true);
                                          },
                                          type: DigitButtonType.primary,
                                          size: DigitButtonSize.large,
                                        ),
                                        DigitButton(
                                          label: localizations.translate(
                                            i18.common.coreCommonCancel,
                                          ),
                                          onPressed: () => Navigator.of(context,
                                                  rootNavigator: true)
                                              .pop(false),
                                          type: DigitButtonType.secondary,
                                          size: DigitButtonSize.large,
                                        ),
                                      ],
                                    ),
                                  );
                                  if (!(submit ?? false)) return;
                                  if (!context.mounted) return;

                                  final createdAt =
                                      context.millisecondsSinceEpoch();
                                  final userUuid =
                                      RegistrationDeliverySingleton()
                                              .loggedInUserUuid ??
                                          '';

                                  final clientRefId =
                                      individualModel?.clientReferenceId ??
                                          IdGen.i.identifier;

                                  var household = householdModel ??
                                      HouseholdModel(
                                        tenantId:
                                            RegistrationDeliverySingleton()
                                                .tenantId,
                                        clientReferenceId: IdGen.i.identifier,
                                        rowVersion: 1,
                                        auditDetails: AuditDetails(
                                          createdBy: userUuid,
                                          createdTime: createdAt,
                                          lastModifiedBy: userUuid,
                                          lastModifiedTime: createdAt,
                                        ),
                                        clientAuditDetails: ClientAuditDetails(
                                          createdBy: userUuid,
                                          createdTime: createdAt,
                                          lastModifiedBy: userUuid,
                                          lastModifiedTime: createdAt,
                                        ),
                                      );

                                  var existingFields =
                                      household.additionalFields?.fields ?? [];
                                  var fieldMap = {
                                    for (var f in existingFields) f.key: f
                                  };
                                  // Do not add placeholder e-Token with an empty value: the
                                  // service validates each field value length as 1–10000.
                                  fieldMap[
                                      AdditionalFieldsType.latitude
                                          .toValue()] = AdditionalField(
                                      AdditionalFieldsType.latitude.toValue(),
                                      addressModel?.latitude?.toString() ?? '');
                                  fieldMap[
                                      AdditionalFieldsType.longitude
                                          .toValue()] = AdditionalField(
                                      AdditionalFieldsType.longitude.toValue(),
                                      addressModel?.longitude?.toString() ??
                                          '');
                                  fieldMap[AdditionalFieldsType.childrenUnder5
                                          .toValue()] =
                                      AdditionalField(
                                          AdditionalFieldsType.childrenUnder5
                                              .toValue(),
                                          childrenCount.toString());
                                  final newAdditionalFields =
                                      HouseholdAdditionalFields(
                                    version:
                                        household.additionalFields?.version ??
                                            1,
                                    fields: fieldMap.values
                                        .where((f) =>
                                            f.value != null &&
                                            f.value
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                        .toList(),
                                  );

                                  household = household.copyWith(
                                    tenantId: RegistrationDeliverySingleton()
                                        .tenantId,
                                    memberCount: memberCount,
                                    address: addressModel,
                                    latitude: addressModel?.latitude,
                                    longitude: addressModel?.longitude,
                                    additionalFields: newAdditionalFields,
                                  );

                                  final individual = IndividualModel(
                                    clientReferenceId: clientRefId,
                                    tenantId: RegistrationDeliverySingleton()
                                        .tenantId,
                                    rowVersion: 1,
                                    mobileNumber: mobile,
                                    auditDetails: AuditDetails(
                                      createdBy: userUuid,
                                      createdTime: createdAt,
                                      lastModifiedBy: userUuid,
                                      lastModifiedTime: createdAt,
                                    ),
                                    clientAuditDetails: ClientAuditDetails(
                                      createdBy: userUuid,
                                      createdTime: createdAt,
                                      lastModifiedBy: userUuid,
                                      lastModifiedTime: createdAt,
                                    ),
                                    name: NameModel(
                                      givenName: headName.trim(),
                                      individualClientReferenceId: clientRefId,
                                      tenantId: RegistrationDeliverySingleton()
                                          .tenantId,
                                      rowVersion: 1,
                                      auditDetails: AuditDetails(
                                        createdBy: userUuid,
                                        createdTime: createdAt,
                                        lastModifiedBy: userUuid,
                                        lastModifiedTime: createdAt,
                                      ),
                                      clientAuditDetails: ClientAuditDetails(
                                        createdBy: userUuid,
                                        createdTime: createdAt,
                                        lastModifiedBy: userUuid,
                                        lastModifiedTime: createdAt,
                                      ),
                                    ),
                                  );

                                  bloc.add(
                                    BeneficiaryRegistrationEvent
                                        .saveIndividualDetails(
                                      model: individual,
                                      isHeadOfHousehold: true,
                                    ),
                                  );
                                  bloc.add(
                                    BeneficiaryRegistrationSaveHouseholdDetailsEvent(
                                      household: household,
                                      registrationDate: dateOfRegistration,
                                    ),
                                  );
                                  final boundary =
                                      RegistrationDeliverySingleton().boundary;
                                  final projectId =
                                      RegistrationDeliverySingleton().projectId;
                                  final loggedInUuid =
                                      RegistrationDeliverySingleton()
                                          .loggedInUserUuid;
                                  if (boundary != null &&
                                      projectId != null &&
                                      loggedInUuid != null) {
                                    _pendingHouseholdAcknowledgementNavigation =
                                        true;
                                    bloc.add(
                                      BeneficiaryRegistrationSummaryEvent(
                                        userUuid: loggedInUuid,
                                        projectId: projectId,
                                        boundary: boundary,
                                        tag: null,
                                      ),
                                    );
                                    bloc.add(
                                      BeneficiaryRegistrationCreateEvent(
                                        projectId: projectId,
                                        userUuid: loggedInUuid,
                                        boundary: boundary,
                                        tag: null,
                                        navigateToSummary: false,
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                      ]),
                  slivers: [
                    SliverToBoxAdapter(
                      child: IgnorePointer(
                        ignoring: viewOnly,
                        child: DigitCard(
                          margin: const EdgeInsets.all(spacer2),
                          children: [
                            Text(
                              localizations.translate(
                                i18.householdDetails.householdRegistrationLabel,
                              ),
                              style: textTheme.headingXl.copyWith(
                                color: const Color(0xFF005A7A),
                              ),
                            ),
                            ReactiveWrapperField(
                              formControlName: _dateOfRegistrationKey,
                              builder: (field) => LabeledField(
                                label: localizations.translate(
                                  i18.householdDetails.dateOfRegistrationLabel,
                                ),
                                child: DigitDateFormInput(
                                  controller: _dateController
                                    ..text = DateFormat(
                                            Constants().dateMonthYearFormat)
                                        .format(
                                      form.control(_dateOfRegistrationKey).value
                                          as DateTime,
                                    ),
                                  confirmText: localizations.translate(
                                    i18.common.coreCommonOk,
                                  ),
                                  cancelText: localizations.translate(
                                    i18.common.coreCommonCancel,
                                  ),
                                  onChange: (value) {
                                    if (value.trim().isEmpty) return;
                                    final parsed = DateFormat(
                                            Constants().dateMonthYearFormat)
                                        .parse(value);
                                    form.control(_dateOfRegistrationKey).value =
                                        parsed;
                                  },
                                ),
                              ),
                            ),
                            ReactiveWrapperField(
                              formControlName: _nameOfIndividualKey,
                              validationMessages: {
                                'required': (_) => localizations.translate(
                                      i18.common.corecommonRequired,
                                    ),
                              },
                              builder: (field) => LabeledField(
                                label: localizations.translate(
                                  i18.individualDetails.nameLabelText,
                                ),
                                isRequired: true,
                                child: DigitTextFormInput(
                                  initialValue:
                                      form.control(_nameOfIndividualKey).value,
                                  onChange: (value) => form
                                      .control(_nameOfIndividualKey)
                                      .value = value,
                                  errorMessage: field.errorText,
                                ),
                              ),
                            ),
                            ReactiveWrapperField(
                              formControlName: _mobileNumberKey,
                              validationMessages: {
                                'mobilePattern': (_) => localizations.translate(
                                      i18.common.coreCommonMobileNumber,
                                    ),
                              },
                              builder: (field) => LabeledField(
                                label: localizations.translate(
                                  i18.individualDetails.mobileNumberLabelText,
                                ),
                                child: DigitTextFormInput(
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  maxLength: 11,
                                  initialValue:
                                      form.control(_mobileNumberKey).value,
                                  onChange: (value) => form
                                      .control(_mobileNumberKey)
                                      .value = value,
                                  errorMessage: field.errorText,
                                ),
                              ),
                            ),
                            ReactiveWrapperField(
                              formControlName: _memberCountKey,
                              builder: (field) => LabeledField(
                                label: localizations.translate(
                                  i18.householdDetails.noOfMembersCountLabel,
                                ),
                                isRequired: true,
                                child: DigitNumericFormInput(
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  minValue: 1,
                                  maxValue: 100,
                                  step: 1,
                                  initialValue: form
                                      .control(_memberCountKey)
                                      .value
                                      .toString(),
                                  onChange: (value) {
                                    if (value.isEmpty) return;
                                    form.control(_memberCountKey).value =
                                        int.parse(value);
                                  },
                                ),
                              ),
                            ),
                            ReactiveFormConsumer(
                              builder: (context, form, _) {
                                final currentMemberCount = (form
                                        .control(_memberCountKey)
                                        .value as int?) ??
                                    1;
                                final currentChildrenCount = (form
                                        .control(_childrenCountKey)
                                        .value as int?) ??
                                    0;
                                final maxChildrenAllowed =
                                    max(0, currentMemberCount - 1);
                                // Auto-clamp when member count drops or cap is exceeded
                                if (currentChildrenCount > maxChildrenAllowed) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    form.control(_childrenCountKey).value =
                                        maxChildrenAllowed;
                                  });
                                }
                                return ReactiveWrapperField(
                                  formControlName: _childrenCountKey,
                                  builder: (field) => LabeledField(
                                    label: localizations.translate(
                                      i18.householdDetails
                                          .noOfChildrenBelow5YearsLabel,
                                    ),
                                    isRequired: true,
                                    child: DigitNumericFormInput(
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      minValue: 0,
                                      maxValue: maxChildrenAllowed,
                                      step: 1,
                                      initialValue: form
                                          .control(_childrenCountKey)
                                          .value
                                          .toString(),
                                      onChange: (value) {
                                        if (value.isEmpty) return;
                                        form.control(_childrenCountKey).value =
                                            int.parse(value);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _persistBednetETokenAfterRegistration({
    required BuildContext context,
    required HouseholdModel householdModel,
    required ProjectBeneficiaryModel? projectBeneficiaryModel,
    required String eToken,
  }) async {
    if (!context.mounted) return;
    final userUuid = RegistrationDeliverySingleton().loggedInUserUuid ?? '';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      final householdRepo =
          context.repository<HouseholdModel, HouseholdSearchModel>(context);
      final existingHh = (await householdRepo.search(
            HouseholdSearchModel(
              clientReferenceId: [householdModel.clientReferenceId],
            ),
          ))
              .firstOrNull ??
          householdModel;

      final tokenKey = AdditionalFieldsType.eToken.toValue();
      final fieldList =
          List<AdditionalField>.from(existingHh.additionalFields?.fields ?? []);
      final ti = fieldList.indexWhere((f) => f.key == tokenKey);
      if (ti >= 0) {
        fieldList[ti] = AdditionalField(tokenKey, eToken);
      } else {
        fieldList.add(AdditionalField(tokenKey, eToken));
      }

      await householdRepo.update(
        existingHh.copyWith(
          additionalFields: HouseholdAdditionalFields(
            version: existingHh.additionalFields?.version ?? 1,
            fields: fieldList,
          ),
          clientAuditDetails: ClientAuditDetails(
            createdBy: existingHh.clientAuditDetails?.createdBy ??
                existingHh.auditDetails?.createdBy.toString() ??
                userUuid,
            createdTime: existingHh.clientAuditDetails?.createdTime ??
                existingHh.auditDetails?.createdTime ??
                nowMs,
            lastModifiedBy: userUuid,
            lastModifiedTime: nowMs,
          ),
          id: existingHh.id,
          rowVersion: existingHh.rowVersion ?? 1,
          nonRecoverableError: existingHh.nonRecoverableError ?? false,
        ),
      );
    } catch (_) {}

    try {
      final pbRepo = context.read<
          LocalRepository<ProjectBeneficiaryModel,
              ProjectBeneficiarySearchModel>>();
      if (projectBeneficiaryModel != null &&
          projectBeneficiaryModel.tag != eToken) {
        await pbRepo.update(
          projectBeneficiaryModel.copyWith(tag: eToken),
        );
      }
    } catch (_) {}
  }

  FormGroup buildForm(BeneficiaryRegistrationState state) {
    final household = state.mapOrNull(
      editHousehold: (value) => value.householdModel,
      create: (value) => value.householdModel,
      persisted: (value) => value.householdModel,
    );
    final individual = state.mapOrNull(
      editHousehold: (value) => value.headOfHousehold,
      create: (value) => value.individualModel,
      persisted: (value) => value.individualModel,
    );

    final registrationDate = state.mapOrNull(
      editHousehold: (value) => value.registrationDate,
      create: (value) => DateTime.now(),
      persisted: (value) => value.registrationDate ?? DateTime.now(),
    );

    return fb.group(<String, Object>{
      _dateOfRegistrationKey:
          FormControl<DateTime>(value: registrationDate, validators: []),
      _nameOfIndividualKey: FormControl<String>(
        value: individual?.name?.givenName ?? '',
        validators: [Validators.required],
      ),
      _mobileNumberKey: FormControl<String>(
        value: individual?.mobileNumber,
        validators: [
          Validators.pattern(
            Constants.mobileNumberRegExp,
            validationMessage: 'mobilePattern',
          ),
        ],
      ),
      _memberCountKey: FormControl<int>(
        value: household?.memberCount ?? 1,
      ),
      _childrenCountKey: FormControl<int>(
        value: int.tryParse(
              household?.additionalFields?.fields
                      .firstWhere(
                        (f) =>
                            f.key ==
                            AdditionalFieldsType.childrenUnder5.toValue(),
                        orElse: () => AdditionalField(
                            AdditionalFieldsType.childrenUnder5.toValue(), '0'),
                      )
                      .value
                      .toString() ??
                  '0',
            ) ??
            0,
      ),
    });
  }
}
