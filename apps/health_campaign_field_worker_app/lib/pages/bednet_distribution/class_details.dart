import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
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
    final classFields =
        classIndividual?.additionalFields?.fields ?? const <AdditionalField>[];
    final additionalFieldMap = <String, Object?>{
      for (final field in classFields) field.key.toLowerCase(): field.value,
    };

    int? readNullableInt(List<String> keys) {
      for (final key in keys) {
        final raw = additionalFieldMap[key.toLowerCase()];
        if (raw == null) continue;
        final value = int.tryParse(raw.toString());
        if (value != null) return value;
      }
      return null;
    }

    DateTime readDate() {
      final raw = additionalFieldMap['distributiondate'];
      if (raw == null) return DateTime.now();
      final millis = int.tryParse(raw.toString());
      if (millis == null) return DateTime.now();
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }

    final className = classIndividual?.name?.givenName?.trim();
    final classLabel = (className?.isNotEmpty ?? false)
        ? className!
        : 'Class ${classIndex + 1}';

    final previous = state.classDetailsByClass.elementAt(classIndex);
    final classPupilCount =
        previous?.pupilCount ?? school.bednetPupilCount;
    final classBoys = previous?.numberOfBoys ?? school.bednetNumberOfBoys;
    final classGirls = previous?.numberOfGirls ?? school.bednetNumberOfGirls;

    return ReactiveFormBuilder(
      form: () => fb.group({
        _date: FormControl<DateTime>(
          value: previous?.distributionDate ?? readDate(),
        ),
        _present: FormControl<String>(
          value: previous?.pupilsPresent.toString() ??
              readNullableInt(
                const ['pupilspresent', 'pupils_present'],
              )?.toString() ??
              '',
          validators: [
            Validators.required,
            Validators.delegate(
              (c) => _bednetMaxIntFormValidator(classPupilCount, c),
            ),
          ],
        ),
        _boysPresent: FormControl<String>(
          value: previous?.boysPresent.toString() ??
              readNullableInt(
                const ['boyspresent', 'boys_present'],
              )?.toString() ??
              '',
          validators: [
            Validators.required,
            Validators.delegate(
              (c) => _bednetMaxIntFormValidator(classBoys, c),
            ),
          ],
        ),
        _girlsPresent: FormControl<String>(
          value: previous?.girlsPresent.toString() ??
              readNullableInt(
                const ['girlspresent', 'girls_present'],
              )?.toString() ??
              '',
          validators: [
            Validators.required,
            Validators.delegate(
              (c) => _bednetMaxIntFormValidator(classGirls, c),
            ),
          ],
        ),
        _absent: FormControl<String>(
          value: previous?.pupilsAbsent.toString() ??
              readNullableInt(
                const ['pupilsabsent', 'pupils_absent'],
              )?.toString() ??
              '',
        ),
      }),
      builder: (context, form, _) {
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
            footer: DigitCard(
              margin: const EdgeInsets.only(top: spacer2),
              children: [
                DigitButton(
                  label: 'Submit',
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: () {
                    form.markAllAsTouched();
                    if (!form.valid) return;

                    final details = ClassDetailsModel(
                      distributionDate: form.control(_date).value as DateTime,
                      pupilCount: classPupilCount,
                      numberOfBoys: classBoys,
                      numberOfGirls: classGirls,
                      pupilsPresent: int.tryParse(
                              form.control(_present).value as String? ?? '0') ??
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
                              form.control(_absent).value as String? ?? '0') ??
                          0,
                    );

                    context.read<BednetDistributionBloc>().add(
                          BednetDistributionEvent.saveClassDetails(
                            classIndex: classIndex,
                            details: details,
                          ),
                        );

                    context.router.push(
                      DistributionSummaryRoute(
                        classIndex: classIndex,
                        totalClasses: totalClasses,
                      ),
                    );
                  },
                ),
              ],
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
