import 'package:digit_data_model/blocs/facility/facility.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/project_facility.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_forms_engine/widgets/base_reactive_field_wrapper.dart';
import 'package:digit_scanner/blocs/scanner.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../blocs/project/project.dart';
import '../../models/entities/roles_type.dart';
import '../../utils/constants.dart';
import '../../utils/extensions/extensions.dart';
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

  List<ProjectFacilityModel> _filterProjectFacilitiesUsingFacilityUsage({
    required List<ProjectFacilityModel> projectFacilities,
    required String? usage,
    String? additionalUsage,
    required bool isToField,
    required bool isFromField,
  }) {
    if (usage == null || usage.trim().isEmpty) return projectFacilities;

    // Align source scope with StockBalanceCard:
    // use only project facilities marked as current level.
    final currentLevelProjectFacilities = projectFacilities.where((pf) {
      final facilityLevel = pf.additionalFields?.fields
          .where((f) => f.key == 'facilityLevel')
          .firstOrNull
          ?.value;
      return facilityLevel == null || facilityLevel == 'current';
    }).toList();

    final currentLevelFacilityIds =
        currentLevelProjectFacilities.map((pf) => pf.facilityId).toSet();

    if (currentLevelFacilityIds.isEmpty) {
      return currentLevelProjectFacilities;
    }

    // If facilities have not been loaded from DB yet, trigger a load
    // and temporarily fall back to unfiltered current-level facilities.
    if (_facilitiesForProject.isEmpty && !_isLoadingFacilitiesFromDb) {
      // Fire-and-forget DB load; result cached in _facilitiesForProject.
      _loadFacilitiesForCurrentProject(currentLevelProjectFacilities);
      return currentLevelProjectFacilities;
    }

    if (_facilitiesForProject.isEmpty) {
      return currentLevelProjectFacilities;
    }

    final primaryUsage = usage.trim();
    final secondaryUsage = additionalUsage?.trim();

    final allowedFacilityIds = _facilitiesForProject
        .where((f) {
          final currentUsage = (f.usage ?? '').trim();
          final matchesPrimary = currentUsage == primaryUsage;
          final matchesSecondary =
              secondaryUsage != null && secondaryUsage.isNotEmpty
                  ? currentUsage == secondaryUsage
                  : false;
          return matchesPrimary || matchesSecondary;
        })
        .map((f) => f.id)
        .toSet();

    return currentLevelProjectFacilities
        .where((pf) => allowedFacilityIds.contains(pf.facilityId))
        .toList();
  }

  /// Extract the delivery team code from the facilityHierarchy validation in config.
  String? _getDeliveryTeamCodeFromConfig(String transactionType) {
    final hierarchyValidation = fieldSchema.validations?.firstWhere(
      (v) => v.type == 'facilityHierarchy',
      orElse: () => const ValidationRule(type: ''),
    );

    if (hierarchyValidation == null || hierarchyValidation.type.isEmpty) {
      return null;
    }

    final value = hierarchyValidation.value;
    if (value is! Map) return null;

    final hierarchyMapping = value['hierarchyMapping'];
    if (hierarchyMapping is! Map) return null;

    final isReceipt = transactionType == 'RECEIVED' ||
        transactionType == 'RECEIPT' ||
        transactionType == 'RETURNED';
    final directionKey = isReceipt ? 'forReceipt' : 'forIssue';

    for (final entry in hierarchyMapping.entries) {
      final directions = entry.value;
      if (directions is Map && directions.containsKey(directionKey)) {
        final targets = directions[directionKey];
        if (targets is List) {
          for (final target in targets) {
            if (target is String && target.startsWith('DELIVERY')) {
              return target;
            }
          }
        }
      }
    }

    return null;
  }

  /// Read current selected value from form data or form control
  String? _getCurrentValue(AbstractControl<dynamic>? control) {
    // First try form control (most up-to-date after user interaction)
    final controlValue = control?.value?.toString();
    if (controlValue != null && controlValue.isNotEmpty) {
      return controlValue;
    }

    // Fallback to stateData.formData (for prefilled values)
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

  @override
  Widget build(BuildContext context) {
    final navigationParams =
        FlowCrudStateRegistry().getNavigationParams('FORM::$pageSchema') ??
            FlowCrudStateRegistry().getNavigationParams(pageSchema) ??
            {};
    final transactionType =
        navigationParams['transactionType']?.toString() ?? '';
    final stockEntryType = navigationParams['stockEntryType']?.toString() ?? '';
    final isReturnFlow = stockEntryType == 'RETURNED' ||
        stockEntryType == 'LOSS' ||
        stockEntryType == 'DAMAGED';
    final isLessExcessFlow = stockEntryType == 'LESS_EXCESS';

    final deliveryTeamCode = _getDeliveryTeamCodeFromConfig(transactionType);
    final hasDeliveryTeamInConfig = deliveryTeamCode != null;

    final isWareHouseMgr = context.loggedInUserRoles
        .any((role) => role.code == RolesType.warehouseManager.toValue());

    final isDistributor = context.loggedInUserRoles
        .where(
          (role) => role.code == RolesType.distributor.toValue(),
        )
        .toList()
        .isNotEmpty;

    final isCommunityDistributor = context.loggedInUserRoles
        .any((role) => role.code == RolesType.communityDistributor.toValue());

    final isHFS = context.loggedInUserRoles.any(
        (role) => role.code == RolesType.healthFacilitySupervisor.toValue());

    // Get wrapper data for project facilities
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

    // Filter facilities
    // final filteredFacilities = projectFacilities.where((e) {
    //   final model = e as ProjectFacilityModel;
    //   final facilityLevel = model.additionalFields?.fields
    //       .where((f) => f.key == 'facilityLevel')
    //       .firstOrNull
    //       ?.value;

    //   if (facilityLevel == null) return true;

    //   if (isLessExcessFlow) {
    //     if (isToField) return facilityLevel == 'parent';
    //     if (isFromField) return facilityLevel == 'current';
    //   } else if (isReturnFlow) {
    //     if (isToField) return facilityLevel == 'parent';
    //     if (isFromField) return facilityLevel == 'current';
    //   } else if (transactionType == 'DISPATCHED' ||
    //       transactionType == 'ISSUED') {
    //     if (isToField) return facilityLevel == 'child';
    //     if (isFromField) return facilityLevel == 'current';
    //   } else if (transactionType == 'RECEIVED' ||
    //       transactionType == 'RECEIPT') {
    //     if (isToField) return facilityLevel == 'current';
    //     if (isFromField) return facilityLevel == 'parent';
    //   }  else if (stockEntryType == 'LOSS' || stockEntryType == 'DAMAGED') {
    // For loss and damaged, to field should show parent facility
    //   if (isToField) return facilityLevel == 'parent';
    //   if (isFromField) return facilityLevel == 'current';
    // }

    //   return true;
    // }).toList();

    //     // todo my changes unblock after test
    final typedProjectFacilities =
        projectFacilities.cast<ProjectFacilityModel>().toList();

    String? usage = "";
    bool? showTeamOption = false;

    final boundaryLevel = context.selectedProject.address?.boundaryType;
    //      ==
    // Constants.lgaBoundaryLevel

    if (stockEntryType == 'ISSUED') {
      if (isWareHouseMgr) {
        if (boundaryLevel == Constants.stateBoundaryLevel) {
          if (isFromField) {
            usage = Constants.stateFacility;
          } else {
            usage = Constants.districtFacility;
          }
        } else {
          if (boundaryLevel == Constants.lgaBoundaryLevel) {
            if (isFromField) {
              usage = Constants.districtFacility;
            } else {
              usage = Constants.dhFacility;
            }
          } else {
            if (isFromField) {
              if (isHFS) {
                usage = Constants.healthFacility;
              } else {
                usage = Constants.dhFacility;
              }
            } else {
              usage = "None";
            }
          }
        }
      } else if (isDistributor || isCommunityDistributor) {
        usage = "None";
      } else {
        if (isToField) {
          showTeamOption = true;
          usage = "None";
        } else {
          usage = Constants.healthFacility;
        }
      }
    } else {
      if (isWareHouseMgr) {
        if (boundaryLevel == Constants.stateBoundaryLevel) {
          if (isFromField) {
            usage = Constants.stateFacility;
          } else {
            usage = Constants.centralFacility;
          }
        } else {
          if (boundaryLevel == Constants.lgaBoundaryLevel) {
            if (isFromField) {
              usage = Constants.districtFacility;
            } else {
              usage = Constants.stateFacility;
            }
          } else {
            if (isFromField) {
              if (isHFS) {
                usage = Constants.healthFacility;
              } else {
                usage = Constants.dhFacility;
              }
            } else {
              usage = Constants.districtFacility;
            }
          }
        }
      } else if (isDistributor) {
        if (isToField) {
          usage = Constants.dhFacility;
        } else {
          usage = "None";
        }
      } else if (isCommunityDistributor) {
        if (isToField) {
          usage = Constants.healthFacility;
        } else {
          usage = "None";
        }
      } else {
        if (isFromField) {
          if (isHFS) {
            usage = Constants.healthFacility;
          } else {
            usage = Constants.dhFacility;
          }
        } else {
          usage = Constants.districtFacility;
        }
      }
    }

    final additionalUsage =
        usage == Constants.dhFacility ? Constants.healthFacility : null;

    final filteredFacilities = _filterProjectFacilitiesUsingFacilityUsage(
      projectFacilities: typedProjectFacilities,
      usage: usage,
      additionalUsage: additionalUsage,
      isToField: isToField,
      isFromField: isFromField,
    );

    // Check if there are child facilities (for warehouse managers at lowest level)
    final hasNoChildFacilities = isToField &&
        (transactionType == 'DISPATCHED' || transactionType == 'ISSUED') &&
        filteredFacilities.isEmpty;

    // Build facility dropdown items
    var facilities = <DropdownItem>[];

    final showDeliveryTeam = hasDeliveryTeamInConfig &&
        ((isToField &&
                !isReturnFlow &&
                (transactionType == 'DISPATCHED' ||
                    transactionType == 'ISSUED') &&
                (!isWareHouseMgr || hasNoChildFacilities)) ||
            (isFromField && isReturnFlow && !isWareHouseMgr));
    if (showDeliveryTeam) {
      facilities.add(DropdownItem(
        code: deliveryTeamCode!,
        name: localizations.translate('DELIVERY_TEAM'),
      ));
    }

    if ((isDistributor || isCommunityDistributor) && isFromField) {
      facilities.add(DropdownItem(
        code: context.loggedInUserUuid,
        name: localizations.translate('DELIVERY_TEAM'),
      ));
    }

    facilities.addAll(filteredFacilities.map((e) {
      final model = e as ProjectFacilityModel;
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
        // Read selected value from the form control (source of truth)
        var selectedValue = _getCurrentValue(field.control);

        // For return flow, auto-prefill delivery team if no value yet (distributors only)
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
            // Auto-fill team code with logged-in user ID
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

        // For ISSUED/DISPATCHED/LESS_EXCESS, auto-prefill the from field with current facility
        if (isFromField &&
            (transactionType == 'DISPATCHED' ||
                transactionType == 'ISSUED' ||
                isLessExcessFlow) &&
            (selectedValue == null ||
                selectedValue.isEmpty ||
                selectedValue != null) &&
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

        // From field is always read-only
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

// class __FacilityCardContentState extends State<_FacilityCardContent> {
//   bool deliveryTeamSelected = false;
//   String? selectedFacilityId;
//   TextEditingController teamCodeController = TextEditingController();
//   bool _initialized = false;
//   bool _formControlUpdated = false;
//   bool _requestedFacilitiesLoad = false;

//   void _maybeLoadFacilitiesForSelectedProject() {
//     if (_requestedFacilitiesLoad) return;

//     FacilityBloc? facilityBloc;
//     try {
//       facilityBloc = context.read<FacilityBloc>();
//     } catch (_) {
//       facilityBloc = null;
//     }
//     if (facilityBloc == null) return;

//     String? projectId;
//     try {
//       projectId = context.read<ProjectBloc>().state.selectedProject?.id;
//     } catch (_) {
//       projectId = null;
//     }
//     if (projectId == null || projectId.isEmpty) return;

//     _requestedFacilitiesLoad = true;
//     facilityBloc.add(
//       FacilityEvent.loadForProjectId(
//         projectId: projectId,
//         loadAllProjects: false,
//       ),
//     );
//   }

/* List<ProjectFacilityModel> _filterProjectFacilitiesUsingFacilityUsage({
  required List<ProjectFacilityModel> projectFacilities,
  required String? usage,
  required bool isToField,
  required bool isFromField,
}) {
  // We filter *facilities* by usage, then return matching *project facilities*.
  // If FacilityBloc isn't available / not fetched, keep original behavior.
  if (usage == null || usage.trim().isEmpty) return projectFacilities;

  List<FacilityModel> facilitiesForProject = const [];
  try {
    // Watch so this widget rebuilds when facilities are fetched
    final state = context.watch<FacilityBloc>().state;
    if (state is FacilityFetchedState) {
      facilitiesForProject = state.facilities;
    }
  } catch (_) {
    // FacilityBloc not in tree
    return projectFacilities;
  }

  if (facilitiesForProject.isEmpty) {
    _maybeLoadFacilitiesForSelectedProject();
    return projectFacilities;
  }

  final allowedFacilityIds = facilitiesForProject
      .where((f) => (f.usage ?? '').trim() == usage.trim())
      .map((f) => f.id)
      .toSet();

  // Return the matching ProjectFacilityModels
  return projectFacilities
      .where((pf) => allowedFacilityIds.contains(pf.facilityId))
      .toList();
} */

//   @override
//   void initState() {
//     super.initState();
//     // Clear QR codes on init
//     context.read<DigitScannerBloc>().add(const DigitScannerEvent.handleScanner(
//           barCode: [],
//           qrCode: [],
//         ));

//     // Initialize from prefilled formData if available
//     _initializeFromFormData();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       _maybeLoadFacilitiesForSelectedProject();
//     });
//   }

//   void _initializeFromFormData() {
//     if (_initialized) return;

//     // Get prefilled value from stateData.formData
//     final formData = widget.stateData?.formData as Map<String, dynamic>?;
//     debugPrint('FacilityCard: formData for ${widget.formKey} = $formData');

//     if (formData != null) {
//       // Try to get facility value - check both nested and flat structure
//       final facilityValue = formData['warehouseDetails.${widget.formKey}'] ??
//           formData[widget.formKey] ??
//           (formData['warehouseDetails']
//               as Map<String, dynamic>?)?[widget.formKey] ??
//           (formData['stockDetails'] as Map<String, dynamic>?)?[widget.formKey];

//       debugPrint(
//           'FacilityCard: Looking for ${widget.formKey}, found: $facilityValue');

//       if (facilityValue != null && facilityValue.toString().isNotEmpty) {
//         selectedFacilityId = facilityValue.toString();
//         deliveryTeamSelected = selectedFacilityId == 'Delivery Team';
//         _initialized = true;
//         _formControlUpdated =
//             false; // Need to update form control when available
//         debugPrint(
//             'FacilityCard: Initialized ${widget.formKey} with prefilled value: $selectedFacilityId');
//       }
//     }
//   }

//   /// Updates the form control with the prefilled value
//   /// This must be called after the form is built and the control is accessible
//   void _updateFormControlIfNeeded(
//       ReactiveFormFieldState<dynamic, dynamic> field) {
//     if (_initialized && !_formControlUpdated && selectedFacilityId != null) {
//       // Schedule the update for after the current build
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (!mounted) return;

//         // Update the form control value
//         field.control.value = selectedFacilityId;

//         // Also update FormsBloc to sync state
//         context.read<FormsBloc>().add(
//               FormsEvent.updateField(
//                 schemaKey: widget.pageSchema,
//                 context: context,
//                 key: widget.formKey,
//                 value: selectedFacilityId,
//               ),
//             );

//         debugPrint(
//             'FacilityCard: Updated form control ${widget.formKey} with value: $selectedFacilityId');
//       });
//       _formControlUpdated = true;
//     }
//   }

//   @override
//   void didUpdateWidget(covariant _FacilityCardContent oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     // Re-initialize if stateData changed and we haven't initialized yet
//     if (!_initialized && widget.stateData != oldWidget.stateData) {
//       _initializeFromFormData();
//     }
//   }

//   @override
//   void dispose() {
//     teamCodeController.dispose();
//     super.dispose();
//   String _getDisplayName(String facilityId, String? deliveryTeamCode) {
//     if (facilityId == deliveryTeamCode) {
//       return localizations.translate('DELIVERY_TEAM');
//     }
//     final isUuid = facilityId.contains('-') && !facilityId.startsWith('F-');
//     return isUuid ? facilityId : localizations.translate('FAC_$facilityId');
//   }

//   @override
//   Widget build(BuildContext context) {
//     final navigationParams = FlowCrudStateRegistry()
//             .getNavigationParams('FORM::$pageSchema') ??
//         FlowCrudStateRegistry().getNavigationParams(pageSchema) ??
//         {};
//     final transactionType =
//         navigationParams['transactionType']?.toString() ?? '';
//     final stockEntryType =
//         navigationParams['stockEntryType']?.toString() ?? '';
//     final isReturnFlow = stockEntryType == 'RETURNED';

//     final deliveryTeamCode = _getDeliveryTeamCodeFromConfig(transactionType);
//     final hasDeliveryTeamInConfig = deliveryTeamCode != null;

//     // Get wrapper data for project facilities
//     var wrapperData = stateData?.stateWrapper;
//     if (wrapperData == null) {
//       final formState = FlowCrudStateRegistry().get('FORM::$pageSchema') ??
//           FlowCrudStateRegistry().get(pageSchema);
//       wrapperData = formState?.stateWrapper;
//     }

//     List<dynamic>? projectFacilities;
//     if (wrapperData != null && wrapperData is List && wrapperData.isNotEmpty) {
//       final firstItem = wrapperData.first;
//       if (firstItem is Map) {
//         final wrapperList = wrapperData as List<Map<String, List<dynamic>>>;
//         projectFacilities = wrapperList.firstWhere(
//             (m) => m.containsKey('ProjectFacilityModel'),
//             orElse: () => {'ProjectFacilityModel': []})['ProjectFacilityModel'];
//       } else if (firstItem is ProjectFacilityModel) {
//         projectFacilities = wrapperData;
//       } else {
//         projectFacilities =
//             wrapperData.whereType<ProjectFacilityModel>().toList();
//       }
//     }
//     projectFacilities ??= [];

//     final labelFromSchema = fieldSchema.label ?? fieldSchema.innerLabel;


//     // // Get transaction type from navigation params for hierarchy filtering
//     // // Try current form's navigation params
//     // final navigationParams = FlowCrudStateRegistry()
//     //     .getNavigationParams('FORM::${widget.pageSchema}') ??
//     //     FlowCrudStateRegistry().getNavigationParams(widget.pageSchema) ??
//     //     {};
//     // final transactionType =
//     //     navigationParams['transactionType']?.toString() ?? '';
//     // final stockEntryType = navigationParams['stockEntryType']?.toString() ?? '';
//     // final isReturnFlow = stockEntryType == 'RETURNED';
//     //

//     debugPrint(
//         'FacilityCard: Transaction type: $transactionType, stockEntryType: $stockEntryType');

//     final isToField = formKey == 'facilityToWhich';
//     final isFromField = formKey == 'facilityFromWhich';

//     // // Filter facilities by facilityLevel based on transaction type and field
//     // // facilityToWhich = destination, facilityFromWhich = source
//     // final isToField = widget.formKey == 'facilityToWhich';
//     // final isFromField = widget.formKey == 'facilityFromWhich';

//     // For return flow, prefill facilityFromWhich with logged-in user UUID
//     // only for distributors (least level) who don't have a facility assigned
//     // final isLeastLevel = showDeliveryTeamOption;
//     // if (isReturnFlow && isFromField && isLeastLevel && !_initialized) {
//     //   final userUuid = context.loggedInUserUuid;
//     //   selectedFacilityId = userUuid;
//     //   _initialized = true;
//     //   _formControlUpdated = false;
//     // }

//     // final filteredFacilities = projectFacilities.where((e) {
//     //   final model = e as ProjectFacilityModel;
//     //   final facilityLevel = model.additionalFields?.fields
//     //       .where((f) => f.key == 'facilityLevel')
//     //       .firstOrNull
//     //       ?.value;


//     // Filter facilities
//     final filteredFacilities = projectFacilities.where((e) {
//       final model = e as ProjectFacilityModel;
//       final facilityLevel = model.additionalFields?.fields
//           .where((f) => f.key == 'facilityLevel')
//           .firstOrNull
//           ?.value;

//       if (facilityLevel == null) return true;

//       if (isReturnFlow) {
//         if (isToField) return facilityLevel == 'parent';
//         if (isFromField) return facilityLevel == 'current';
//       } else if (transactionType == 'DISPATCHED' ||
//           transactionType == 'ISSUED') {
//         if (isToField) return facilityLevel == 'child';
//         if (isFromField) return facilityLevel == 'current';
//       } else if (transactionType == 'RECEIVED' ||
//           transactionType == 'RECEIPT') {
//         if (isToField) return facilityLevel == 'current';
//         if (isFromField) return facilityLevel == 'parent';
//       }
//       return true;
//     }).toList();

//     // todo my changes unblock after test
//     final typedProjectFacilities =
//     projectFacilities.cast<ProjectFacilityModel>().toList();


//     // You can populate this later (from navigation params / schema / etc.)
//     String? usage = "";


//     // final filteredFacilities = projectFacilities.where((e) {
//     //   final model = e as ProjectFacilityModel;
//     //   final facilityLevel = model.additionalFields?.fields
//     //       .where((f) => f.key == 'facilityLevel')
//     //       .firstOrNull
//     //       ?.value;

//     //   // If no facilityLevel (e.g. from ProjectFacilities list), always include
//     //   if (facilityLevel == null) return true;

//     //   if (isReturnFlow) {
//     //     if (isToField) return facilityLevel == 'parent';
//     //     if (isFromField) return facilityLevel == 'current';
//     //   } else if (transactionType == 'DISPATCHED' ||
//     //       transactionType == 'ISSUED') {
//     //     if (isToField) return facilityLevel == 'child';
//     //     if (isFromField) return facilityLevel == 'current';
//     //   } else if (transactionType == 'RECEIVED' ||
//     //       transactionType == 'RECEIPT') {
//     //     if (isToField) return facilityLevel == 'current';
//     //     if (isFromField) return facilityLevel == 'parent';
//     //   }

//     //   return true;
//     // }).toList();

//     // Build facility dropdown items
//     var facilities = <DropdownItem>[];

//     final showDeliveryTeam = hasDeliveryTeamInConfig &&
//         ((isToField &&
//                 !isReturnFlow &&
//                 (transactionType == 'DISPATCHED' ||
//                     transactionType == 'ISSUED')) ||
//             (isFromField && isReturnFlow));
//     if (showDeliveryTeam) {
//       facilities.add(DropdownItem(
//         code: deliveryTeamCode!,
//         name: localizations.translate('DELIVERY_TEAM'),
//       ));
//     }

//     // todo uncomment after check
//     if (showTeamOption) {
//       facilities.add(const DropdownItem(
//         code: 'Delivery Team',
//         name: 'Delivery Team',
//       ));
//     }

//     facilities.addAll(filteredFacilities.map((e) {
//       final model = e as ProjectFacilityModel;
//       final facilityId = model.facilityId;
//       final isUuid = facilityId.contains('-') && !facilityId.startsWith('F-');
//       return DropdownItem(
//         code: facilityId,
//         name: isUuid
//             ? facilityId
//             : localizations.translate('FAC_$facilityId'),
//       );
//     }).toList());

//     return BaseReactiveFieldWrapper(
//       formControlName: formKey,
//       schema: fieldSchema,
//       builder: (field) {
//         // Read selected value from the form control (source of truth)
//         var selectedValue = _getCurrentValue(field.control);

//         // For return flow, auto-prefill delivery team if no value yet
//         if (isReturnFlow &&
//             isFromField &&
//             hasDeliveryTeamInConfig &&
//             (selectedValue == null || selectedValue.isEmpty)) {
//           selectedValue = deliveryTeamCode;
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             field.control.value = deliveryTeamCode;
//             context.read<FormsBloc>().add(
//                   FormsEvent.updateField(
//                     schemaKey: pageSchema,
//                     context: context,
//                     key: formKey,
//                     value: deliveryTeamCode,
//                   ),
//                 );
//           });
//         }

//         // For ISSUED/DISPATCHED, auto-prefill the from field with current facility
//         if (isFromField &&
//             (transactionType == 'DISPATCHED' ||
//                 transactionType == 'ISSUED') &&
//             (selectedValue == null || selectedValue.isEmpty) &&
//             facilities.isNotEmpty) {
//           final currentFacility = facilities.first.code;
//           selectedValue = currentFacility;
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             field.control.value = currentFacility;
//             context.read<FormsBloc>().add(
//                   FormsEvent.updateField(
//                     schemaKey: pageSchema,
//                     context: context,
//                     key: formKey,
//                     value: currentFacility,
//                   ),
//                 );
//           });
//         }

//         final selectedOption = (selectedValue != null && selectedValue.isNotEmpty)
//             ? DropdownItem(
//                 code: selectedValue,
//                 name: _getDisplayName(selectedValue, deliveryTeamCode),
//               )
//             : null;

//         // Make from field read-only for ISSUED/DISPATCHED
//         final isReadOnlyFrom = isFromField &&
//             (transactionType == 'DISPATCHED' ||
//                 transactionType == 'ISSUED');

//         return LabeledField(
//           label: labelFromSchema != null
//               ? localizations.translate(labelFromSchema)
//               : localizations.translate("SELECT_FACILITY"),
//           capitalizedFirstLetter: false,
//           isRequired: true,
//           child: DigitDropdown(
//             key: ValueKey('dropdown_${formKey}_$selectedValue'),
//             errorMessage: field.errorText,
//             emptyItemText: localizations.translate('NOT_FOUND'),
//             items: facilities,
//             selectedOption: selectedOption,
//             readOnly: isReadOnlyFrom,
//             onSelect: (value) {
//               field.control.value = value.code;

//               context.read<FormsBloc>().add(
//                     FormsEvent.updateField(
//                       schemaKey: pageSchema,
//                       context: context,
//                       key: formKey,
//                       value: value.code,
//                     ),
//                   );
//             },
//           ),
//         );
//       },
//     );
//   }
// }
