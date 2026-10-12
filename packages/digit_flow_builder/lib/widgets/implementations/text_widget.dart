import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../../utils/widget_parsers.dart';
import '../resolved_flow_widget.dart';

class TextWidget extends ResolvedFlowWidget {
  @override
  String get format =>
      'textTemplate'; // add support to take multiple format types

  @override
  Widget buildResolved(
    Map<String, dynamic> json,
    BuildContext context,
    void Function(ActionConfig) onAction,
    ResolvedWidgetContext resolved,
  ) {
    // Use the pre-resolved label, or resolve 'value' field as fallback
    final value = json['value'] ?? '';

    // Get style from properties
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final styleKey = properties['style']?.toString();
    final separatedBy = properties['separatedBy'];
    final replaceAll = properties['replaceAll'] as List?;
    final textStyle = _parseTextStyle(context, styleKey);

    var preResolvedValue = resolved.resolveText(value);
    var resolvedValue = (separatedBy != null)
        ? preResolvedValue
            .split(separatedBy)
            .map((part) => resolved.resolveText(part.trim()))
            .join(separatedBy)
        : preResolvedValue;

    if (replaceAll != null) {
      for (var replacement in replaceAll) {
        final searchValue = replacement['searchValue']?.toString() ?? '';
        final replaceValue = replacement['replaceValue']?.toString() ?? '';
        resolvedValue = resolvedValue.replaceAll(searchValue, replaceValue);
      }
    }

    final displayValue = (resolvedValue)
        .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '--');

    final text = displayValue.isEmpty ? '--' : displayValue;
    final style = textStyle?.copyWith(
      color: _parseTextColor(context, properties['color']?.toString()),
    );
    final maxLines = json["maxLines"] ?? 2;

    // Selectable text cannot ellipsize, so it wraps to maxLines instead. Opt
    // in per widget for values a user may want to lift out, e.g. an ID.
    final selectable = properties['selectable'] == true;

    return WidgetParsers.wrapWithBottomGap(
      selectable
          ? SelectableText(
              text,
              style: style,
              // Only when the config asks for it: SelectableText *reserves*
              // maxLines of height rather than treating it as a ceiling, so
              // the default of 2 leaves a single line sitting in a
              // double-height box and drags anything centred beside it low.
              maxLines: json['maxLines'] as int?,
            )
          : Text(
              text,
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: maxLines,
            ),
      properties,
    );
  }

  Color? _parseTextColor(BuildContext context, String? colorKey) {
    if (colorKey == null) return null;

    final theme = Theme.of(context);
    switch (colorKey) {
      case 'primary':
        return theme.colorScheme.primary;
      case 'onPrimary':
        return theme.colorScheme.onPrimary;
      case 'secondary':
        return theme.colorScheme.secondary;
      case 'onSecondary':
        return theme.colorScheme.onSecondary;
      case 'error':
        return theme.colorScheme.error;
      case 'onError':
        return theme.colorScheme.onError;
      case 'surface':
        return theme.colorScheme.surface;
      case 'onSurface':
        return theme.colorScheme.onSurface;
      default:
        return null; // Could add support for custom colors here
    }
  }

  TextStyle? _parseTextStyle(BuildContext context, String? styleKey) {
    if (styleKey == null) return null;

    final digitTextTheme = Theme.of(context).digitTextTheme(context);

    switch (styleKey) {
      // Heading styles
      case 'headingXl':
        return digitTextTheme.headingXl;
      case 'headingL':
        return digitTextTheme.headingL;
      case 'headingM':
        return digitTextTheme.headingM;
      case 'headingS':
        return digitTextTheme.headingS;
      // Body styles
      case 'bodyL':
        return digitTextTheme.bodyL;
      case 'bodyS':
        return digitTextTheme.bodyS;
      // Caption styles
      case 'captionL':
        return digitTextTheme.captionL;
      case 'captionS':
        return digitTextTheme.captionS;
      // Label style
      case 'label':
        return digitTextTheme.label;
      default:
        return null;
    }
  }
}
