import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

class DigitComponentsUtils {
  static void hideDialog(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil(
      (route) => route is! PopupRoute,
    );
  }

  static void showDialog(
    BuildContext context,
    String? label,
    DialogType dialogType,
  ) {
    DigitSyncDialog.show(
      context,
      type: dialogType,
      label: label,
    );
  }
}

class DigitSyncDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    Key? key,
    bool barrierDismissible = false,
    required DialogType type,
    String? label,
    DigitDialogActions? primaryAction,
    DigitDialogActions? secondaryAction,
  }) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: const DigitColors().overLayColor.withOpacity(.70),
      builder: (context) => DigitSyncDialogContent(
          type: type,
          label: label,
          primaryAction: primaryAction,
          secondaryAction: secondaryAction),
    );
  }
}

class DigitSyncDialogContent extends StatefulWidget {
  final String? label;
  final DialogType type;

  final DigitDialogActions? primaryAction;
  final DigitDialogActions? secondaryAction;

  const DigitSyncDialogContent({
    super.key,
    this.label,
    required this.type,
    this.primaryAction,
    this.secondaryAction,
  });

  @override
  State<DigitSyncDialogContent> createState() => _DigitSyncDialogContentState();
}

class _DigitSyncDialogContentState extends State<DigitSyncDialogContent>
    with SingleTickerProviderStateMixin {
  /// Drives the in-progress icon. Without it the dialog shows a still
  /// `autorenew` glyph, which reads as an icon rather than as work in
  /// progress.
  static const Duration _spinDuration = Duration(milliseconds: 1200);

  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    if (widget.type == DialogType.inProgress) {
      _spin = AnimationController(vsync: this, duration: _spinDuration)
        ..repeat();
    }
  }

  @override
  void didUpdateWidget(DigitSyncDialogContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type == oldWidget.type) return;

    // The same dialog can be reused to report completion or failure, and a
    // finished state must not keep spinning.
    if (widget.type == DialogType.inProgress) {
      _spin ??= AnimationController(vsync: this, duration: _spinDuration)
        ..repeat();
    } else {
      _spin?.dispose();
      _spin = null;
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final type = widget.type;
    final primaryAction = widget.primaryAction;
    final secondaryAction = widget.secondaryAction;

    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    IconData icon;
    Color color;
    TextStyle? labelStyle;

    switch (type) {
      case DialogType.inProgress:
        icon = Icons.autorenew;
        color = theme.colorTheme.primary.primary1;
        labelStyle = textTheme.headingM;
        break;
      case DialogType.complete:
        icon = Icons.check_circle_outline;
        color = theme.colorTheme.alert.success;
        labelStyle = textTheme.headingM;
        break;
      case DialogType.failed:
        icon = Icons.error_outline;
        color = theme.colorTheme.alert.error;
        labelStyle = textTheme.headingM;
        break;
    }

    return Dialog.fullscreen(
      backgroundColor: const DigitColors().transparent,
      child: Center(
        child: Container(
            padding: const EdgeInsets.all(spacer4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius4),
              color: theme.colorTheme.paper.primary,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withOpacity(.16),
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                  blurRadius: 2,
                ),
              ],
            ),
            width: 300,
            constraints: const BoxConstraints(minHeight: 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _spin == null
                    ? Icon(icon, size: 32, color: color)
                    : RotationTransition(
                        turns: _spin!,
                        child: Icon(icon, size: 32, color: color),
                      ),
                if (label != null && label != "") ...[
                  const SizedBox(height: spacer4),
                  Text(
                    label,
                    // The icon above is centred, so a label that wraps has to
                    // be centred too or the two visibly disagree.
                    textAlign: TextAlign.center,
                    style: labelStyle.copyWith(color: color),
                  ),
                ],
                if (primaryAction != null || secondaryAction != null) ...[
                  const SizedBox(height: spacer4),
                  if (secondaryAction != null)
                    DigitButton(
                      type: DigitButtonType.secondary,
                      size: DigitButtonSize.medium,
                      label: secondaryAction.label,
                      onPressed: () {
                        if (secondaryAction.action != null) {
                          secondaryAction.action!(context);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      mainAxisSize: MainAxisSize.max,
                    ),
                  if (primaryAction != null && secondaryAction != null)
                    const SizedBox(height: spacer4),
                  if (primaryAction != null)
                    DigitButton(
                      label: primaryAction.label,
                      onPressed: () {
                        if (primaryAction.action != null) {
                          primaryAction.action!(context);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      size: DigitButtonSize.medium,
                      type: DigitButtonType.primary,
                      mainAxisSize: MainAxisSize.max,
                    ),
                ],
              ],
            )),
      ),
    );
  }
}

enum DialogType { inProgress, complete, failed }

class DigitDialogActions<T> {
  final String label;
  final T Function(BuildContext context)? action;

  const DigitDialogActions({
    required this.label,
    this.action,
  });
}
