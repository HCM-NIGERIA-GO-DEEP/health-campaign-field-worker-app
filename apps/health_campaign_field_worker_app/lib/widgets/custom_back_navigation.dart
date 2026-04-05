import 'package:flutter/material.dart';

import 'header/back_navigation_help_header.dart';

/// Thin wrapper so bednet / registration pages share the app header API.
class CustomBackNavigationHelpHeaderWidget extends StatelessWidget {
  const CustomBackNavigationHelpHeaderWidget({
    super.key,
    this.showHelp = true,
    this.handleback,
  });

  final bool showHelp;
  final VoidCallback? handleback;

  @override
  Widget build(BuildContext context) {
    return BackNavigationHelpHeaderWidget(
      showHelp: showHelp,
      handleback: handleback,
    );
  }
}
