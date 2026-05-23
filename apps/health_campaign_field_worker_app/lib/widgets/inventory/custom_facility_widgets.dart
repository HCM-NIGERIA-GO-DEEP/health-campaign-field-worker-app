import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/widgets/base_reactive_field_wrapper.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../blocs/project/project.dart';
import '../../models/entities/roles_type.dart';
import '../../utils/extensions/extensions.dart';
import '../../utils/facility_usage_filter.dart';
import '../localized.dart';

class FacilityCard extends LocalizedStatefulWidget {
  final String formKey;
  final String dependantFormKey;
  final dynamic stateData;
  final String schemaName;

  const FacilityCard(
      {super.key,
      super.appLocalizations,
      required this.formKey,
      required this.dependantFormKey,
      required this.stateData,
      required this.schemaName});

  @override
  State<FacilityCard> createState() => _FacilityCardState();
}

class _FacilityCardState extends LocalizedState<FacilityCard> {
  @override
  Widget build(BuildContext context) {
    final pages =
        context.read<FormsBloc>().state.cachedSchemas[widget.schemaName]?.pages;

    if (pages == null) {
      return const SizedBox.shrink();
    }

    PropertySchema? fieldSchema;
    void findSchema(Map<String, PropertySchema> node) {
      for (final entry in node.entries) {
        if (entry.key == widget.formKey) {
          fieldSchema = entry.value;
          return;
        }
        if (entry.value.properties != null &&
            entry.value.properties!.isNotEmpty) {
          findSchema(entry.value.properties!);
        }
      }
    }

    findSchema(pages);

    if (fieldSchema == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<FlowCrudState?>(
      valueListenable:
          FlowCrudStateRegistry().listen('FORM::${widget.schemaName}'),
      builder: (context, flowState, _) {
        return _FacilityCardContent(
          formKey: widget.formKey,
          dependantFormKey: widget.dependantFormKey,
          fieldSchema: fieldSchema!,
          stateData: widget.stateData,
          pageSchema: widget.schemaName,
          localizations: localizations,
        );
      },
    );
  }
}

class _FacilityCardContent extends StatefulWidget {
  final String formKey;
  final String dependantFormKey;
  final PropertySchema fieldSchema;
  final String pageSchema;
  final dynamic stateData;
  final dynamic localizations;

  const _FacilityCardContent({
    required this.formKey,
    required this.dependantFormKey,
    required this.fieldSchema,
    required this.pageSchema,
    required this.stateData,
    required this.localizations,
  });

  @override
  State<_FacilityCardContent> createState() => _FacilityCardContentState();
}

class _FacilityCardContentState extends State<_FacilityCardContent> {
  bool _requestedFacilitiesLoad = false;
  bool _isLoadingFacilitiesFromDb = false;
  List<FacilityModel> _facilitiesForProject = const [];
  bool _isLoadingStockFacilityIds = false;
  Set<String>? _stockFacilityIdsForDistributor;
  List<ProjectFacilityModel> _stockProjectFacilitiesForDistributor = const [];

  String get formKey => widget.formKey;
  String get dependantFormKey => widget.dependantFormKey;
  PropertySchema get fieldSchema => widget.fieldSchema;
  String get pageSchema => widget.pageSchema;
  dynamic get stateData => widget.stateData;
  dynamic get localizations => widget.localizations;

  void _maybeLoadFacilitiesForSelectedProject() {
    if (_requestedFacilitiesLoad) return;

    FacilityBloc? facilityBloc;
    try {
      facilityBloc = context.read<FacilityBloc>();
    } catch (_) {
      facilityBloc = null;
    }
    if (facilityBloc == null) return;

    String? projectId;
    try {
      projectId = context.read<ProjectBloc>().state.selectedProject?.id;
    } catch (_) {
      projectId = null;
    }
    if (projectId == null || projectId.isEmpty) return;

    _requestedFacilitiesLoad = true;
    facilityBloc.add(
      FacilityEvent.loadForProjectId(
        projectId: projectId,
        loadAllProjects: false,
      ),
    );
  }

  void _scheduleFacilityDetailsLoadIfNeeded(
    List<ProjectFacilityModel> currentLevelProjectFacilities,
    String usageForFilter,
  ) {
    if (usageForFilter.trim().isEmpty || usageForFilter == 'None') return;
    if (currentLevelProjectFacilities.isEmpty) return;
    if (_facilitiesForProject.isNotEmpty || _isLoadingFacilitiesFromDb) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_facilitiesForProject.isNotEmpty || _isLoadingFacilitiesFromDb) {
        return;
      }
      _loadFacilitiesForCurrentProject(currentLevelProjectFacilities);
    });
  }

  Future<void> _loadFacilitiesForCurrentProject(
    List<ProjectFacilityModel> projectFacilities,
  ) async {
    if (_isLoadingFacilitiesFromDb || projectFacilities.isEmpty) return;

    setState(() {
      _isLoadingFacilitiesFromDb = true;
    });

    try {
      final facilityIds =
          projectFacilities.map((pf) => pf.facilityId).toSet().toList();

      final facilityRepo =
          context.read<LocalRepository<FacilityModel, FacilitySearchModel>>();

      final facilities = await facilityRepo.search(
        FacilitySearchModel(id: facilityIds),
      );

      if (!mounted) return;
      setState(() {
        _facilitiesForProject = facilities;
        _isLoadingFacilitiesFromDb = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFacilitiesFromDb = false;
      });
    }
  }

  /// Read current selected value from form data or form control
  String? _getCurrentValue(AbstractControl<dynamic>? control) {
    final controlValue = control?.value?.toString();
    if (controlValue != null && controlValue.isNotEmpty) {
      return controlValue;
    }

    final formData = stateData?.formData as Map<String, dynamic>?;
    if (formData == null) return null;

    final value = formData['warehouseDetails.$formKey'] ??
        formData[formKey] ??
        (formData['warehouseDetails'] as Map<String, dynamic>?)?[formKey] ??
        (formData['stockDetails'] as Map<String, dynamic>?)?[formKey];

    return (value != null && value.toString().isNotEmpty)
        ? value.toString()
        : null;
  }

  String _getDisplayName(String facilityId, String? deliveryTeamCode) {
    if (facilityId == deliveryTeamCode) {
      return localizations.translate('DELIVERY_TEAM');
    }
    final isUuid = facilityId.contains('-') && !facilityId.startsWith('F-');
    return isUuid ? facilityId : localizations.translate('FAC_$facilityId');
  }

  bool _isDeliveryTeamCode(String id) {
    final value = id.trim();
    return value == 'DELIVERY_TEAM' ||
        value == 'Delivery Team' ||
        value.startsWith('DELIVERY');
  }

  void _addStockFacilityCandidate(
    Set<String> ids,
    String? candidate,
    String receiverId,
  ) {
    final value = candidate?.trim();
    if (value == null || value.isEmpty) return;
    if (value == receiverId) return;
    if (_isDeliveryTeamCode(value)) return;
    ids.add(value);
  }

  void _scheduleStockFacilityIdsLoadIfNeeded({
    required bool enabled,
    required String receiverId,
    required String? projectId,
  }) {
    if (!enabled) return;
    if (receiverId.isEmpty) return;
    if (projectId == null || projectId.isEmpty) return;
    if (_stockFacilityIdsForDistributor != null || _isLoadingStockFacilityIds) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_stockFacilityIdsForDistributor != null ||
          _isLoadingStockFacilityIds) {
        return;
      }
      _loadStockFacilitiesForDistributor(
        receiverId: receiverId,
        projectId: projectId,
      );
    });
  }

  Future<void> _loadStockFacilitiesForDistributor({
    required String receiverId,
    required String projectId,
  }) async {
    setState(() {
      _isLoadingStockFacilityIds = true;
    });

    try {
      final stockRepo =
          context.read<LocalRepository<StockModel, StockSearchModel>>();
      final projectFacilityRepo = context.read<
          LocalRepository<ProjectFacilityModel, ProjectFacilitySearchModel>>();
      final facilityRepo =
          context.read<LocalRepository<FacilityModel, FacilitySearchModel>>();
      final stocks = await stockRepo.search(
        StockSearchModel(receiverId: receiverId),
      );

      final facilityIds = <String>{};
      for (final stock in stocks) {
        if (stock.receiverId != receiverId) continue;

        _addStockFacilityCandidate(facilityIds, stock.senderId, receiverId);
        _addStockFacilityCandidate(facilityIds, stock.facilityId, receiverId);
        _addStockFacilityCandidate(
          facilityIds,
          stock.transactingPartyId,
          receiverId,
        );
      }

      final stockProjectFacilities = facilityIds.isEmpty
          ? <ProjectFacilityModel>[]
          : await projectFacilityRepo.search(
              ProjectFacilitySearchModel(
                facilityId: facilityIds.toList(),
              ),
            );

      final stockProjectFacilityIds =
          stockProjectFacilities.map((pf) => pf.facilityId).toSet().toList();
      final stockFacilities = stockProjectFacilityIds.isEmpty
          ? <FacilityModel>[]
          : await facilityRepo.search(
              FacilitySearchModel(id: stockProjectFacilityIds),
            );

      if (!mounted) return;
      setState(() {
        final facilitiesById = {
          for (final facility in _facilitiesForProject) facility.id: facility,
          for (final facility in stockFacilities) facility.id: facility,
        };
        _stockFacilityIdsForDistributor = facilityIds;
        _stockProjectFacilitiesForDistributor = stockProjectFacilities;
        _facilitiesForProject = facilitiesById.values.toList();
        _isLoadingStockFacilityIds = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stockFacilityIdsForDistributor = <String>{};
        _stockProjectFacilitiesForDistributor = const [];
        _isLoadingStockFacilityIds = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeLoadFacilitiesForSelectedProject();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Union both keys — plain [pageSchema] often holds stockEntryType from
    // NAVIGATION actions; a sparse `FORM::` map must not hide those keys.
    final navigationParams = <String, dynamic>{
      ...?FlowCrudStateRegistry().getNavigationParams('FORM::$pageSchema'),
      ...?FlowCrudStateRegistry().getNavigationParams(pageSchema),
    };
    final transactionType =
        navigationParams['transactionType']?.toString() ?? '';
    final stockEntryType = navigationParams['stockEntryType']?.toString() ?? '';
    final isReturnFlow = stockEntryType == 'RETURNED' ||
        stockEntryType == 'LOSS' ||
        stockEntryType == 'DAMAGED';
    final isLessExcessFlow =
        stockEntryType == 'LESS_EXCESS' || stockEntryType == 'EXCESS';

    final deliveryTeamCodeFromSchema =
        getDeliveryTeamCodeFromFacilityHierarchy(fieldSchema, transactionType);
    final deliveryTeamCode = deliveryTeamCodeFromSchema ?? 'DELIVERY_TEAM';

    final roleBasedDeliveryTeam = context.loggedInUserRoles.any(
          (role) => role.code == RolesType.distributor.toValue(),
        ) ||
        context.loggedInUserRoles.any(
          (role) => role.code == RolesType.communityDistributor.toValue(),
        );

    final hasDeliveryTeamInConfig =
        deliveryTeamCodeFromSchema != null || roleBasedDeliveryTeam;

    final isWareHouseMgr = context.loggedInUserRoles
        .any((role) => role.code == RolesType.warehouseManager.toValue());

    final isDistributor = context.loggedInUserRoles.any(
      (role) => role.code == RolesType.distributor.toValue(),
    );

    final isCommunityDistributor = context.loggedInUserRoles.any(
      (role) => role.code == RolesType.communityDistributor.toValue(),
    );

    final isHfs = context.loggedInUserRoles.any(
      (role) =>
          role.code == RolesType.healthFacilitySupervisor.toValue() ||
          role.code == RolesType.healthFacilityWorker.toValue(),
    );

    String? boundaryLevel;
    String? projectId;
    try {
      final selectedProject = context.read<ProjectBloc>().state.selectedProject;
      boundaryLevel = selectedProject?.address?.boundaryType;
      projectId = selectedProject?.id;
    } catch (_) {
      boundaryLevel = null;
      projectId = null;
    }

    var wrapperData = stateData?.stateWrapper;
    if (wrapperData == null) {
      final formState = FlowCrudStateRegistry().get('FORM::$pageSchema') ??
          FlowCrudStateRegistry().get(pageSchema);
      wrapperData = formState?.stateWrapper;
    }

    List<dynamic>? projectFacilities;
    if (wrapperData != null && wrapperData is List && wrapperData.isNotEmpty) {
      final firstItem = wrapperData.first;
      if (firstItem is Map) {
        final wrapperList = wrapperData as List<Map<String, List<dynamic>>>;
        projectFacilities = wrapperList.firstWhere(
            (m) => m.containsKey('ProjectFacilityModel'),
            orElse: () => {'ProjectFacilityModel': []})['ProjectFacilityModel'];
      } else if (firstItem is ProjectFacilityModel) {
        projectFacilities = wrapperData;
      } else {
        projectFacilities =
            wrapperData.whereType<ProjectFacilityModel>().toList();
      }
    }
    projectFacilities ??= [];

    final labelFromSchema = fieldSchema.label ?? fieldSchema.innerLabel;

    final isToField = formKey == 'facilityToWhich';
    final isFromField = formKey == 'facilityFromWhich';

    var typedProjectFacilities =
        projectFacilities.cast<ProjectFacilityModel>().toList();

    final usageResolution = resolveFacilityUsageForInventory(
      stockEntryType: stockEntryType,
      transactionType: transactionType,
      isToField: isToField,
      isFromField: isFromField,
      boundaryType: boundaryLevel,
      isWareHouseMgr: isWareHouseMgr,
      isDistributor: isDistributor,
      isCommunityDistributor: isCommunityDistributor,
      isHfs: isHfs,
    );

    final isDistributorRole = isDistributor || isCommunityDistributor;
    final shouldFilterByDistributorStockFacilities =
        stockEntryType == 'RETURNED' && isDistributorRole && isToField;
    _scheduleStockFacilityIdsLoadIfNeeded(
      enabled: shouldFilterByDistributorStockFacilities,
      receiverId: context.loggedInUserUuid,
      projectId: projectId,
    );

    if (shouldFilterByDistributorStockFacilities &&
        _stockProjectFacilitiesForDistributor.isNotEmpty) {
      typedProjectFacilities = {
        for (final facility in typedProjectFacilities)
          facility.facilityId: facility,
        for (final facility in _stockProjectFacilitiesForDistributor)
          facility.facilityId: facility,
      }.values.toList();
    }

    // final currentLevelForLoad =
    //     filterProjectFacilitiesToCurrentLevel(typedProjectFacilities);
    _scheduleFacilityDetailsLoadIfNeeded(
      typedProjectFacilities,
      usageResolution.usage,
    );

    final filteredFacilities = filterProjectFacilitiesByFacilityUsage(
      projectFacilities: typedProjectFacilities,
      facilitiesFromDb: _facilitiesForProject,
      isLoadingFacilitiesFromDb: _isLoadingFacilitiesFromDb,
      usage: usageResolution.usage,
      additionalUsage: usageResolution.additionalUsage,
    );

    final stockScopedFacilities = shouldFilterByDistributorStockFacilities
        ? (_stockFacilityIdsForDistributor == null
            ? <ProjectFacilityModel>[]
            : filteredFacilities
                .where((facility) => _stockFacilityIdsForDistributor!
                    .contains(facility.facilityId))
                .toList())
        : filteredFacilities;

    final hasNoChildFacilities = isToField &&
        (transactionType == 'DISPATCHED' || transactionType == 'ISSUED') &&
        stockScopedFacilities.isEmpty;

    var facilities = <DropdownItem>[];

    final showDeliveryTeam = hasDeliveryTeamInConfig &&
        ((isToField &&
                !isReturnFlow &&
                (transactionType == 'DISPATCHED' ||
                    transactionType == 'ISSUED') &&
                (!isWareHouseMgr || hasNoChildFacilities)) ||
            (isFromField &&
                !isWareHouseMgr &&
                (isReturnFlow || isLessExcessFlow)));

    if (showDeliveryTeam) {
      facilities.add(DropdownItem(
        code: deliveryTeamCode,
        name: localizations.translate('DELIVERY_TEAM'),
      ));
    }

    facilities.addAll(stockScopedFacilities.map((model) {
      final facilityId = model.facilityId;
      final isUuid = facilityId.contains('-') && !facilityId.startsWith('F-');
      return DropdownItem(
        code: facilityId,
        name: isUuid ? facilityId : localizations.translate('FAC_$facilityId'),
      );
    }).toList());

    return BaseReactiveFieldWrapper(
      formControlName: formKey,
      schema: fieldSchema,
      builder: (field) {
        var selectedValue = _getCurrentValue(field.control);

        if (isReturnFlow &&
            isFromField &&
            hasDeliveryTeamInConfig &&
            !isWareHouseMgr &&
            (selectedValue == null || selectedValue.isEmpty)) {
          selectedValue = deliveryTeamCode;
          final loggedInUserId = context.loggedInUserUuid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            field.control.value = deliveryTeamCode;
            field.control.markAsTouched();
            field.control.markAsDirty();
            context.read<FormsBloc>().add(
                  FormsEvent.updateField(
                    schemaKey: pageSchema,
                    context: context,
                    key: formKey,
                    value: deliveryTeamCode,
                  ),
                );
            context.read<FormsBloc>().add(
                  FormsEvent.updateField(
                    schemaKey: pageSchema,
                    context: context,
                    key: dependantFormKey,
                    value: loggedInUserId,
                  ),
                );
          });
        }

        if (isLessExcessFlow &&
            isFromField &&
            hasDeliveryTeamInConfig &&
            !isWareHouseMgr &&
            (selectedValue == null || selectedValue.isEmpty)) {
          selectedValue = deliveryTeamCode;
          final loggedInUserId = context.loggedInUserUuid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            field.control.value = deliveryTeamCode;
            field.control.markAsTouched();
            field.control.markAsDirty();
            context.read<FormsBloc>().add(
                  FormsEvent.updateField(
                    schemaKey: pageSchema,
                    context: context,
                    key: formKey,
                    value: deliveryTeamCode,
                  ),
                );
            context.read<FormsBloc>().add(
                  FormsEvent.updateField(
                    schemaKey: pageSchema,
                    context: context,
                    key: dependantFormKey,
                    value: loggedInUserId,
                  ),
                );
          });
        }

        if (isFromField &&
            (transactionType == 'DISPATCHED' ||
                transactionType == 'ISSUED' ||
                isLessExcessFlow) &&
            (selectedValue == null || selectedValue.isEmpty) &&
            facilities.isNotEmpty) {
          final currentFacility = facilities.first.code;
          selectedValue = currentFacility;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            field.control.value = currentFacility;
            field.control.markAsTouched();
            field.control.markAsDirty();
            context.read<FormsBloc>().add(
                  FormsEvent.updateField(
                    schemaKey: pageSchema,
                    context: context,
                    key: formKey,
                    value: currentFacility,
                  ),
                );
          });
        }

        final selectedOption =
            (selectedValue != null && selectedValue.isNotEmpty)
                ? DropdownItem(
                    code: selectedValue,
                    name: _getDisplayName(selectedValue, deliveryTeamCode),
                  )
                : null;

        final isReadOnlyFrom = isFromField;

        return LabeledField(
          label: labelFromSchema != null
              ? localizations.translate(labelFromSchema)
              : localizations.translate("SELECT_FACILITY"),
          capitalizedFirstLetter: false,
          isRequired: true,
          child: DigitDropdown(
            key: ValueKey('dropdown_${formKey}_$selectedValue'),
            errorMessage: field.errorText,
            emptyItemText: localizations.translate('NOT_FOUND'),
            items: facilities,
            selectedOption: selectedOption,
            readOnly: isReadOnlyFrom,
            onSelect: (value) {
              field.control.value = value.code;

              context.read<FormsBloc>().add(
                    FormsEvent.updateField(
                      schemaKey: pageSchema,
                      context: context,
                      key: formKey,
                      value: value.code,
                    ),
                  );
            },
          ),
        );
      },
    );
  }
}
