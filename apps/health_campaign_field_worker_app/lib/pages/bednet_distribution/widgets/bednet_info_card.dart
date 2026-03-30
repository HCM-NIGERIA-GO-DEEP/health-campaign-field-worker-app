import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';

class BednetInfoCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> items;
  final bool showDivider;

  const BednetInfoCard({
    super.key,
    required this.title,
    required this.items,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return DigitCard(
      margin: const EdgeInsets.all(spacer2),
      children: [
        Text(
          title,
          style: textTheme.headingXl
              .copyWith(color: theme.colorTheme.primary.primary2),
        ),
        const SizedBox(height: spacer2),
        ...items.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: spacer2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: textTheme.headingM
                        .copyWith(color: theme.colorTheme.text.primary),
                  ),
                ),
                const SizedBox(width: spacer2),
                Expanded(
                  child: Text(
                    entry.value,
                    style: textTheme.bodyS
                        .copyWith(color: theme.colorTheme.text.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: spacer4),
      ],
    );
  }
}
