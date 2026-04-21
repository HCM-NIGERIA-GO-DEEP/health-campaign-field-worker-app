import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/blocs/facility/facility.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/enum/app_enums.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/widgets/atoms/digit_button.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/registration_deliver/app_localization.dart';
import '../../../blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import '../../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../../blocs/registration_deliver/search_households/search_households.dart';
import '../../../models/entities/roles_type.dart';
import '../../../models/registration_deliver_model/entities/status.dart';
import '../../../utils/environment_config.dart';
import '../../../utils/registration_deliver_utils/i18_key_constants.dart'
    as i18_local;
import '../../../utils/registration_deliver_utils/utils.dart';
import '../../../utils/utils.dart' hide RegistrationDeliverySingleton;
import '../../../widgets/custom_back_navigation.dart';
import '../../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../../widgets/registartion_deliver/localized.dart';
import 'package:registration_delivery/utils/i18_key_constants.dart' as i18_rd;

/// Referral details after TB screening (facility search required).
class TbReferBeneficiaryPage extends LocalizedStatefulWidget {
  final String projectBeneficiaryClientRefId;
  final IndividualModel individual;
  final String householdClientReferenceId;
  final String administrativeAreaCode;
  final List<String> referralReasons;
  final String tbScreeningPayload;

  const TbReferBeneficiaryPage({
    super.key,
    super.appLocalizations,
    required this.projectBeneficiaryClientRefId,
    required this.individual,
    required this.householdClientReferenceId,
    required this.administrativeAreaCode,
    required this.referralReasons,
    required this.tbScreeningPayload,
  });

  @override
  State<TbReferBeneficiaryPage> createState() => _TbReferBeneficiaryPageState();
}

class _TbReferBeneficiaryPageState
    extends LocalizedState<TbReferBeneficiaryPage> {
  final _busy = ValueNotifier<bool>(false);
  FacilityModel? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FacilityBloc>().add(
            FacilityEvent.loadForProjectId(
              projectId: RegistrationDeliverySingleton().projectId!,
            ),
          );
    });
  }

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  Future<void> _pickFacility(List<FacilityModel> healthFacilities) async {
    final picked =
        await Navigator.of(context, rootNavigator: true).push<FacilityModel>(
      MaterialPageRoute(
        builder: (ctx) => _TbFacilitySearchPage(
          facilities: healthFacilities,
          localizations: localizations,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selected = picked);
    }
  }

  Future<void> _submit(List<FacilityModel> healthFacilities) async {
    if (_selected == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Popup(
        title: localizations.translate(i18_rd.deliverIntervention.dialogTitle),
        type: PopUpType.simple,
        description:
            localizations.translate(i18_rd.deliverIntervention.dialogContent),
        actions: [
          DigitButton(
            label: localizations.translate(i18_rd.common.coreCommonSubmit),
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
          DigitButton(
            label: localizations.translate(i18_rd.common.coreCommonCancel),
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            type: DigitButtonType.secondary,
            size: DigitButtonSize.large,
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    _busy.value = true;
    _busy.value = true;
    final facility = _selected!;

    try {
      await context
          .read<LocalRepository<ReferralModel, ReferralSearchModel>>()
          .create(
            ReferralModel(
              clientReferenceId: IdGen.i.identifier,
              projectId: context.projectId,
              projectBeneficiaryClientReferenceId:
                  widget.projectBeneficiaryClientRefId,
              referrerId: context.loggedInUserUuid,
              recipientId: facility.id,
              recipientType: 'FACILITY',
              reasons: widget.referralReasons.isNotEmpty
                  ? widget.referralReasons
                  : ['TB_SCREENING'],
              tenantId: envConfig.variables.tenantId,
              rowVersion: 1,
              auditDetails: AuditDetails(
                createdBy: context.loggedInUserUuid,
                createdTime: DateTime.now().millisecondsSinceEpoch,
                lastModifiedBy: context.loggedInUserUuid,
                lastModifiedTime: DateTime.now().millisecondsSinceEpoch,
              ),
              clientAuditDetails: ClientAuditDetails(
                createdBy: context.loggedInUserUuid,
                createdTime: DateTime.now().millisecondsSinceEpoch,
                lastModifiedBy: context.loggedInUserUuid,
                lastModifiedTime: DateTime.now().millisecondsSinceEpoch,
              ),
              additionalFields: ReferralAdditionalFields(
                version: 1,
                fields: [
                  const AdditionalField('referralType', 'tbScreening'),
                  AdditionalField(
                    'childClientReferenceId',
                    widget.individual.clientReferenceId,
                  ),
                  AdditionalField(
                    'householdClientReferenceId',
                    widget.householdClientReferenceId,
                  ),
                  AdditionalField(
                    'administrativeAreaCode',
                    widget.administrativeAreaCode,
                  ),
                  AdditionalField(
                    'tbScreeningData',
                    widget.tbScreeningPayload,
                  ),
                ],
              ),
            ),
          );

      final taskRef = IdGen.i.identifier;
      if (!mounted) return;
      context.read<DeliverInterventionBloc>().add(
            DeliverInterventionSubmitEvent(
              task: TaskModel(
                projectBeneficiaryClientReferenceId:
                    widget.projectBeneficiaryClientRefId,
                clientReferenceId: taskRef,
                tenantId: envConfig.variables.tenantId,
                rowVersion: 1,
                createdBy: context.loggedInUserUuid,
                createdDate: DateTime.now().millisecondsSinceEpoch,
                auditDetails: AuditDetails(
                  createdBy: context.loggedInUserUuid,
                  createdTime: DateTime.now().millisecondsSinceEpoch,
                  lastModifiedBy: context.loggedInUserUuid,
                  lastModifiedTime: DateTime.now().millisecondsSinceEpoch,
                ),
                projectId: context.projectId,
                status: Status.beneficiaryReferred.toValue(),
                clientAuditDetails: ClientAuditDetails(
                  createdBy: context.loggedInUserUuid,
                  createdTime: DateTime.now().millisecondsSinceEpoch,
                  lastModifiedBy: context.loggedInUserUuid,
                  lastModifiedTime: DateTime.now().millisecondsSinceEpoch,
                ),
                additionalFields: TaskAdditionalFields(
                  version: 1,
                  fields: [
                    AdditionalField(
                      'taskStatus',
                      Status.beneficiaryReferred.toValue(),
                    ),
                    const AdditionalField('referralType', 'tbScreening'),
                    AdditionalField(
                      'childClientReferenceId',
                      widget.individual.clientReferenceId,
                    ),
                    AdditionalField(
                      'householdClientReferenceId',
                      widget.householdClientReferenceId,
                    ),
                    AdditionalField(
                      'administrativeAreaCode',
                      widget.administrativeAreaCode,
                    ),
                  ],
                ),
                address: widget.individual.address?.firstOrNull?.copyWith(
                  relatedClientReferenceId: taskRef,
                  id: null,
                ),
              ),
              isEditing: false,
              boundaryModel: RegistrationDeliverySingleton().boundary!,
            ),
          );

      if (!mounted) return;
      context
          .read<SearchHouseholdsBloc>()
          .add(const SearchHouseholdsEvent.clear());
      context.read<HouseholdOverviewBloc>().add(
            HouseholdOverviewReloadEvent(
              projectId: context.projectId,
              projectBeneficiaryType:
                  RegistrationDeliverySingleton().beneficiaryType!,
            ),
          );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(true);
    } finally {
      _busy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    return BlocBuilder<FacilityBloc, FacilityState>(
      builder: (ctx, facilityState) {
        final healthFacilities = facilityState.whenOrNull(
              fetched: (facilities, allFacilities) {
                final projectFacilities = facilities
                    .where((e) => e.usage == Constants.healthFacility)
                    .toList();
                return projectFacilities.isEmpty
                    ? allFacilities
                    : projectFacilities;
              },
            ) ??
            [];

        if (facilityState.maybeWhen(loading: () => true, orElse: () => false) &&
            healthFacilities.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: ScrollableContent(
            header: const Column(
              children: [
                CustomBackNavigationHelpHeaderWidget(showHelp: false),
              ],
            ),
            footer: DigitCard(
              margin: const EdgeInsets.only(top: spacer2),
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _busy,
                  builder: (context, busy, _) {
                    return DigitButton(
                      label: localizations.translate(
                        i18_local.common.coreCommonSubmit,
                      ),
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large,
                      mainAxisSize: MainAxisSize.max,
                      isDisabled: busy || _selected == null,
                      onPressed: () => _submit(healthFacilities),
                    );
                  },
                ),
              ],
            ),
            slivers: [
              SliverToBoxAdapter(
                child: DigitCard(
                  margin: const EdgeInsets.symmetric(horizontal: spacer2),
                  children: [
                    Text(
                      localizations.translate(
                        i18_local.referBeneficiary.referralDetails,
                      ),
                      style: textTheme.headingXl.copyWith(
                        color: theme.colorTheme.primary.primary2,
                      ),
                    ),
                    const SizedBox(height: spacer2),
                    LabeledField(
                      label: localizations.translate(
                        i18_local.referBeneficiary.dateOfReferralLabel,
                      ),
                      child: DigitDateFormInput(
                        readOnly: true,
                        initialValue: dateStr,
                        initialDate: DateTime.now(),
                        cancelText: localizations.translate(
                          i18_local.common.coreCommonCancel,
                        ),
                        confirmText: localizations.translate(
                          i18_local.common.coreCommonOk,
                        ),
                      ),
                    ),
                    LabeledField(
                      label: localizations.translate(
                        i18_local.referBeneficiary.administrationUnitFormLabel,
                      ),
                      child: DigitTextFormInput(
                        readOnly: true,
                        initialValue: localizations.translate(
                          widget.administrativeAreaCode,
                        ),
                      ),
                    ),
                    LabeledField(
                      label: localizations.translate(
                        i18_local.referBeneficiary.referredToLabel,
                      ),
                      child: DigitTextFormInput(
                        readOnly: true,
                        initialValue: context.loggedInUser.userName ?? '',
                      ),
                    ),
                    InkWell(
                      onTap: healthFacilities.isEmpty
                          ? null
                          : () => _pickFacility(healthFacilities),
                      child: IgnorePointer(
                        child: LabeledField(
                          label: localizations.translate(
                            i18_local.referBeneficiary.referredByLabel,
                          ),
                          isRequired: true,
                          child: DigitSearchFormInput(
                            initialValue: _selected == null
                                ? ''
                                : localizations.translate(
                                    'FAC_${_selected!.id}',
                                  ),
                            onSuffixTap: (value) async {
                              if (healthFacilities.isNotEmpty) {
                                _pickFacility(healthFacilities);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TbFacilitySearchPage extends StatelessWidget {
  const _TbFacilitySearchPage({
    required this.facilities,
    required this.localizations,
  });

  final List<FacilityModel> facilities;
  final RegistrationDeliveryLocalization localizations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate(i18_local.tbScreening.searchFacilitiesHeader),
        ),
      ),
      body: StatefulBuilder(
        builder: (context, setState) {
          void filter() => setState(() {});

          final q = searchController.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? facilities
              : facilities.where((f) {
                  final name =
                      localizations.translate('FAC_${f.id}').toLowerCase();
                  final id = f.id.toLowerCase();
                  return name.contains(q) || id.contains(q);
                }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: spacer2),
                child: BackNavigationHelpHeaderWidget(
                  showHelp: false,
                  handleBack: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(spacer2),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText:
                        localizations.translate(i18_local.common.searchByName),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => filter(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final f = filtered[index];
                    return ListTile(
                      title: Text(
                        localizations.translate('FAC_${f.id}'),
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        f.id,
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => Navigator.of(context).pop(f),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

bool contextIsMdtUser(BuildContext context) {
  final roles = context.loggedInUser.roles.map((e) => e.code).toSet();
  return roles.contains(RolesType.distributor.toValue()) ||
      roles.contains(RolesType.communityDistributor.toValue());
}

bool contextIsCommunityDistributor(BuildContext context) {
  try {
    final roles = context.loggedInUser.roles.map((e) => e.code).toSet();
    return roles.contains(RolesType.communityDistributor.toValue());
  } catch (_) {
    return false;
  }
}
