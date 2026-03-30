import 'package:collection/collection.dart';
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

/// Mobile must be exactly 11 digits (optional spaces stripped before check).
Map<String, dynamic>? _teacherMobileElevenDigits(
  AbstractControl<dynamic> control,
) {
  final raw = control.value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length != 11) {
    return {'mobileElevenDigits': true};
  }
  return null;
}

@RoutePage()
class ClassTeacherInfoPage extends StatelessWidget {
  final int classIndex;
  final int totalClasses;

  const ClassTeacherInfoPage({
    super.key,
    required this.classIndex,
    required this.totalClasses,
  });

  static const _name = 'name';
  static const _gender = 'gender';
  static const _mobile = 'mobile';

  static const _genderItems = [
    DropdownItem(name: 'Male', code: 'Male'),
    DropdownItem(name: 'Female', code: 'Female'),
    DropdownItem(name: 'Other', code: 'Other'),
  ];

  /// Empty string until the user selects a value (no default to Male).
  static String _normalizeGender(String? raw) {
    if (raw == null) return '';
    final t = raw.trim();
    if (t.isEmpty) return '';
    final lower = t.toLowerCase();
    for (final item in _genderItems) {
      if (item.code.toLowerCase() == lower) return item.code;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<BednetDistributionBloc>().state;
    final existing = state.teacherInfoByClass.elementAt(classIndex);
    final classIndividual = state.classIndividuals.elementAtOrNull(classIndex);
    final classFields =
        classIndividual?.additionalFields?.fields ?? const <AdditionalField>[];
    final additionalFieldMap = <String, Object?>{
      for (final field in classFields) field.key.toLowerCase(): field.value,
    };
    final className = classIndividual?.name?.givenName?.trim();
    final classLabel = (className?.isNotEmpty ?? false)
        ? className!
        : 'Class ${classIndex + 1}';

    return ReactiveFormBuilder(
      form: () => fb.group({
        _name: FormControl<String>(
          value: existing?.name ??
              additionalFieldMap['teachername']?.toString() ??
              '',
          validators: [Validators.required],
        ),
        _gender: FormControl<String>(
          value: _normalizeGender(
            existing?.gender ??
                additionalFieldMap['teachergender']?.toString(),
          ),
          validators: [Validators.required],
        ),
        _mobile: FormControl<String>(
          value: existing?.mobileNumber ??
              additionalFieldMap['teachermobilenumber']?.toString() ??
              '',
          validators: [
            Validators.required,
            Validators.delegate(_teacherMobileElevenDigits),
          ],
        ),
      }),
      builder: (context, form, _) {
        final theme = Theme.of(context);
        final textTheme = theme.digitTextTheme(context);
        final genderVal = (form.control(_gender).value as String?) ?? '';
        final genderSelected = genderVal.isEmpty
            ? null
            : (_genderItems.firstWhereOrNull((e) => e.code == genderVal) ??
                DropdownItem(name: genderVal, code: genderVal));
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
                  onPressed: () {
                    form.markAllAsTouched();
                    if (!form.valid) return;

                    final mobileRaw =
                        (form.control(_mobile).value as String?) ?? '';
                    final mobileDigits =
                        mobileRaw.replaceAll(RegExp(r'\D'), '');

                    context.read<BednetDistributionBloc>().add(
                          BednetDistributionEvent.saveTeacherInfo(
                            classIndex: classIndex,
                            info: ClassTeacherInfoModel(
                              name: (form.control(_name).value as String?) ?? '',
                              gender: (form.control(_gender).value as String?) ?? '',
                              mobileNumber: mobileDigits,
                            ),
                          ),
                        );

                    context.router.push(
                      ClassDetailsRoute(
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: spacer2,
                          right: spacer2,
                        ),
                        child: DigitButton(
                          label: 'Help',
                          suffixIcon: Icons.help_outline_outlined,
                          type: DigitButtonType.tertiary,
                          size: DigitButtonSize.medium,
                          onPressed: () {},
                        ),
                      ),
                    ),
                    DigitCard(
                      margin: const EdgeInsets.all(spacer2),
                      children: [
                        Text(
                          '$classLabel Teacher Information',
                          style: textTheme.headingXl.copyWith(
                              color: theme.colorTheme.primary.primary2),
                        ),
                        const SizedBox(height: spacer2),
                        ReactiveWrapperField(
                          formControlName: _name,
                          validationMessages: {
                            'required': (_) => 'Name is required',
                          },
                          builder: (field) => LabeledField(
                            label: 'Name',
                            isRequired: true,
                            child: DigitTextFormInput(
                              initialValue: form.control(_name).value,
                              errorMessage: field.errorText,
                              keyboardType: TextInputType.text,
                              onChange: (value) {
                                form.control(_name).value = value;
                              },
                            ),
                          ),
                        ),
                        ReactiveWrapperField(
                          formControlName: _gender,
                          validationMessages: {
                            'required': (_) => 'Gender is required',
                          },
                          builder: (field) => LabeledField(
                            label: 'Gender',
                            isRequired: true,
                            child: DigitDropdown<String>(
                              items: _genderItems,
                              emptyItemText: 'Select gender',
                              selectedOption: genderSelected,
                              onSelect: (value) {
                                form.control(_gender).value = value.code;
                              },
                              errorMessage: field.errorText,
                            ),
                          ),
                        ),
                        ReactiveWrapperField(
                          formControlName: _mobile,
                          validationMessages: {
                            'required': (_) => 'Mobile number is required',
                            'mobileElevenDigits': (_) =>
                                'Enter exactly 11 digits for mobile number',
                          },
                          builder: (field) => LabeledField(
                            label: 'Mobile number',
                            isRequired: true,
                            child: DigitTextFormInput(
                              initialValue: form.control(_mobile).value,
                              errorMessage: field.errorText,
                              keyboardType: TextInputType.number,
                              onChange: (value) {
                                form.control(_mobile).value = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
