import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';

import '../../router/app_router.dart';
import '../../widgets/header/back_navigation_help_header.dart';

@RoutePage()
class BednetDistributionSuccessPage extends StatelessWidget {
  const BednetDistributionSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              label: 'Go to Home',
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              onPressed: () {
                context.router.replaceAll([HomeRoute()]);
              },
            ),
          ],
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(spacer4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorTheme.alert.success,
                      size: spacer10,
                    ),
                    const SizedBox(height: spacer3),
                    Text(
                      'School selection completed successfully.',
                      textAlign: TextAlign.center,
                      style: textTheme.headingL
                          .copyWith(color: theme.colorTheme.primary.primary2),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
