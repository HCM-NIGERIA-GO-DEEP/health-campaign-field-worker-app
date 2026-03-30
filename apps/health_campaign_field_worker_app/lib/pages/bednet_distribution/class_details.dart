import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';
import 'widgets/bednet_info_card.dart';

Map<String, dynamic>? _bednetMaxIntFormValidator(
  int max,
  AbstractControl<dynamic> control,
) {
  final raw = control.value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final v = int.tryParse(raw);
  if (v == null) return {'invalidNumber': true};
  if (v < 0) return {'negative': true};
  if (v > max) return {'maxExceeded': true};
  return null;
}

Map<String, dynamic>? _presentCompositionValidator(
  AbstractControl<dynamic> control,
) {
  if (control is! FormGroup) return null;

  final presentRaw = control.control(ClassDetailsPage._present).value
      ?.toString()
      .trim();
  final boysRaw = control.control(ClassDetailsPage._boysPresent).value
      ?.toString()
      .trim();
  final girlsRaw = control.control(ClassDetailsPage._girlsPresent).value
      ?.toString()
      .trim();

  if (presentRaw == null ||
      boysRaw == null ||
      girlsRaw == null ||
      presentRaw.isEmpty ||
      boysRaw.isEmpty ||
      girlsRaw.isEmpty) {
    return null;
  }

  final present = int.tryParse(presentRaw);
  final boys = int.tryParse(boysRaw);
  final girls = int.tryParse(girlsRaw);
  if (present == null || boys == null || girls == null) return null;

  if (boys + girls != present) {
    return {'presentMismatch': true};
  }

  return null;
}

@RoutePage()
class ClassDetailsPage extends StatelessWidget {
  final int classIndex;
  final int totalClasses;

  const ClassDetailsPage({
    super.key,
    required this.classIndex,
    required this.totalClasses,
  });

  static const _date = 'distributionDate';
  static const _present = 'present';
  static const _boysPresent = 'boysPresent';
  static const _girlsPresent = 'girlsPresent';
  static const _absent = 'absent';

  @override
  Widget build(BuildContext context) {
    final state = context.read<BednetDistributionBloc>().state;
    final school = state.selectedSchool;
    if (school == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final classIndividual = state.classIndividuals.elementAtOrNull(classIndex);
    final schoolFieldMap = <String, Object?>{
      for (final field
          in school.additionalFields?.fields ?? const <AdditionalField>[])
        field.key.toLowerCase(): field.value as Object?,
    };

    int? readSchoolInt(List<String> keys) {
      for (final key in keys) {
        final raw = schoolFieldMap[key.toLowerCase()];
        if (raw == null) continue;
        final parsed = int.tryParse(raw.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    int resolveClassOrdinal() {
      final fields =
          classIndividual?.additionalFields?.fields ?? const <AdditionalField>[];
      for (final field in fields) {
        if (field.key.toLowerCase() != kBednetClassIndexKey.toLowerCase()) {
          continue;
        }
        final parsed = int.tryParse(field.value.toString());
        if (parsed != null && parsed > 0) return parsed;
      }
      final givenName = classIndividual?.name?.givenName?.trim() ?? '';
      final classNumMatch = RegExp(r'(\d+)').firstMatch(givenName);
      if (classNumMatch != null) {
        final parsed = int.tryParse(classNumMatch.group(1)!);
        if (parsed != null && parsed > 0) return parsed;
      }
      return classIndex + 1;
    }

    final className = classIndividual?.name?.givenName?.trim();
    final classLabel = (className?.isNotEmpty ?? false)
        ? className!
        : 'Class ${classIndex + 1}';
    final classOrdinal = resolveClassOrdinal();

    final previous = state.classDetailsByClass.elementAt(classIndex);
    final classTotalBoysFromSchool = readSchoolInt([
      'class${classOrdinal}_totalboys',
      'class${classOrdinal}_numberofboys',
      'class${classOrdinal}_boys',
    ]);
    final classTotalGirlsFromSchool = readSchoolInt([
      'class${classOrdinal}_totalgirls',
      'class${classOrdinal}_numberofgirls',
      'class${classOrdinal}_girls',
    ]);
    final classTotalPupilsFromSchool = readSchoolInt([
      'class${classOrdinal}_totalstudents',
      'class${classOrdinal}_totalpupils',
      'class${classOrdinal}_pupilcount',
      'class${classOrdinal}_total',
    ]);

    final classPupilCount =
        previous?.pupilCount ??
            classTotalPupilsFromSchool ??
            ((classTotalBoysFromSchool ?? 0) + (classTotalGirlsFromSchool ?? 0) >
                    0
                ? (classTotalBoysFromSchool ?? 0) +
                    (classTotalGirlsFromSchool ?? 0)
                : school.bednetPupilCount);
    final classBoys =
        previous?.numberOfBoys ?? classTotalBoysFromSchool ?? school.bednetNumberOfBoys;
    final classGirls = previous?.numberOfGirls ??
        classTotalGirlsFromSchool ??
        school.bednetNumberOfGirls;

    return ReactiveFormBuilder(
      form: () => fb.group({
        _date: FormControl<DateTime>(
          value: previous?.distributionDate ?? DateTime.now(),
        ),
        _present: FormControl<String>(
          value: previous?.pupilsPresent.toString() ?? '',
          validators: [
            Validators.required,
            Validators.delegate(
              (c) => _bednetMaxIntFormValidator(classPupilCount, c),
            ),
          ],
        ),
        _boysPresent: FormControl<String>(
          value: previous?.boysPresent.toString() ?? '',
          validators: [
            Validators.required,
            Validators.delegate(
              (c) => _bednetMaxIntFormValidator(classBoys, c),
            ),
          ],
        ),
        _girlsPresent: FormControl<String>(
          value: previous?.girlsPresent.toString() ?? '',
          validators: [
            Validators.required,
            Validators.delegate(
              (c) => _bednetMaxIntFormValidator(classGirls, c),
            ),
          ],
        ),
        _absent: FormControl<String>(
          value: previous?.pupilsAbsent.toString() ?? '',
        ),
      }, [
        Validators.delegate(_presentCompositionValidator),
      ]),
      builder: (context, form, _) {
        final theme = Theme.of(context);
        final textTheme = theme.digitTextTheme(context);

        void recomputeAbsent() {
          final total = classPupilCount;
          final presentRaw = (form.control(_present).value ?? '').toString();
          final present = int.tryParse(presentRaw);
          if (present == null || total < 0) {
            form.control(_absent).value = '';
            return;
          }
          final absent = (total - present).clamp(0, total);
          form.control(_absent).value = absent.toString();
        }

        recomputeAbsent();

        return Scaffold(
          body: ScrollableContent(
            enableFixedDigitButton: true,
            header: const BackNavigationHelpHeaderWidget(showHelp: false),
            footer: StreamBuilder<Object?>(
              stream: form.valueChanges,
              initialData: form.value,
              builder: (context, _) {
                return DigitCard(
                  margin: const EdgeInsets.only(top: spacer2),
                  children: [
                    DigitButton(
                      label: 'Submit',
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large,
                      mainAxisSize: MainAxisSize.max,
                      isDisabled: !form.valid,
                      onPressed: () {
                        form.markAllAsTouched();
                        if (!form.valid) return;

                        final details = ClassDetailsModel(
                          distributionDate:
                              form.control(_date).value as DateTime,
                          pupilCount: classPupilCount,
                          numberOfBoys: classBoys,
                          numberOfGirls: classGirls,
                          pupilsPresent: int.tryParse(
                                  form.control(_present).value as String? ??
                                      '0') ??
                              0,
                          boysPresent: int.tryParse(
                                  form.control(_boysPresent).value as String? ??
                                      '0') ??
                              0,
                          girlsPresent: int.tryParse(
                                  form.control(_girlsPresent).value as String? ??
                                      '0') ??
                              0,
                          pupilsAbsent: int.tryParse(
                                  form.control(_absent).value as String? ??
                                      '0') ??
                              0,
                        );

                        context.read<BednetDistributionBloc>().add(
                              BednetDistributionEvent.saveClassDetails(
                                classIndex: classIndex,
                                details: details,
                              ),
                            );

                        context.router.push(
                          ClassTeacherInfoRoute(
                            classIndex: classIndex,
                            totalClasses: totalClasses,
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
                child: Column(
                  children: [
                    BednetInfoCard(
                      title: '$classLabel Details',
                      items: [
                        MapEntry(
                          'Date of Distribution',
                          DateFormat('d MMMM y')
                              .format(form.control(_date).value as DateTime),
                        ),
                        MapEntry('Pupil Count', classPupilCount.toString()),
                        MapEntry('Number of Boys', classBoys.toString()),
                        MapEntry('Number of Girls', classGirls.toString()),
                      ],
                    ),
                    DigitCard(
                      margin: const EdgeInsets.all(spacer2),
                      children: [
                        ReactiveWrapperField(
                          formControlName: _present,
                          validationMessages: {
                            'required': (_) =>
                                'Number of pupils present is required',
                            'invalidNumber': (_) => 'Enter a valid number',
                            'negative': (_) => 'Value cannot be negative',
                            'maxExceeded': (_) =>
                                'Cannot exceed total pupils in class ($classPupilCount)',
                          },
                          builder: (field) => LabeledField(
                            label: 'Number of Pupils Present',
                            isRequired: true,
                            child: DigitTextFormInput(
                              initialValue: form.control(_present).value,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              errorMessage: field.errorText,
                              onChange: (value) {
                                form.control(_present).value = value;
                                recomputeAbsent();
                              },
                            ),
                          ),
                        ),
                        ReactiveWrapperField(
                          formControlName: _boysPresent,
                          validationMessages: {
                            'required': (_) =>
                                'Total number of boys present is required',
                            'invalidNumber': (_) => 'Enter a valid number',
                            'negative': (_) => 'Value cannot be negative',
                            'maxExceeded': (_) =>
                                'Cannot exceed total boys in class ($classBoys)',
                          },
                          builder: (field) => LabeledField(
                            label: 'Total number of Boys Present',
                            isRequired: true,
                            child: DigitTextFormInput(
                              initialValue: form.control(_boysPresent).value,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                                'Total number of girls present is required',
                            'invalidNumber': (_) => 'Enter a valid number',
                            'negative': (_) => 'Value cannot be negative',
                            'maxExceeded': (_) =>
                                'Cannot exceed total girls in class ($classGirls)',
                          },
                          builder: (field) => LabeledField(
                            label: 'Total number of Girls Present',
                            isRequired: true,
                            child: DigitTextFormInput(
                              initialValue: form.control(_girlsPresent).value,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              errorMessage: field.errorText,
                              onChange: (value) {
                                form.control(_girlsPresent).value = value;
                              },
                            ),
                          ),
                        ),
                        ReactiveWrapperField<String>(
                          formControlName: _absent,
                          builder: (field) {
                            final absentText =
                                field.control.value as String? ?? '';
                            return LabeledField(
                              label: 'Total number of Pupils Absent',
                              isRequired: true,
                              child: DigitTextFormInput(
                                key: ValueKey(absentText),
                                initialValue: absentText,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                                onChange: (_) {},
                              ),
                            );
                          },
                        ),
                        if (form.hasError('presentMismatch'))
                          Padding(
                            padding: const EdgeInsets.only(top: spacer1),
                            child: Text(
                              'Boys present + Girls present must equal Number of Pupils Present',
                              style: textTheme.bodyS.copyWith(
                                color: theme.colorTheme.alert.error,
                              ),
                            ),
                          ),
                      ],
                    )
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
