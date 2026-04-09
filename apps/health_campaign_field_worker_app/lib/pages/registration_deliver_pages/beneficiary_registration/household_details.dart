import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/constants.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../bednet_distribution/bednet_household_review.dart';
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
  final TextEditingController _dateController = TextEditingController();

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

    return Scaffold(
      body: ReactiveFormBuilder(
        form: () => buildForm(bloc.state),
        builder: (context, form, child) {
          return BlocBuilder<BeneficiaryRegistrationBloc,
              BeneficiaryRegistrationState>(
            builder: (context, registrationState) {
              return ScrollableContent(
                header: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: spacer2),
                    child: BackNavigationHelpHeaderWidget(showHelp: true),
                  ),
                ]),
                enableFixedDigitButton: true,
                footer: DigitCard(
                    margin: const EdgeInsets.only(top: spacer2),
                    children: [
                      DigitButton(
                        label: registrationState.mapOrNull(
                              editHousehold: (value) => localizations
                                  .translate(i18.common.coreCommonSave),
                            ) ??
                            localizations
                                .translate(i18.householdDetails.actionLabel),
                        type: DigitButtonType.primary,
                        size: DigitButtonSize.large,
                        mainAxisSize: MainAxisSize.max,
                        onPressed: () {
                          form.markAllAsTouched();
                          if (!form.valid) return;
                          bool shouldNavigateNext = false;

                          final memberCount =
                              form.control(_memberCountKey).value as int;
                          final dateOfRegistration = form
                              .control(_dateOfRegistrationKey)
                              .value as DateTime;
                          final headName = form
                              .control(_nameOfIndividualKey)
                              .value as String;
                          final mobile =
                              form.control(_mobileNumberKey).value as String?;

                          registrationState.maybeWhen(
                            orElse: () {},
                            create: (
                              addressModel,
                              householdModel,
                              individualModel,
                              projectBeneficiaryModel,
                              registrationDate,
                              searchQuery,
                              loading,
                              isHeadOfHousehold,
                            ) {
                              final createdAt =
                                  context.millisecondsSinceEpoch();
                              final userUuid = RegistrationDeliverySingleton()
                                      .loggedInUserUuid ??
                                  '';

                              final clientRefId =
                                  individualModel?.clientReferenceId ??
                                      IdGen.i.identifier;

                              var household = householdModel ??
                                  HouseholdModel(
                                    tenantId: RegistrationDeliverySingleton()
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
                              household = household.copyWith(
                                tenantId:
                                    RegistrationDeliverySingleton().tenantId,
                                memberCount: memberCount,
                                address: addressModel,
                              );

                              final individual = IndividualModel(
                                clientReferenceId: clientRefId,
                                tenantId:
                                    RegistrationDeliverySingleton().tenantId,
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
                                  tenantId:
                                      RegistrationDeliverySingleton().tenantId,
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
                              shouldNavigateNext = true;
                            },
                          );

                          if (shouldNavigateNext) {
                            final memberCount =
                                form.control(_memberCountKey).value as int;
                            final headName = (form
                                    .control(_nameOfIndividualKey)
                                    .value as String)
                                .trim();
                            final mobile = (form.control(_mobileNumberKey).value
                                    as String?)
                                ?.trim();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: bloc,
                                  child: BednetHouseholdReviewPage(
                                    headName: headName,
                                    memberCount: memberCount,
                                    mobileNumber: mobile,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ]),
                slivers: [
                  SliverToBoxAdapter(
                    child: DigitCard(
                        margin: const EdgeInsets.all(spacer2),
                        children: [
                          Text(
                            localizations.translate(
                              i18.householdDetails.householdDetailsLabel,
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
                                maxLength: 10,
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
                        ]),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  FormGroup buildForm(BeneficiaryRegistrationState state) {
    final household = state.mapOrNull(
      editHousehold: (value) => value.householdModel,
      create: (value) => value.householdModel,
    );
    final individual = state.mapOrNull(
      editHousehold: (value) => value.headOfHousehold,
      create: (value) => value.individualModel,
    );

    final registrationDate = state.mapOrNull(
      editHousehold: (value) => value.registrationDate,
      create: (value) => DateTime.now(),
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
    });
  }
}
