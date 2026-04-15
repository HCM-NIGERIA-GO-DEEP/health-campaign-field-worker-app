import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../models/entities/additional_fields_type.dart';
import '../../models/registration_deliver_model/entities/status.dart';
import 'package:digit_data_model/models/entities/address_type.dart';
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/utils.dart';

import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../widgets/header/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';
import 'bednet_success_page.dart';

class BednetInformHouseholdPage extends LocalizedStatefulWidget {
  final String eToken;
  final int itnForDelivery;

  /// When set with [existingDeliveryHead], submit uses local DB update (overview
  /// flow) instead of [BeneficiaryRegistrationEvent.summary]/[create], which
  /// require a populated [BeneficiaryRegistrationState.create].
  final HouseholdModel? existingDeliveryHousehold;
  final IndividualModel? existingDeliveryHead;

  const BednetInformHouseholdPage({
    super.key,
    super.appLocalizations,
    required this.eToken,
    required this.itnForDelivery,
    this.existingDeliveryHousehold,
    this.existingDeliveryHead,
  });

  @override
  State<BednetInformHouseholdPage> createState() =>
      _BednetInformHouseholdPageState();
}

class _BednetInformHouseholdPageState
    extends LocalizedState<BednetInformHouseholdPage> {
  static final List<String> _messageKeys = [
    i18.bednetDistribution.netInstruction1,
    i18.bednetDistribution.netInstruction2,
    i18.bednetDistribution.netInstruction3,
    i18.bednetDistribution.netInstruction4,
    i18.bednetDistribution.netInstruction5,
    i18.bednetDistribution.netInstruction6,
    i18.bednetDistribution.netInstruction7,
  ];

  late final List<bool> _checked =
      List<bool>.filled(_messageKeys.length, false);
  bool _isSubmitting = false;

  bool get _existingHouseholdSubmit =>
      widget.existingDeliveryHousehold != null &&
      widget.existingDeliveryHead != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return BlocListener<BeneficiaryRegistrationBloc,
        BeneficiaryRegistrationState>(
      listenWhen: (previous, current) => !_existingHouseholdSubmit,
      listener: (context, state) {
        state.mapOrNull(
          persisted: (_) {
            if (!mounted || _isSubmitting) return;
            _isSubmitting = true;
            final registrationBloc =
                context.read<BeneficiaryRegistrationBloc>();
            // Replace inform screen only so the Material stack below (review →
            // household details → location → search) stays intact and the same
            // [BeneficiaryRegistrationBloc] remains valid for "View household".
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: registrationBloc,
                  child: BednetSuccessPage(
                    eToken: widget.eToken,
                    itnForDelivery: widget.itnForDelivery,
                    appLocalizations: localizations,
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Scaffold(
        body: ScrollableContent(
          enableFixedDigitButton: true,
          header: const BackNavigationHelpHeaderWidget(showHelp: true),
          footer: DigitCard(
            margin: const EdgeInsets.only(top: spacer2),
            children: [
              DigitButton(
                label: localizations.translate(i18.common.coreCommonSubmit),
                type: DigitButtonType.primary,
                size: DigitButtonSize.large,
                mainAxisSize: MainAxisSize.max,
                isDisabled:
                    _checked.contains(false) || _isSubmitting,
                onPressed: _openSubmitDialog,
              ),
            ],
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(spacer2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.translate(
                        i18.bednetDistribution.informHouseholdTitle,
                      ),
                      style: textTheme.headingXl.copyWith(
                        color: const Color(0xFF005A7A),
                      ),
                    ),
                    const SizedBox(height: spacer2),
                    ...List.generate(_messageKeys.length, (idx) {
                      return InkWell(
                        onTap: _isSubmitting
                            ? null
                            : () =>
                                setState(() => _checked[idx] = !_checked[idx]),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: spacer2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFCC4C02),
                                    width: 1.3,
                                  ),
                                ),
                                child: _checked[idx]
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Color(0xFFCC4C02),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: spacer2),
                              Expanded(
                                child: Text(
                                  localizations.translate(_messageKeys[idx]),
                                  style: textTheme.headingXl.copyWith(
                                    fontSize:
                                        (textTheme.headingXl.fontSize ?? 24) *
                                            0.7,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistExistingBednetDelivery(BuildContext context) async {
    final household = widget.existingDeliveryHousehold!;
    final head = widget.existingDeliveryHead!;
    final userUuid = RegistrationDeliverySingleton().loggedInUserUuid ?? '';
    final projectId = RegistrationDeliverySingleton().projectId ?? '';
    final tenantId = RegistrationDeliverySingleton().tenantId;
    final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType!;

    final pbRepo = context.read<
        LocalRepository<ProjectBeneficiaryModel,
            ProjectBeneficiarySearchModel>>();
    final householdRepo = context
        .repository<HouseholdModel, HouseholdSearchModel>(context);
    final taskLocalRepository =
        context.read<LocalRepository<TaskModel, TaskSearchModel>>();

    final benRef = beneficiaryType == BeneficiaryType.individual
        ? head.clientReferenceId
        : household.clientReferenceId;

    final pbs = await pbRepo.search(
      ProjectBeneficiarySearchModel(
        projectId: [projectId],
        beneficiaryClientReferenceId: [benRef],
      ),
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    late final ProjectBeneficiaryModel resolvedPb;
    if (pbs.isNotEmpty) {
      resolvedPb = pbs.first;
      if (resolvedPb.tag != widget.eToken) {
        await pbRepo.update(resolvedPb.copyWith(tag: widget.eToken));
      }
    } else {
      resolvedPb = ProjectBeneficiaryModel(
        tag: widget.eToken,
        rowVersion: 1,
        tenantId: tenantId,
        clientReferenceId: IdGen.i.identifier,
        dateOfRegistration: nowMs,
        projectId: projectId,
        beneficiaryClientReferenceId: benRef,
        clientAuditDetails: ClientAuditDetails(
          createdTime: nowMs,
          lastModifiedTime: nowMs,
          lastModifiedBy: userUuid,
          createdBy: userUuid,
        ),
        auditDetails: AuditDetails(
          createdBy: userUuid,
          createdTime: nowMs,
        ),
      );
      await pbRepo.create(resolvedPb);
    }

    final existingHh = (await householdRepo.search(
          HouseholdSearchModel(
            clientReferenceId: [household.clientReferenceId],
          ),
        ))
            .firstOrNull ??
        household;

    final tokenKey = AdditionalFieldsType.eToken.toValue();
    final fieldList =
        List<AdditionalField>.from(existingHh.additionalFields?.fields ?? []);
    final ti = fieldList.indexWhere((f) => f.key == tokenKey);
    if (ti >= 0) {
      fieldList[ti] = AdditionalField(tokenKey, widget.eToken);
    } else {
      fieldList.add(AdditionalField(tokenKey, widget.eToken));
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

    await _recordHouseholdItnDeliveryTask(
      taskRepo: taskLocalRepository,
      projectBeneficiary: resolvedPb,
      household: existingHh,
      head: head,
      userUuid: userUuid,
      tenantId: tenantId,
    );
  }

  /// Persists the ITN task with the same locality rules as
  /// [DeliverInterventionBloc] create/update (must be awaited so navigation does
  /// not race ahead of the DB write).
  ///
  /// Field correctness vs [CustomHouseholdOverviewPage] / [CustomMemberCard]:
  /// - [TaskModel.projectBeneficiaryClientReferenceId] = [ProjectBeneficiaryModel.clientReferenceId]
  ///   (PB id), not the household/individual beneficiary ref — matches `taskData` filter.
  /// - [TaskModel.status] = [Status.administeredSuccess] so `isDelivered` is true.
  /// - [TaskSearchModel.projectId] is a single project id string (not a list).
  Future<void> _recordHouseholdItnDeliveryTask({
    required LocalRepository<TaskModel, TaskSearchModel> taskRepo,
    required ProjectBeneficiaryModel projectBeneficiary,
    required HouseholdModel household,
    required IndividualModel head,
    required String userUuid,
    required String? tenantId,
  }) async {
    final projectId = RegistrationDeliverySingleton().projectId;
    final boundary = RegistrationDeliverySingleton().boundary;
    // Submit dialog already requires boundary; keep guard if singleton changes.
    if (projectId == null || boundary == null) return;

    final existing = (await taskRepo.search(
      TaskSearchModel(
        projectId: projectId,
        projectBeneficiaryClientReferenceId: [
          projectBeneficiary.clientReferenceId,
        ],
      ),
    )).firstOrNull;

    if (existing?.status == Status.administeredSuccess.toValue()) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final coords = household.bednetLatLngFromAdditionalFields;
    final lat = coords.latitude ??
        head.address?.firstOrNull?.latitude ??
        household.address?.latitude ??
        0.0;
    final lng = coords.longitude ??
        head.address?.firstOrNull?.longitude ??
        household.address?.longitude ??
        0.0;

    final baseAddr = head.address?.firstOrNull ?? household.address;
    final clientRef = existing?.clientReferenceId ?? IdGen.i.identifier;

    final fields = <AdditionalField>[
      const AdditionalField(
        kBednetTaskAdministrationStatusKey,
        kBednetTaskAdministrationSuccessStatus,
      ),
      AdditionalField(kBednetTaskDistributionDateKey, now),
      AdditionalField('householdClientReferenceId', household.clientReferenceId),
      AdditionalField('eToken', widget.eToken),
      AdditionalField('itnDeliveredCount', widget.itnForDelivery),
    ];

    final address = (baseAddr ??
            AddressModel(
              relatedClientReferenceId: clientRef,
              latitude: lat,
              longitude: lng,
              type: AddressType.permanent,
              tenantId: tenantId,
            ))
        .copyWith(
      relatedClientReferenceId: clientRef,
      id: null,
      latitude: lat,
      longitude: lng,
      tenantId: tenantId,
    );

    final TaskModel task;
    if (existing != null) {
      task = existing.copyWith(
        status: Status.administeredSuccess.toValue(),
        additionalFields: TaskAdditionalFields(
          version: existing.additionalFields?.version ?? 1,
          fields: fields,
        ),
        address: address,
      );
    } else {
      task = TaskModel(
        projectBeneficiaryClientReferenceId:
            projectBeneficiary.clientReferenceId,
        clientReferenceId: clientRef,
        tenantId: tenantId,
        rowVersion: 1,
        auditDetails: AuditDetails(
          createdBy: userUuid,
          createdTime: now,
        ),
        clientAuditDetails: ClientAuditDetails(
          createdBy: userUuid,
          createdTime: now,
        ),
        projectId: projectId,
        createdBy: userUuid,
        status: Status.administeredSuccess.toValue(),
        createdDate: now,
        address: address,
        additionalFields: TaskAdditionalFields(version: 1, fields: fields),
      );
    }

    final code = boundary.code;
    final name = boundary.name;
    final localityModel = code == null || name == null
        ? null
        : LocalityModel(code: code, name: name);

    if (existing != null) {
      await taskRepo.update(task);
    } else {
      await taskRepo.create(
        task.copyWith(
          address: task.address?.copyWith(
            locality: localityModel,
          ),
        ),
      );
    }
  }

  void _openSubmitDialog() async {
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => Popup(
        title: localizations.translate(
          i18.bednetDistribution.informHouseholdReadyToSubmitLabel,
        ),
        description: localizations.translate(
          i18.bednetDistribution.informHouseholdSubmitConfirmText,
        ),
        actions: [
          DigitButton(
            label: localizations.translate(i18.common.coreCommonSubmit),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          DigitButton(
            label: localizations.translate(i18.common.coreCommonCancel),
            type: DigitButtonType.tertiary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );

    if (submit != true || !mounted) return;

    final boundary = RegistrationDeliverySingleton().boundary;
    if (boundary == null) return;

    if (_existingHouseholdSubmit) {
      setState(() => _isSubmitting = true);
      try {
        await _persistExistingBednetDelivery(context);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BednetSuccessPage(
              eToken: widget.eToken,
              itnForDelivery: widget.itnForDelivery,
              appLocalizations: localizations,
            ),
          ),
        );
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Bednet existing delivery persist failed: $e\n$st');
        }
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save delivery: $e')),
          );
        }
      }
      return;
    }

    final registrationBloc = context.read<BeneficiaryRegistrationBloc>();
    final userUuid = RegistrationDeliverySingleton().loggedInUserUuid ?? '';
    final projectId = RegistrationDeliverySingleton().projectId ?? '';

    // Build projectBeneficiaryModel with the eToken as tag, then persist.
    registrationBloc.add(BeneficiaryRegistrationEvent.summary(
      userUuid: userUuid,
      projectId: projectId,
      boundary: boundary,
      tag: widget.eToken,
      navigateToSummary: false,
    ));
    registrationBloc.add(BeneficiaryRegistrationEvent.create(
      userUuid: userUuid,
      projectId: projectId,
      boundary: boundary,
      navigateToSummary: false,
    ));
  }
}
