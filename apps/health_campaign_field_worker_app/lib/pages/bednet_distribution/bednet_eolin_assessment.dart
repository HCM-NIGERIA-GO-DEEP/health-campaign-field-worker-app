import 'dart:math';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:group_radio_button/group_radio_button.dart';

import '../../blocs/localization/app_localization.dart';
import '../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../models/entities/additional_fields_type.dart';
import '../../utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/utils.dart';

import '../../widgets/header/back_navigation_help_header.dart';
import 'bednet_household_review.dart';
import 'bednet_inform_household.dart';

/// End-of-life insecticide net (EOLIN) assessment before SBCC / inform household.
class BednetEolinAssessmentPage extends StatefulWidget {
  final String headName;
  final int memberCount;
  final int childrenCount;
  final String? mobileNumber;
  final String? householdEToken;
  final HouseholdModel? bednetDeliveryHousehold;
  final IndividualModel? bednetDeliveryHead;

  const BednetEolinAssessmentPage({
    super.key,
    required this.headName,
    required this.memberCount,
    required this.childrenCount,
    this.mobileNumber,
    this.householdEToken,
    this.bednetDeliveryHousehold,
    this.bednetDeliveryHead,
  });

  @override
  State<BednetEolinAssessmentPage> createState() =>
      _BednetEolinAssessmentPageState();
}

class _BednetEolinAssessmentPageState extends State<BednetEolinAssessmentPage> {
  static const _yes = 'YES';
  static const _no = 'NO';

  String? _hasOldNetsAnswer;
  int _returningCount = 1;
  bool _isSaving = false;

  int get _itnForDelivery => max(1, (widget.memberCount / 2).ceil());

  String get _effectiveToken {
    final stored = widget.householdEToken?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return BednetHouseholdReviewPage.syntheticEToken(
      headName: widget.headName,
      memberCount: widget.memberCount,
    );
  }

  bool get _canProceed {
    if (_hasOldNetsAnswer == null) return false;
    if (_hasOldNetsAnswer == _yes) {
      return _returningCount >= 1 &&
          _returningCount <= _itnForDelivery;
    }
    return true;
  }

  /// Persists returning count only when the user answered Yes, and only if
  /// [eolinOldNetsReturningCount] already exists on the household (MDMS).
  /// the household (MDMS-provisioned). Skips when [additionalFields] is null or
  /// when a key is absent, so sync is not broken by unknown fields.
  Future<void> _persistEolinToHouseholdIfApplicable() async {
    final seed = widget.bednetDeliveryHousehold;
    if (seed == null) return;

    final householdRepo =
        context.repository<HouseholdModel, HouseholdSearchModel>(context);
    final userUuid = RegistrationDeliverySingleton().loggedInUserUuid ?? '';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final existingHh = (await householdRepo.search(
          HouseholdSearchModel(
            clientReferenceId: [seed.clientReferenceId],
          ),
        ))
            .firstOrNull ??
        seed;

    final additional = existingHh.additionalFields;
    if (additional == null) return;

    final fieldList = List<AdditionalField>.from(additional.fields);
    final countKey = AdditionalFieldsType.eolinOldNetsReturningCount.toValue();

    var touched = false;
    if (_hasOldNetsAnswer == _yes) {
      touched |= _setFieldIfKeyExists(
        fieldList,
        countKey,
        _returningCount.toString(),
      );
    } else if (_hasOldNetsAnswer == _no) {
      touched |= _setFieldIfKeyExists(fieldList, countKey, '0');
    }

    if (!touched) return;

    await householdRepo.update(
      existingHh.copyWith(
        additionalFields: HouseholdAdditionalFields(
          version: additional.version,
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
  }

  /// Returns true if [key] was present and updated.
  bool _setFieldIfKeyExists(
    List<AdditionalField> fields,
    String key,
    String value,
  ) {
    final i = fields.indexWhere((f) => f.key == key);
    if (i < 0) return false;
    fields[i] = AdditionalField(key, value);
    return true;
  }

  void _navigateToInformHousehold() {
    final registrationBloc = context.read<BeneficiaryRegistrationBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: registrationBloc,
          child: BednetInformHouseholdPage(
            eToken: _effectiveToken,
            itnForDelivery: _itnForDelivery,
            existingDeliveryHousehold: widget.bednetDeliveryHousehold,
            existingDeliveryHead: widget.bednetDeliveryHead,
          ),
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    setState(() => _isSaving = true);
    try {
      await _persistEolinToHouseholdIfApplicable();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('EOLIN household persist failed: $e\n$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save EOLIN details: $e')),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
    if (!mounted) return;
    _navigateToInformHousehold();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: BackNavigationHelpHeaderWidget(
          showHelp: false,
          defaultPopRoute: false,
          handleback: () => Navigator.of(context).pop(),
        ),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: 'Next',
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              isDisabled: !_canProceed || _isSaving,
              onPressed: () {
                if (!_canProceed || _isSaving) return;
                _onNext();
              },
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
                  Text.rich(
                    TextSpan(
                      style: textTheme.headingXl.copyWith(
                        color: theme.colorTheme.primary.primary2,
                      ),
                      children: const [
                        TextSpan(text: 'EOLIN Assessment'),
                      ],
                    ),
                  ),
                  const SizedBox(height: spacer2),
                  DigitCard(
                    children: [
                      Text(
                        'Do you have old nets?',
                        style: textTheme.headingM.copyWith(
                          color: theme.colorTheme.primary.primary2,
                        ),
                      ),
                      const SizedBox(height: spacer1),
                      RadioGroup<String>.builder(
                        groupValue: _hasOldNetsAnswer ?? '',
                        onChanged: (v) {
                          setState(() {
                            _hasOldNetsAnswer = v;
                            if (v == _yes) {
                              _returningCount = _returningCount.clamp(
                                1,
                                _itnForDelivery,
                              );
                            }
                          });
                        },
                        items: const [_yes, _no],
                        itemBuilder: (v) => RadioButtonBuilder(
                          AppLocalizations.of(context).translate(
                            v == _yes
                                ? i18.common.coreCommonYes
                                : i18.common.coreCommonNo,
                          ),
                        ),
                      ),
                      if (_hasOldNetsAnswer == _yes) ...[
                        const SizedBox(height: spacer2),
                        LabeledField(
                          label: 'How many old nets are you returning?',
                          isRequired: true,
                          child: DigitNumericFormInput(
                            key: ValueKey(_hasOldNetsAnswer),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            minValue: 1,
                            maxValue: _itnForDelivery,
                            step: 1,
                            initialValue: _returningCount.toString(),
                            onChange: (value) {
                              if (value.isEmpty) return;
                              setState(() {
                                final parsed = int.tryParse(value);
                                if (parsed == null) return;
                                _returningCount =
                                    parsed.clamp(1, _itnForDelivery);
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: spacer1),
                          child: Text(
                            'Maximum $_itnForDelivery (cannot return more '
                            'bednets than are being provided for this '
                            'household).',
                            style: textTheme.bodyS.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.65),
                            ),
                          ),
                        ),
                        const SizedBox(height: spacer2),
                        DigitCard(
                          children: [
                            Container(
                              width: double.infinity,
                              color: Colors.red[700],
                              padding: const EdgeInsets.all(spacer2),
                              child: const Text(
                                'Screen the Old Nets to Confirm.\n'
                                'Distributor should ensure all EOLINs are retrieved.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
