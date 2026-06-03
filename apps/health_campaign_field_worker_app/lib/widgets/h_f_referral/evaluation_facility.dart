import 'package:collection/collection.dart';
import 'package:digit_data_model/blocs/facility/facility.dart';
import 'package:digit_data_model/blocs/project_facility/project_facility.dart';
import 'package:digit_data_model/models/entities/facility.dart';
import 'package:digit_data_model/models/entities/project_facility.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:digit_forms_engine/helper/validation_message_helper.dart';
import 'package:digit_forms_engine/models/property_schema/property_schema.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/atoms/dropdown_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../models/entities/roles_type.dart';
import '../../utils/utils.dart';
import '../localized.dart';

class EvaluationKeyDropDown extends LocalizedStatefulWidget {
  final String schemaName;
  final String formControlName;
  const EvaluationKeyDropDown({
    super.key,
    super.appLocalizations,
    required this.schemaName,
    required this.formControlName,
  });

  @override
  _EvaluationKeyDropDownState createState() => _EvaluationKeyDropDownState();
}

class _EvaluationKeyDropDownState
    extends LocalizedState<EvaluationKeyDropDown> {
  @override
  void initState() {
    super.initState();

    final projectId = context.selectedProject.id;
    context.read<FacilityBloc>().add(
          FacilityEvent.loadForProjectId(
            projectId: projectId,
            loadAllProjects: false,
          ),
        );
    context.read<ProjectFacilityBloc>().add(
          ProjectFacilityEvent.load(
            query: ProjectFacilitySearchModel(projectId: [projectId]),
          ),
        );
  }

  /// Maps health facilities to their project-facility rows for this project.
  /// Dropdown [code] is [ProjectFacilityModel.id]; label uses [ProjectFacilityModel.facilityId].
  List<ProjectFacilityModel> _healthProjectFacilities({
    required List<FacilityModel> facilities,
    required List<ProjectFacilityModel> projectFacilities,
    required String facilityUsage,
  }) {
    final healthFacilityIds = facilities
        .where((f) => f.usage == facilityUsage)
        .map((f) => f.id)
        .toSet();

    return projectFacilities.where((pf) {
      if (!healthFacilityIds.contains(pf.facilityId)) return false;

      final facilityLevel = pf.additionalFields?.fields
          .where((f) => f.key == 'facilityLevel')
          .firstOrNull
          ?.value;
      return facilityLevel == null ||
          facilityLevel == 'current' ||
          facilityLevel == 'parent';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FacilityBloc, FacilityState>(
      builder: (context, facilityState) {
        return BlocBuilder<ProjectFacilityBloc, ProjectFacilityState>(
          builder: (context, projectFacilityState) {
            final facilities = facilityState.maybeWhen(
              fetched: (facilities, _) => facilities,
              orElse: () => const <FacilityModel>[],
            );
            final projectFacilities = projectFacilityState.maybeWhen(
              fetched: (list) => list,
              orElse: () => const <ProjectFacilityModel>[],
            );

            final isReady = facilityState is FacilityFetchedState &&
                projectFacilityState is ProjectFacilityFetchedState;

            final isDistributor = context.loggedInUserRoles.any(
              (role) =>
                  role.code == RolesType.distributor.toValue() ||
                  role.code == RolesType.communityDistributor.toValue(),
            );
            final facilityUsage = isDistributor
                ? Constants.dhFacility
                : Constants.healthFacility;

            return _buildDropdown(
              context,
              isReady
                  ? _healthProjectFacilities(
                      facilities: facilities,
                      projectFacilities: projectFacilities,
                      facilityUsage: facilityUsage,
                    )
                  : const [],
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown(
    BuildContext context,
    List<ProjectFacilityModel> projectFacilities,
  ) {
    bool isReadOnlyFromSchema = false;
    String? labelFromSchema;
    bool isRequiredFromSchema = false;
    dynamic validationMessages;

    final pages = context
            .read<FormsBloc>()
            .state
            .cachedSchemas[widget.schemaName]
            ?.pages ??
        context.read<FormsBloc>().state.cachedSchemas["REFERRAL_CREATE"]?.pages;

    void walk(Map<String, PropertySchema> node, List<String> pathSoFar) {
      for (final entry in node.entries) {
        final key = entry.key;
        final schema = entry.value;

        if (key == widget.formControlName) {
          isReadOnlyFromSchema =
              (schema.readOnly == true) || (schema.displayOnly == true);
          labelFromSchema = schema.label ?? schema.innerLabel;
          if (schema.validations != null) {
            validationMessages =
                buildValidationMessages(schema.validations, localizations);
            for (final validation in schema.validations!) {
              if (validation.type == "required" && validation.value == true) {
                isRequiredFromSchema = true;
                break;
              }
            }
          }
          return;
        }

        if (schema.properties != null && schema.properties!.isNotEmpty) {
          walk(schema.properties!, [...pathSoFar, key]);
          if (labelFromSchema != null || isReadOnlyFromSchema) return;
        }
      }
    }

    if (pages != null) {
      walk(pages, []);
    }

    return ReactiveWrapperField<dynamic>(
      formControlName: widget.formControlName,
      validationMessages: validationMessages,
      showErrors: (control) => control.invalid && control.touched,
      builder: (field) {
        final form = ReactiveForm.of(context) as FormGroup;

        return LabeledField(
          isRequired: isRequiredFromSchema,
          label: localizations.translate(labelFromSchema ?? ""),
          child: Dropdown(
            readOnly: isReadOnlyFromSchema,
            selectedOption: _mapItems(projectFacilities).firstWhere(
              (item) => item.code == form.control(widget.formControlName).value,
              orElse: () => const DropdownItem(name: '', code: ''),
            ),
            errorMessage: field.errorText,
            items: _mapItems(projectFacilities),
            onSelect: (val) {
              form.control(widget.formControlName).markAsTouched();
              form.control(widget.formControlName).value = val.code;

              context.read<FormsBloc>().add(
                    FormsEvent.updateField(
                      context: context,
                      schemaKey: widget.schemaName,
                      key: widget.formControlName,
                      value: val.code,
                    ),
                  );
            },
          ),
        );
      },
    );
  }

  List<DropdownItem> _mapItems(List<ProjectFacilityModel> projectFacilities) {
    return projectFacilities
        .map(
          (pf) => DropdownItem(
            name: localizations.translate('FAC_${pf.facilityId}'),
            code: pf.id,
          ),
        )
        .toList();
  }
}
