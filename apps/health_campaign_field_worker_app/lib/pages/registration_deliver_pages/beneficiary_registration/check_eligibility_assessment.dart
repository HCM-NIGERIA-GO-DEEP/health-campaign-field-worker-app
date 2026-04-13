import 'dart:convert';

import 'package:digit_data_model/data_model.dart'
    hide ReferralModel, ReferralSearchModel;

import '../../../models/registration_deliver_model/entities/referral.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/enum/app_enums.dart';
import 'package:digit_ui_components/theme/spacers.dart';
import 'package:digit_ui_components/widgets/atoms/digit_button.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/scrollable_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:group_radio_button/group_radio_button.dart';
import '../../../blocs/registration_deliver/delivery_intervention/deliver_intervention.dart';
import '../../../blocs/registration_deliver/referral_management/referral_management.dart';
import '../../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../../blocs/registration_deliver/search_households/search_households.dart';
import '../../../models/registration_deliver_model/entities/status.dart';
import '../../../router/app_router.dart';
import '../../../utils/environment_config.dart';
import '../../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../../utils/registration_deliver_utils/utils.dart';
import '../../../widgets/custom_back_navigation.dart';
import '../../../widgets/registartion_deliver/localized.dart';
import 'refer_beneficiary_page.dart';

/// TB eligibility screening (6 Yes/No questions) and routing to referral or success.
class TbEligibilityAssessmentPage extends LocalizedStatefulWidget {
  final IndividualModel child;
  final String householdClientReferenceId;
  final String projectBeneficiaryClientReferenceId;
  final String administrativeAreaCode;

  const TbEligibilityAssessmentPage({
    super.key,
    super.appLocalizations,
    required this.child,
    required this.householdClientReferenceId,
    required this.projectBeneficiaryClientReferenceId,
    required this.administrativeAreaCode,
  });

  @override
  State<TbEligibilityAssessmentPage> createState() =>
      _TbEligibilityAssessmentPageState();
}

class _TbEligibilityAssessmentPageState
    extends LocalizedState<TbEligibilityAssessmentPage> {
  static const _yes = 'YES';
  static const _no = 'NO';

  final List<String?> _answers = List<String?>.filled(6, null);

  bool _showAdditionalSymptoms = false;
  final Set<String> _additionalSymptoms = {};

  bool get _allAnswered =>
      _answers.every((e) => e != null && e.isNotEmpty);

  int get _yesCount => _answers.where((e) => e == _yes).length;

  bool get _q1Yes => _answers[0] == _yes;

  bool get _needsReferral => _q1Yes || _yesCount >= 2;

  bool get _needsAdditionalSymptomStep => _yesCount >= 2 && !_q1Yes;

  List<String> _referralReasonCodes() {
    final reasons = <String>[];
    if (_q1Yes) reasons.add('TB_COUGH_TWO_WEEKS');
    for (var i = 1; i < _answers.length; i++) {
      if (_answers[i] == _yes) {
        reasons.add('TB_SCREENING_Q${i + 1}');
      }
    }
    if (reasons.isEmpty) reasons.add('TB_SCREENING');
    return reasons;
  }

  Map<String, dynamic> _payloadMap() {
    return {
      'q1': _answers[0],
      'q2': _answers[1],
      'q3': _answers[2],
      'q4': _answers[3],
      'q5': _answers[4],
      'q6': _answers[5],
      'additionalSymptoms': _additionalSymptoms.toList(),
      'childClientReferenceId': widget.child.clientReferenceId,
      'householdClientReferenceId': widget.householdClientReferenceId,
      'administrativeAreaCode': widget.administrativeAreaCode,
    };
  }

  Future<void> _showReadyToSubmitModal({required VoidCallback onProceed}) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Popup(
        title: localizations.translate(i18.tbScreening.readyToSubmitTitle),
        type: PopUpType.simple,
        description:
            localizations.translate(i18.tbScreening.readyToSubmitMessage),
        actions: [
          DigitButton(
            label: localizations.translate(i18.tbScreening.proceed),
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
          DigitButton(
            label: localizations.translate(i18.common.coreCommonCancel),
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            type: DigitButtonType.secondary,
            size: DigitButtonSize.large,
          ),
        ],
      ),
    );
    if (go == true) onProceed();
  }

  Future<void> _recordNoReferralAndExit() async {
    final taskRef = IdGen.i.identifier;
    final payload = jsonEncode(_payloadMap());

    context.read<DeliverInterventionBloc>().add(
          DeliverInterventionSubmitEvent(
            task: TaskModel(
              projectBeneficiaryClientReferenceId:
                  widget.projectBeneficiaryClientReferenceId,
              clientReferenceId: taskRef,
              tenantId: envConfig.variables.tenantId,
              rowVersion: 1,
              auditDetails: AuditDetails(
                createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
                createdTime: DateTime.now().millisecondsSinceEpoch,
              ),
              projectId: RegistrationDeliverySingleton().projectId!,
              status: Status.visited.toValue(),
              clientAuditDetails: ClientAuditDetails(
                createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
                createdTime: DateTime.now().millisecondsSinceEpoch,
                lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid!,
                lastModifiedTime: DateTime.now().millisecondsSinceEpoch,
              ),
              additionalFields: TaskAdditionalFields(
                version: 1,
                fields: [
                  const AdditionalField('tbScreeningOutcome', 'no_referral'),
                  const AdditionalField('referralType', 'tbScreening'),
                  AdditionalField('tbScreeningData', payload),
                  AdditionalField(
                    'childClientReferenceId',
                    widget.child.clientReferenceId,
                  ),
                  AdditionalField(
                    'householdClientReferenceId',
                    widget.householdClientReferenceId,
                  ),
                  AdditionalField(
                    'administrativeAreaCode',
                    widget.administrativeAreaCode,
                  ),
                ],
              ),
              address: widget.child.address?.first.copyWith(
                relatedClientReferenceId: taskRef,
                id: null,
              ),
            ),
            isEditing: false,
            boundaryModel: RegistrationDeliverySingleton().boundary!,
          ),
        );

    context.read<SearchHouseholdsBloc>().add(const SearchHouseholdsEvent.clear());
    context.read<HouseholdOverviewBloc>().add(
          HouseholdOverviewReloadEvent(
            projectId: RegistrationDeliverySingleton().projectId!,
            projectBeneficiaryType: RegistrationDeliverySingleton().beneficiaryType!,
          ),
        );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;
    await context.router.push(
      HouseholdAcknowledgementRoute(enableViewHousehold: true),
    );
  }

  Future<void> _onPrimarySubmit() async {
    if (!_allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations.translate(i18.common.corecommonRequired),
          ),
        ),
      );
      return;
    }

    if (!_needsReferral) {
      await _recordNoReferralAndExit();
      return;
    }

    if (_needsAdditionalSymptomStep) {
      if (!_showAdditionalSymptoms) {
        setState(() => _showAdditionalSymptoms = true);
        return;
      }
      if (_additionalSymptoms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.translate(i18.tbScreening.additionalSymptomsRequired),
            ),
          ),
        );
        return;
      }
    }

    await _showReadyToSubmitModal(
      onProceed: () async {
        if (!mounted) return;
        await Navigator.of(context, rootNavigator: true).push<bool>(
          MaterialPageRoute(
            builder: (ctx) => BlocProvider(
              create: (c) => ReferralBloc(
                const ReferralState(),
                referralRepository:
                    c.repository<ReferralModel, ReferralSearchModel>(c),
              ),
              child: TbReferBeneficiaryPage(
                appLocalizations: localizations,
                projectBeneficiaryClientRefId:
                    widget.projectBeneficiaryClientReferenceId,
                individual: widget.child,
                householdClientReferenceId: widget.householdClientReferenceId,
                administrativeAreaCode: widget.administrativeAreaCode,
                referralReasons: _referralReasonCodes(),
                tbScreeningPayload: jsonEncode(_payloadMap()),
              ),
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        if (!mounted) return;
        await context.router.push(
          HouseholdAcknowledgementRoute(enableViewHousehold: true),
        );
      },
    );
  }

  Widget _questionTile(int index, String labelKey) {
    final theme = Theme.of(context);
    return DigitCard(
      margin: const EdgeInsets.only(bottom: spacer2),
      children: [
        Text(
          localizations.translate(labelKey),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: spacer2),
        RadioGroup<String>.builder(
          groupValue: _answers[index] ?? '',
          onChanged: (v) {
            setState(() {
              _answers[index] = v;
            });
          },
          items: const [_yes, _no],
          itemBuilder: (v) => RadioButtonBuilder(
            localizations.translate('CORE_COMMON_${v.trim().toUpperCase()}'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final additionalRequired = _showAdditionalSymptoms &&
        _needsAdditionalSymptomStep &&
        _additionalSymptoms.isEmpty;

    return ScrollableContent(
      enableFixedDigitButton: true,
      header: const Column(
        children: [
          CustomBackNavigationHelpHeaderWidget(showHelp: false),
        ],
      ),
      footer: DigitCard(
        margin: const EdgeInsets.fromLTRB(0, spacer2, 0, 0),
        padding: const EdgeInsets.fromLTRB(spacer2, 0, spacer2, 0),
        children: [
          DigitButton(
            label: localizations.translate(i18.common.coreCommonSubmit),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
            mainAxisSize: MainAxisSize.max,
            onPressed: _onPrimarySubmit,
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(spacer2),
          child: Text(
            localizations.translate(i18.tbScreening.screenTitle),
            style: theme.textTheme.displayMedium,
          ),
        ),
        _questionTile(0, i18.tbScreening.q1),
        _questionTile(1, i18.tbScreening.q2),
        _questionTile(2, i18.tbScreening.q3),
        _questionTile(3, i18.tbScreening.q4),
        _questionTile(4, i18.tbScreening.q5),
        _questionTile(5, i18.tbScreening.q6),
        if (_showAdditionalSymptoms && _needsAdditionalSymptomStep) ...[
          Padding(
            padding: const EdgeInsets.all(spacer2),
            child: Text(
              localizations.translate(i18.tbScreening.additionalSymptomsTitle),
              style: theme.textTheme.titleLarge,
            ),
          ),
          DigitCard(
            children: [
              CheckboxListTile(
                title: Text(
                  localizations.translate(i18.tbScreening.symptomNightSweats),
                ),
                value: _additionalSymptoms.contains('NIGHT_SWEATS'),
                onChanged: (_) {
                  setState(() {
                    if (_additionalSymptoms.contains('NIGHT_SWEATS')) {
                      _additionalSymptoms.remove('NIGHT_SWEATS');
                    } else {
                      _additionalSymptoms.add('NIGHT_SWEATS');
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: Text(
                  localizations.translate(i18.tbScreening.symptomFatigue),
                ),
                value: _additionalSymptoms.contains('PERSISTENT_FATIGUE'),
                onChanged: (_) {
                  setState(() {
                    if (_additionalSymptoms.contains('PERSISTENT_FATIGUE')) {
                      _additionalSymptoms.remove('PERSISTENT_FATIGUE');
                    } else {
                      _additionalSymptoms.add('PERSISTENT_FATIGUE');
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: Text(
                  localizations.translate(i18.tbScreening.symptomLymph),
                ),
                value: _additionalSymptoms.contains('SWOLLEN_LYMPH_NODES'),
                onChanged: (_) {
                  setState(() {
                    if (_additionalSymptoms.contains('SWOLLEN_LYMPH_NODES')) {
                      _additionalSymptoms.remove('SWOLLEN_LYMPH_NODES');
                    } else {
                      _additionalSymptoms.add('SWOLLEN_LYMPH_NODES');
                    }
                  });
                },
              ),
              if (additionalRequired)
                Padding(
                  padding: const EdgeInsets.only(top: spacer2),
                  child: Text(
                    localizations.translate(
                      i18.tbScreening.additionalSymptomsRequired,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
