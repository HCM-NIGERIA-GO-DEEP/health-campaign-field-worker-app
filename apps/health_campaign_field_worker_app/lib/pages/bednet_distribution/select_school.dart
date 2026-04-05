import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';

@RoutePage()
class SelectSchoolPage extends StatelessWidget {
  const SelectSchoolPage({super.key});

  static const _schoolControl = 'school';

  @override
  Widget build(BuildContext context) {
    return BlocListener<BednetDistributionBloc, BednetDistributionState>(
      listenWhen: (previous, current) =>
          previous.schoolSelectionSeq != current.schoolSelectionSeq &&
          current.selectedSchool != null &&
          current.error == null,
      listener: (context, state) {
        if (!context.mounted) return;
        context.router.push(const SchoolDetailsRoute());
      },
      child: BlocBuilder<BednetDistributionBloc, BednetDistributionState>(
        builder: (context, state) {
          return ReactiveFormBuilder(
            form: () => fb.group({
              _schoolControl: FormControl<HouseholdModel>(
                validators: [Validators.required],
                value: null,
              )
            }),
            builder: (context, form, _) {
              final theme = Theme.of(context);
              final textTheme = theme.digitTextTheme(context);
              return Scaffold(
                body: ScrollableContent(
                  enableFixedDigitButton: true,
                  header: const BackNavigationHelpHeaderWidget(
                    showHelp: false,
                  ),
                  footer: StreamBuilder<Object?>(
                    stream: form.valueChanges,
                    initialData: form.value,
                    builder: (context, _) {
                      final selected =
                          form.control(_schoolControl).value as HouseholdModel?;
                      final hasSelection = selected != null;
                      return DigitCard(
                        margin: const EdgeInsets.only(top: spacer2),
                        children: [
                          DigitButton(
                            label: 'Next',
                            type: DigitButtonType.primary,
                            size: DigitButtonSize.large,
                            mainAxisSize: MainAxisSize.max,
                            isDisabled: state.schools.isEmpty || !hasSelection,
                            onPressed: () {
                              form.markAllAsTouched();
                              if (!form.valid) return;
                              final school = form.control(_schoolControl).value
                                  as HouseholdModel;
                              context.read<BednetDistributionBloc>().add(
                                    BednetDistributionEvent.selectSchool(
                                      school: school,
                                    ),
                                  );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: DigitCard(
                        margin: const EdgeInsets.all(spacer2),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Select the school',
                                  style: textTheme.headingXl.copyWith(
                                    color: theme.colorTheme.primary.primary2,
                                  ),
                                ),
                              ),
                              // DigitButton(
                              //   label: 'Refresh',
                              //   type: DigitButtonType.tertiary,
                              //   size: DigitButtonSize.medium,
                              //   onPressed: () {
                              //     if (state.loading) return;
                              //     context.read<BednetDistributionBloc>().add(
                              //           const BednetDistributionEvent.reload(),
                              //         );
                              //   },
                              // ),
                            ],
                          ),
                          const SizedBox(height: spacer2),
                          ReactiveWrapperField(
                            formControlName: _schoolControl,
                            validationMessages: {
                              'required': (_) =>
                                  'Please select a school to proceed',
                            },
                            builder: (field) => LabeledField(
                              label: 'Select the school',
                              isRequired: true,
                              child: DigitDropdown<HouseholdModel>(
                                isSearchable: false,
                                items: state.schools
                                    .map(
                                      (e) => DropdownItem(
                                        name: e.bednetDisplayName,
                                        code: e.bednetSchoolId,
                                      ),
                                    )
                                    .toList(),
                                selectedOption: (form
                                            .control(_schoolControl)
                                            .value as HouseholdModel?) !=
                                        null
                                    ? DropdownItem(
                                        name: (form
                                                .control(_schoolControl)
                                                .value as HouseholdModel)
                                            .bednetDisplayName,
                                        code: (form
                                                .control(_schoolControl)
                                                .value as HouseholdModel)
                                            .bednetSchoolId,
                                      )
                                    : null,
                                onSelect: (value) {
                                  final selected = state.schools.firstWhere(
                                    (school) =>
                                        school.bednetSchoolId == value.code,
                                  );
                                  form.control(_schoolControl).value = selected;
                                },
                                errorMessage: field.errorText,
                                emptyItemText: 'No schools available',
                              ),
                            ),
                          ),
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: spacer2),
                              child: Text(
                                state.error!,
                                style: textTheme.bodyS.copyWith(
                                  color: theme.colorTheme.alert.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
