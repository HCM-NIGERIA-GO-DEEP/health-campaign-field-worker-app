import 'package:digit_ui_components/digit_components.dart';
import 'package:flutter/material.dart';

import '../../blocs/localization/app_localization.dart';

class EolinInfoMessageWidget extends StatelessWidget {

  const EolinInfoMessageWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Look up the localized string using the context
    final localizedMessage = AppLocalizations.of(context).translate('EOLIN_SCREEN_NETS_ALERT');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(spacer2),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 200, 76, 14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: spacer1),
          Expanded(
            child: Text(
              localizedMessage, // Use the localized variable here
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}