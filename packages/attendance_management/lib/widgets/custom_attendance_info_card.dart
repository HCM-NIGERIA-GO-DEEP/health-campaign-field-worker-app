import 'package:attendance_management/blocs/app_localization.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/ComponentTheme/button_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

import '../../utils/i18_key_constants.dart' as i18;

/// A single face-auth event dot shown on the attendance card.
class FaceEventDot {
  final Color color;

  /// Confidence in [0, 1]. 0 means no face scan (PIN fallback, missed, etc.).
  final double confidence;

  /// Short label shown below the dot, e.g. "PIN", "–", or "" for face events.
  final String label;

  /// Abbreviated event type shown below the confidence/label, e.g. "CI", "RV".
  final String eventType;

  const FaceEventDot({
    required this.color,
    required this.confidence,
    this.label = '',
    this.eventType = '',
  });
}

class CustomAttendanceInfoCard extends StatelessWidget {
  final String name;
  final String individualNumber;
  final double? status;
  final VoidCallback onMarkPresent;
  final VoidCallback onMarkAbsent;
  final bool markManualAttendance;
  final bool viewOnly;
  final bool isCurrentDate;

  /// Dots representing face auth events for this individual on the selected
  /// day. Each dot carries a color and optional confidence percentage.
  final List<FaceEventDot>? faceEventDots;

  const CustomAttendanceInfoCard(
      {super.key,
      required this.name,
      required this.individualNumber,
      required this.status,
      required this.onMarkPresent,
      required this.onMarkAbsent,
      required this.markManualAttendance,
      required this.viewOnly,
      required this.isCurrentDate,
      this.faceEventDots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    var localizations = AttendanceLocalization.of(context);

    String getStatusText() {
      if (status == 1) {
        return localizations.translate(i18.attendance.markedAsPresent);
      }
      if (status == 0) {
        return localizations.translate(i18.attendance.markedAsAbsent);
      }
      return localizations.translate(i18.attendance.attendanceUnMarked);
    }

    Color? getStatusColor() {
      if (status == 1) return theme.colorTheme.alert.success;
      if (status == 0) return theme.colorTheme.alert.error;
      return null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: spacer4),
      padding: const EdgeInsets.all(spacer3),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(),
        color: const DigitColors().light.paperSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: textTheme.captionS),
              if (faceEventDots != null && faceEventDots!.isNotEmpty) ...[
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: faceEventDots!
                        .map((dot) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: dot.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dot.confidence > 0
                                        ? '${(dot.confidence * 100).round()}%'
                                        : dot.label,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                  if (dot.eventType.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Icon(
                                      _eventTypeIcon(dot.eventType),
                                      size: 9,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: spacer1),
          if (viewOnly || markManualAttendance || status != null) ...[
            Text(
              getStatusText(),
              style: textTheme.bodyS.copyWith(
                color: getStatusColor() ?? theme.colorTheme.alert.warning,
              ),
            ),
            const SizedBox(height: spacer2),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: spacer1, vertical: spacer1),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(spacer1)),
              border: Border(
                  left: BorderSide(color: theme.colorTheme.generic.divider),
                  right: BorderSide(color: theme.colorTheme.generic.divider),
                  bottom: BorderSide(color: theme.colorTheme.generic.divider),
                  top: BorderSide(color: theme.colorTheme.generic.divider)),
              color: theme.colorTheme.paper.secondary,
            ),
            child: Center(
              child: Text(individualNumber,
                  style: textTheme.headingXS
                      .copyWith(color: theme.colorTheme.primary.primary2)),
            ),
          ),
          const SizedBox(height: spacer4),
          Row(
            children: [
              if (!viewOnly && markManualAttendance)
                Expanded(
                  child: DigitButton(
                    prefixIcon: Icons.check,
                    label: localizations.translate(i18.attendance.present),
                    capitalizeLetters: true,
                    textColor: status == 1
                        ? theme.colorTheme.paper.primary
                        : theme.colorTheme.alert.success,
                    iconColor: status == 1
                        ? theme.colorTheme.paper.primary
                        : theme.colorTheme.alert.success,
                    isDisabled: false,
                    onPressed: onMarkPresent,
                    type: status == 1
                        ? DigitButtonType.primary
                        : DigitButtonType.secondary,
                    size: DigitButtonSize.small,
                    digitButtonThemeData: DigitButtonThemeData(
                      DigitButtonColor: theme.colorTheme.alert.success,
                      disabledColor:
                          theme.colorTheme.alert.success.withOpacity(0.4),
                      borderWidth: 1.2,
                      radius: BorderRadius.circular(spacer1),
                      padding: const EdgeInsets.all(spacer3),
                    ),
                  ),
                ),
              if (!viewOnly && markManualAttendance)
                const SizedBox(width: spacer3),
              if (!viewOnly && markManualAttendance)
                Expanded(
                  child: DigitButton(
                    prefixIcon: Icons.cancel,
                    label: localizations.translate(i18.attendance.absent),
                    capitalizeLetters: true,
                    textColor: status == 0
                        ? theme.colorTheme.paper.primary
                        : theme.colorTheme.alert.error,
                    iconColor: status == 0
                        ? theme.colorTheme.paper.primary
                        : theme.colorTheme.alert.error,
                    isDisabled: false,
                    onPressed: onMarkAbsent,
                    type: status == 0
                        ? DigitButtonType.primary
                        : DigitButtonType.secondary,
                    size: DigitButtonSize.small,
                    digitButtonThemeData: DigitButtonThemeData(
                      DigitButtonColor: theme.colorTheme.alert.error,
                      disabledColor:
                          theme.colorTheme.alert.error.withOpacity(0.4),
                      radius: BorderRadius.circular(spacer1),
                      padding: const EdgeInsets.all(spacer3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: spacer2),
        ],
      ),
    );
  }

  static IconData _eventTypeIcon(String eventType) {
    switch (eventType) {
      case 'EN':  return Icons.how_to_reg;
      case 'L':   return Icons.login;
      case 'RV':  return Icons.face_retouching_natural;
      case 'CI':  return Icons.check_circle_outline;
      default:    return Icons.radio_button_unchecked;
    }
  }
}

/// Compact legend card that explains face-event dot colors and event-type icons.
/// Place it once above the attendee list whenever face event dots are visible.
class FaceEventLegend extends StatelessWidget {
  const FaceEventLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    var localizations = AttendanceLocalization.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: spacer3),
      padding: const EdgeInsets.symmetric(horizontal: spacer3, vertical: spacer2),
      decoration: BoxDecoration(
        color: theme.colorTheme.paper.secondary,
        borderRadius: BorderRadius.circular(spacer1),
        border: Border.all(color: theme.colorTheme.generic.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: theme.colorTheme.text.secondary),
              const SizedBox(width: 4),
              Text(
                localizations.translate(i18.attendance.faceEventLegendTitle),
                style: textTheme.bodyXS.copyWith(
                  color: theme.colorTheme.text.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: spacer2),
          Wrap(
            spacing: spacer4,
            runSpacing: spacer1,
            children: [
              _dotLegend(Colors.green, localizations.translate(i18.attendance.faceEventFaceVerified)),
              _dotLegend(Colors.orange, localizations.translate(i18.attendance.faceEventPinUsed)),
              _dotLegend(Colors.red, localizations.translate(i18.attendance.faceEventMissedRejected)),
            ],
          ),
          const SizedBox(height: spacer2),
          Wrap(
            spacing: spacer4,
            runSpacing: spacer1,
            children: [
              _iconLegend(Icons.how_to_reg,             localizations.translate(i18.attendance.faceEventEnrollment)),
              _iconLegend(Icons.login,                  localizations.translate(i18.attendance.faceEventLogin)),
              _iconLegend(Icons.check_circle_outline,   localizations.translate(i18.attendance.faceEventCheckIn)),
              _iconLegend(Icons.face_retouching_natural,localizations.translate(i18.attendance.faceEventReVerify)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dotLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _iconLegend(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.black54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
