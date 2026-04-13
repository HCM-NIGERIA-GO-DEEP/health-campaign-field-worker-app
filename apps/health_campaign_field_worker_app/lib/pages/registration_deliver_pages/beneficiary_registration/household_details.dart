import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import '../../../utils/registration_deliver_utils/constants.dart';
import '../../../widgets/registartion_deliver/localized.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../models/entities/additional_fields_type.dart';

import '../../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../../blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import '../../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../../blocs/registration_deliver/search_households/search_households.dart';
import '../../../data/registration_deliver_repo/local/individual_global_search.dart';
import '../../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../../utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import '../../../utils/registration_deliver_utils/utils.dart';
import '../../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../beneficiary/household_overview.dart';
import '../beneficiary_registration/custom_household_overview.dart';

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

  /// When true, [BlocListener] opens [HouseholdOverviewPage] after persist.
  bool _pendingHouseholdOverviewNavigation = false;

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

  /// Same repositories as [BednetHouseholdOverviewWrapperPage]; required by
  /// [HouseholdOverviewPage] and [DeliverInterventionBloc] when pushed outside
  /// the overview AutoRoute shell.
  Widget _householdOverviewRouteShell({
    required BuildContext context,
    required BeneficiaryRegistrationBloc registrationBloc,
    required HouseholdModel household,
  }) {
    final singleton = RegistrationDeliverySingleton();
    final beneficiaryType = singleton.beneficiaryType;

    if (beneficiaryType == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final sql = context.read<LocalSqlDataStore>();
    final isar = context.read<Isar>();
    final individualGlobalSearchRepository = IndividualGlobalSearchRepository(
      sql,
      IndividualOpLogManager(isar),
    );

    final individual =
        context.repository<IndividualModel, IndividualSearchModel>(context);
    final householdRepo =
        context.repository<HouseholdModel, HouseholdSearchModel>(context);
    final householdMember = context
        .repository<HouseholdMemberModel, HouseholdMemberSearchModel>(context);
    final projectBeneficiary = context.repository<ProjectBeneficiaryModel,
        ProjectBeneficiarySearchModel>(context);
    final task = context.repository<TaskModel, TaskSearchModel>(context);
    final sideEffect =
        context.repository<SideEffectModel, SideEffectSearchModel>(context);
    final referral =
        context.repository<ReferralModel, ReferralSearchModel>(context);

    final taskBeneficiaryRefs = beneficiaryType == BeneficiaryType.individual
        ? null
        : <String>[household.clientReferenceId];

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: registrationBloc),
        BlocProvider(
          create: (_) => HouseholdOverviewBloc(
            HouseholdOverviewState(
              householdMemberWrapper:
                  HouseholdMemberWrapper(household: household),
            ),
            projectBeneficiaryRepository: projectBeneficiary,
            householdRepository: householdRepo,
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
      child: const CustomHouseholdOverviewPage(),
    );
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
          _pendingHouseholdOverviewNavigation &&
          current.mapOrNull(persisted: (_) => true) != null,
      listener: (context, state) {
        state.mapOrNull(
          persisted: (value) async {
            if (!_pendingHouseholdOverviewNavigation) return;
            _pendingHouseholdOverviewNavigation = false;
            try {
              context.read<BednetDistributionBloc>().add(
                    BednetDistributionEvent.updateSelectedSchool(
                      school: value.householdModel,
                    ),
                  );
            } catch (_) {}
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _householdOverviewRouteShell(
                  context: context,
                  registrationBloc: bloc,
                  household: value.householdModel,
                ),
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
                            onPressed: () {
                              form.markAllAsTouched();
                              if (!form.valid) return;

                              final memberCount =
                                  form.control(_memberCountKey).value as int;
                              final childrenCount =
                                  form.control(_childrenCountKey).value as int;
                              final dateOfRegistration = form
                                  .control(_dateOfRegistrationKey)
                                  .value as DateTime;
                              final headName = form
                                  .control(_nameOfIndividualKey)
                                  .value as String;
                              final mobile = form
                                  .control(_mobileNumberKey)
                                  .value as String?;

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
                                  if (!fieldMap.containsKey(
                                      AdditionalFieldsType.eToken.toValue())) {
                                    fieldMap[
                                        AdditionalFieldsType.eToken
                                            .toValue()] = AdditionalField(
                                        AdditionalFieldsType.eToken.toValue(),
                                        '');
                                  }
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
                                    fields: fieldMap.values.toList(),
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
                                    _pendingHouseholdOverviewNavigation = true;
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
                                // Auto-clamp if memberCount was reduced below childrenCount
                                if (currentChildrenCount > currentMemberCount) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    form.control(_childrenCountKey).value =
                                        currentMemberCount;
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
                                      maxValue: currentMemberCount,
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
