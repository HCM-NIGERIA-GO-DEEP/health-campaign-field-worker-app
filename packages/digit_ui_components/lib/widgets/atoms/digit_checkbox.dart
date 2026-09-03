/// `DigitCheckbox` is a DigitCheckbox component with a label and optional icon customization.

/// This widget allows the user to toggle between checked and unchecked states. It supports
/// customization of the DigitCheckbox icon color, label, and disabled state.

/// Example usage:
/// ```dart
/// DigitCheckbox(
///   label: 'DigitCheckbox label',
///   onChanged: (value) {
///     // Handle DigitCheckbox state change
///     print('Feature X is now ${value ? 'enabled' : 'disabled'}');
///   },
///   disabled: false, // Set to true to disable the DigitCheckbox
///   value: true, // Set the initial state of the DigitCheckbox
///   padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0), // Customize padding
///   iconColor: Colors.blue, // Customize DigitCheckbox icon color
/// )

import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/ComponentTheme/checkbox_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

import '../../utils/utils.dart';

class DigitCheckbox extends StatefulWidget {
  /// The current value of the DigitCheckbox.
  final bool value;

  /// The label associated with the DigitCheckbox.
  final String? label;

  /// Callback function triggered when the DigitCheckbox value changes.
  final ValueChanged<bool> onChanged;

  /// Indicates whether the DigitCheckbox is disabled or not.
  final bool isDisabled;
  final bool alignRight;

  /// Indicates whether the DigitCheckbox is disabled or not.
  final bool readOnly;

  final bool capitalizeFirstLetter;

  final DigitCheckboxThemeData? checkboxThemeData;

  final bool isRequired;

  /// Optional stable accessibility identifier for the tappable box (surfaces as
  /// the Android `resource-id`).
  ///
  /// The box and its label are SIBLINGS, so the tappable node carries no label
  /// of its own — without this it is an anonymous node that accessibility-tree
  /// drivers (Maestro, TalkBack) can only reach by screen coordinates. Same
  /// shape as [RadioList]; see its `semanticsIdentifierPrefix`.
  ///
  /// Null leaves the box unannotated, i.e. the previous behaviour.
  final String? semanticsIdentifier;

  /// Creates a `DigitCheckbox` widget with the given parameters.
  const DigitCheckbox({
    Key? key,
    this.label,
    required this.onChanged,
    this.readOnly = false,
    this.isDisabled = false,
    this.value = false,
    this.alignRight = false,
    this.capitalizeFirstLetter = true,
    this.checkboxThemeData,
    this.isRequired = false,
    this.semanticsIdentifier,
  }) : super(key: key);

  @override
  _DigitCheckboxState createState() => _DigitCheckboxState();
}

class _DigitCheckboxState extends State<DigitCheckbox> {
  late bool _currentState;
  bool isHovered = false;
  bool isFocused = false;

  /// Annotates the tappable box with [DigitCheckbox.semanticsIdentifier] when
  /// the caller supplied one; returns [child] untouched otherwise, so existing
  /// call sites keep their semantics tree.
  Widget _withCheckboxSemantics(Widget child) {
    final identifier = widget.semanticsIdentifier;
    if (identifier == null || identifier.isEmpty) return child;

    // container: true is load-bearing. A single checkbox under the forms
    // engine's field-level Semantics(identifier: formControlName) otherwise
    // merges into ONE node that spans the whole field block: the field id
    // wins, this id is dropped, and although the merged node reports
    // tap=true its centre sits on the LABEL, so tapping it never toggles the
    // box. Forcing our own node keeps the id on the box's own rect.
    // (RadioList needs no such flag - two option nodes stop the ancestor
    // annotation from collapsing into a single child.)
    return Semantics(
      identifier: identifier,
      container: true,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentState = widget.value;
  }

  @override
  void didUpdateWidget(DigitCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the value has changed
    if (widget.value != oldWidget.value) {
      setState(() {
        _currentState = widget.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final checkboxThemeData =
        widget.checkboxThemeData ?? theme.extension<DigitCheckboxThemeData>();
    final defaultThemeData = DigitCheckboxThemeData.defaultTheme(context);

    bool isMobile = AppView.isMobileView(MediaQuery.of(context).size);

    /// Capitalize the first letter of the label if required
    final processedLabel = widget.capitalizeFirstLetter
        ? convertInToSentenceCase(widget.label)
        : widget.label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: widget.alignRight
          ? TextDirection.rtl
          : checkboxThemeData?.labelTextDirection ??
              defaultThemeData.labelTextDirection,
      children: [
        Column(
          children: [
            SizedBox(
              height: isMobile ? 0 : 2,
            ),
            // Stable resource-id on the tappable box. Its label is a sibling
            // node, so without this the box is anonymous to accessibility-tree
            // drivers (same trap RadioList hit in run -1214).
            _withCheckboxSemantics(InkWell(
              hoverColor: theme.colorTheme.generic.transparent,
              splashColor: theme.colorTheme.generic.transparent,
              highlightColor: theme.colorTheme.generic.transparent,
              focusColor: theme.colorTheme.generic.transparent,
              onFocusChange: (value) {
                setState(() {
                  isFocused = value;
                });
              },
              onHover: (hover) {
                setState(() {
                  isHovered = hover;
                });
              },
              onTap: widget.isDisabled || widget.readOnly
                  ? null
                  : () {
                      if (mounted) {
                        setState(() {
                          _currentState = !_currentState;
                        });
                        widget.onChanged(_currentState);
                      }
                    },
              child: DigitCheckboxIcon(
                state: _currentState
                    ? DigitCheckboxState.checked
                    : DigitCheckboxState.unchecked,
                isDisabled: widget.isDisabled || widget.readOnly,
                checkboxThemeData: widget.checkboxThemeData ?? defaultThemeData,
              ),
            )),
          ],
        ),
        if (widget.label != null) ...[
          const SizedBox(width: spacer4),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _parseLabelText(
                  processedLabel ?? '',
                  widget.isDisabled
                      ? checkboxThemeData?.disabledLabelTextStyle ??
                          defaultThemeData.disabledLabelTextStyle
                      : checkboxThemeData?.labelTextStyle ??
                          defaultThemeData.labelTextStyle,
                  widget.isDisabled
                      ? (checkboxThemeData?.disabledLabelTextStyle ??
                              defaultThemeData.disabledLabelTextStyle)
                          ?.copyWith(fontWeight: FontWeight.bold)
                      : (checkboxThemeData?.labelTextStyle ??
                              defaultThemeData.labelTextStyle)
                          ?.copyWith(fontWeight: FontWeight.bold),
                  theme.colorTheme.alert.error,
                  widget.isRequired,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<TextSpan> _parseLabelText(
    String text,
    TextStyle? normalStyle,
    TextStyle? boldStyle,
    Color requiredColor,
    bool isRequired,
  ) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*'); // match **bold text**
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Add normal text before **
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: normalStyle,
        ));
      }

      // Add bold text inside **
      spans.add(TextSpan(
        text: match.group(1),
        style: boldStyle,
      ));

      lastIndex = match.end;
    }

    // Add any remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: normalStyle,
      ));
    }

    // Add red asterisk if required
    if (isRequired) {
      spans.add(TextSpan(
        text: ' *',
        style: TextStyle(color: requiredColor),
      ));
    }

    return spans;
  }
}
