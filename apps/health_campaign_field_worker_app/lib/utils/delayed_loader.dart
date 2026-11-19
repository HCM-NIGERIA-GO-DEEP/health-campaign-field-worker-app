import 'dart:async';

import 'package:digit_ui_components/widgets/atoms/digit_loader.dart';
import 'package:flutter/material.dart';

/// Shows a loader dialog on [context] and returns a future that completes
/// when the dialog is closed.
typedef ShowLoader = Future<void> Function(BuildContext context);

Future<void> _overlayLoader(BuildContext context) =>
    DigitLoaders.overlayLoader(context: context);

/// Awaits [work] behind the overlay loader.
///
/// The loader only appears once [work] has taken longer than [delay], so work
/// that finishes at once (e.g. localization that is already loaded) does not
/// flash a loader. It is closed when [work] completes or fails.
Future<T> runWithDelayedLoader<T>(
  BuildContext context,
  Future<T> work, {
  Duration delay = const Duration(milliseconds: 300),
  ShowLoader showLoader = _overlayLoader,
}) async {
  NavigatorState? navigator;
  var loaderOpen = false;
  final timer = Timer(delay, () {
    if (!context.mounted) return;
    // Kept so the loader can still be closed if [context] is gone by then.
    navigator = Navigator.of(context, rootNavigator: true);
    loaderOpen = true;
    showLoader(context).whenComplete(() => loaderOpen = false);
  });
  try {
    return await work;
  } finally {
    timer.cancel();
    // Skipped when the loader was already closed (e.g. with the back
    // button): popping then would close the page underneath instead.
    final nav = navigator;
    if (loaderOpen && nav != null && nav.mounted) {
      loaderOpen = false;
      nav.pop();
    }
  }
}
