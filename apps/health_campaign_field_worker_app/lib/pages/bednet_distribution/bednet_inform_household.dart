import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';

import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../widgets/header/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';
import 'bednet_success_page.dart';

class BednetInformHouseholdPage extends LocalizedStatefulWidget {
  final String eToken;
  final int itnForDelivery;

  const BednetInformHouseholdPage({
    super.key,
    super.appLocalizations,
    required this.eToken,
    required this.itnForDelivery,
  });

  @override
  State<BednetInformHouseholdPage> createState() =>
      _BednetInformHouseholdPageState();
}

class _BednetInformHouseholdPageState
    extends LocalizedState<BednetInformHouseholdPage> {
  static final List<String> _messageKeys = [
    i18.bednetDistribution.netInstruction1,
    i18.bednetDistribution.netInstruction2,
    i18.bednetDistribution.netInstruction3,
    i18.bednetDistribution.netInstruction4,
    i18.bednetDistribution.netInstruction5,
    i18.bednetDistribution.netInstruction6,
    i18.bednetDistribution.netInstruction7,
  ];

  late final List<bool> _checked =
      List<bool>.filled(_messageKeys.length, false);
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return BlocListener<BeneficiaryRegistrationBloc,
        BeneficiaryRegistrationState>(
      listener: (context, state) {
        state.mapOrNull(
          persisted: (_) {
            if (!mounted || _isSubmitting) return;
            _isSubmitting = true;
            final registrationBloc =
                context.read<BeneficiaryRegistrationBloc>();
            // Replace inform screen only so the Material stack below (review →
            // household details → location → search) stays intact and the same
            // [BeneficiaryRegistrationBloc] remains valid for "View household".
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: registrationBloc,
                  child: BednetSuccessPage(
                    eToken: widget.eToken,
                    itnForDelivery: widget.itnForDelivery,
                    appLocalizations: localizations,
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Scaffold(
        body: ScrollableContent(
          enableFixedDigitButton: true,
          header: const BackNavigationHelpHeaderWidget(showHelp: true),
          footer: DigitCard(
            margin: const EdgeInsets.only(top: spacer2),
            children: [
              DigitButton(
                label: localizations.translate(i18.common.coreCommonSubmit),
                type: DigitButtonType.primary,
                size: DigitButtonSize.large,
                mainAxisSize: MainAxisSize.max,
                isDisabled: _checked.contains(false),
                onPressed: _openSubmitDialog,
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
                    Text(
                      localizations.translate(
                        i18.bednetDistribution.informHouseholdTitle,
                      ),
                      style: textTheme.headingXl.copyWith(
                        color: const Color(0xFF005A7A),
                      ),
                    ),
                    const SizedBox(height: spacer2),
                    ...List.generate(_messageKeys.length, (idx) {
                      return InkWell(
                        onTap: () =>
                            setState(() => _checked[idx] = !_checked[idx]),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: spacer2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFCC4C02),
                                    width: 1.3,
                                  ),
                                ),
                                child: _checked[idx]
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Color(0xFFCC4C02),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: spacer2),
                              Expanded(
                                child: Text(
                                  localizations.translate(_messageKeys[idx]),
                                  style: textTheme.headingXl.copyWith(
                                    fontSize:
                                        (textTheme.headingXl.fontSize ?? 24) *
                                            0.7,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSubmitDialog() async {
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => Popup(
        title: localizations.translate(
          i18.bednetDistribution.informHouseholdReadyToSubmitLabel,
        ),
        description: localizations.translate(
          i18.bednetDistribution.informHouseholdSubmitConfirmText,
        ),
        actions: [
          DigitButton(
            label: localizations.translate(i18.common.coreCommonSubmit),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          DigitButton(
            label: localizations.translate(i18.common.coreCommonCancel),
            type: DigitButtonType.tertiary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );

    if (submit == true && mounted) {
      final registrationBloc = context.read<BeneficiaryRegistrationBloc>();
      final boundary = RegistrationDeliverySingleton().boundary;
      final userUuid = RegistrationDeliverySingleton().loggedInUserUuid ?? '';
      final projectId = RegistrationDeliverySingleton().projectId ?? '';

      if (boundary == null) return;

      // Build projectBeneficiaryModel with the eToken as tag, then persist.
      registrationBloc.add(BeneficiaryRegistrationEvent.summary(
        userUuid: userUuid,
        projectId: projectId,
        boundary: boundary,
        tag: widget.eToken,
        navigateToSummary: false,
      ));
      registrationBloc.add(BeneficiaryRegistrationEvent.create(
        userUuid: userUuid,
        projectId: projectId,
        boundary: boundary,
        navigateToSummary: false,
      ));
    }
  }
}
