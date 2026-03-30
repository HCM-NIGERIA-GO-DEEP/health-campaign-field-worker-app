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
import 'widgets/bednet_info_card.dart';

Map<String, dynamic>? _schoolNonNegativeInt(AbstractControl<dynamic> control) {
  final raw = control.value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final v = int.tryParse(raw);
  if (v == null) return {'invalidNumber': true};
  if (v < 0) return {'negative': true};
  return null;
}

@RoutePage()
class SchoolDetailsPage extends StatelessWidget {
  const SchoolDetailsPage({super.key});

  static const _totalPupils = 'totalPupils';
  static const _boysPresent = 'boysPresent';
  static const _girlsPresent = 'girlsPresent';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BednetDistributionBloc, BednetDistributionState>(
      builder: (context, state) {
        final school = state.selectedSchool;
        if (school == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final pendingCount = state.classIndividuals.length;
        final totalClasses = school.bednetNumberOfClasses;

        return ReactiveFormBuilder(
          form: () => fb.group({
            _totalPupils: FormControl<String>(
              value: school.bednetPupilCount.toString(),
              validators: [
                Validators.required,
                Validators.delegate(_schoolNonNegativeInt),
              ],
            ),
            _boysPresent: FormControl<String>(
              value: school.bednetNumberOfBoys.toString(),
              validators: [
                Validators.required,
                Validators.delegate(_schoolNonNegativeInt),
              ],
            ),
            _girlsPresent: FormControl<String>(
              value: school.bednetNumberOfGirls.toString(),
              validators: [
                Validators.required,
                Validators.delegate(_schoolNonNegativeInt),
              ],
            ),
          }),
          builder: (context, form, _) {
            final theme = Theme.of(context);
            final textTheme = theme.digitTextTheme(context);

            return Scaffold(
              body: ScrollableContent(
                enableFixedDigitButton: true,
                header: const BackNavigationHelpHeaderWidget(showHelp: false),
                footer: DigitCard(
                  margin: const EdgeInsets.only(top: spacer2),
                  children: [
                    DigitButton(
                      label: 'Next',
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large,
                      mainAxisSize: MainAxisSize.max,
                      isDisabled: !form.valid,
                      onPressed: () {
                        form.markAllAsTouched();
                        if (!form.valid) return;
                        context.router.push(
                          ClassTeacherInfoRoute(
                            classIndex: 0,
                            totalClasses: totalClasses,
                          ),
                        );
                      },
                    )
                  ],
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BednetInfoCard(
                          title: 'School Details',
                          items: [
                            MapEntry(
                              'Classes to administer (pending)',
                              pendingCount > 0
                                  ? pendingCount.toString()
                                  : '—',
                            ),
                            MapEntry('School Name', school.bednetDisplayName),
                            MapEntry('School Head', school.bednetSchoolHead),
                            MapEntry(
                              'Number of Classes',
                              totalClasses.toString(),
                            ),
                          ],
                        ),
                        DigitCard(
                          margin: const EdgeInsets.all(spacer2),
                          children: [
                            Text(
                              'School roll',
                              style: textTheme.headingM.copyWith(
                                color: theme.colorTheme.primary.primary2,
                              ),
                            ),
                            const SizedBox(height: spacer2),
                            ReactiveWrapperField(
                              formControlName: _totalPupils,
                              validationMessages: {
                                'required': (_) =>
                                    'Total pupils is required',
                                'invalidNumber': (_) =>
                                    'Enter a valid whole number',
                                'negative': (_) =>
                                    'Value cannot be negative',
                              },
                              builder: (field) => LabeledField(
                                label: 'Total pupils',
                                isRequired: true,
                                child: DigitTextFormInput(
                                  initialValue:
                                      form.control(_totalPupils).value,
                                  keyboardType: TextInputType.number,
                                  errorMessage: field.errorText,
                                  onChange: (value) {
                                    form.control(_totalPupils).value = value;
                                  },
                                ),
                              ),
                            ),
                            ReactiveWrapperField(
                              formControlName: _boysPresent,
                              validationMessages: {
                                'required': (_) =>
                                    'Boys present is required',
                                'invalidNumber': (_) =>
                                    'Enter a valid whole number',
                                'negative': (_) =>
                                    'Value cannot be negative',
                              },
                              builder: (field) => LabeledField(
                                label: 'Boys present',
                                isRequired: true,
                                child: DigitTextFormInput(
                                  initialValue:
                                      form.control(_boysPresent).value,
                                  keyboardType: TextInputType.number,
                                  errorMessage: field.errorText,
                                  onChange: (value) {
                                    form.control(_boysPresent).value = value;
                                  },
                                ),
                              ),
                            ),
                            ReactiveWrapperField(
                              formControlName: _girlsPresent,
                              validationMessages: {
                                'required': (_) =>
                                    'Girls present is required',
                                'invalidNumber': (_) =>
                                    'Enter a valid whole number',
                                'negative': (_) =>
                                    'Value cannot be negative',
                              },
                              builder: (field) => LabeledField(
                                label: 'Girls present',
                                isRequired: true,
                                child: DigitTextFormInput(
                                  initialValue:
                                      form.control(_girlsPresent).value,
                                  keyboardType: TextInputType.number,
                                  errorMessage: field.errorText,
                                  onChange: (value) {
                                    form.control(_girlsPresent).value = value;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
