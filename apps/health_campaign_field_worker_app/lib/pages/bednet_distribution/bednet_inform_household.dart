import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';

import '../../widgets/header/back_navigation_help_header.dart';
import 'bednet_success_page.dart';

class BednetInformHouseholdPage extends StatefulWidget {
  final String eToken;
  final int itnForDelivery;

  const BednetInformHouseholdPage({
    super.key,
    required this.eToken,
    required this.itnForDelivery,
  });

  @override
  State<BednetInformHouseholdPage> createState() =>
      _BednetInformHouseholdPageState();
}

class _BednetInformHouseholdPageState extends State<BednetInformHouseholdPage> {
  final List<String> _messages = const [
    'When you receive your net, air it under a shade for 24 hours before you hang over your mat, mattress or bed.',
    'Tuck in the net properly under your sleeping material and sleep inside every night.',
    'Roll up net when not in use.',
    'When the net is dirty, wash with mild soap; spread under a shade to dry, avoid spreading under the sun.',
    'Mend your nets when torn by sewing with thread and needle.',
    'When you and your family sleep inside the net every night, all of you will be protected from malaria.',
    'The net protects you and your family from mosquitoes that spread malaria.',
  ];

  late final List<bool> _checked = List<bool>.filled(_messages.length, false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: const BackNavigationHelpHeaderWidget(showHelp: true),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: 'Submit',
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
                    'Please Inform the Household of the following',
                    style: textTheme.headingXl.copyWith(
                      color: const Color(0xFF005A7A),
                    ),
                  ),
                  const SizedBox(height: spacer2),
                  ...List.generate(_messages.length, (i) {
                    return InkWell(
                      onTap: () => setState(() => _checked[i] = !_checked[i]),
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
                              child: _checked[i]
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
                                _messages[i],
                                style: textTheme.headingXl.copyWith(
                                  fontSize: (textTheme.headingXl.fontSize ?? 24) * 0.7,
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
    );
  }

  void _openSubmitDialog() async {
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => Popup(
        title: 'Ready to submit?',
        description:
            'Make sure you review all details before clicking on the Submit button. Click on the Cancel button to go back to the previous page.',
        actions: [
          DigitButton(
            label: 'Submit',
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          DigitButton(
            label: 'Cancel',
            type: DigitButtonType.tertiary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );

    if (submit == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BednetSuccessPage(
            eToken: widget.eToken,
            itnForDelivery: widget.itnForDelivery,
          ),
        ),
        (route) => route.isFirst,
      );
    }
  }
}
