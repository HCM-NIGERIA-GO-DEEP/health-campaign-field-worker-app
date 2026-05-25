import 'package:digit_ui_components/constants/icon_mapping.dart';
import 'package:digit_ui_components/widgets/atoms/menu_card.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../../utils/conditional_evaluator.dart';
import '../localization_context.dart';
import '../resolved_flow_widget.dart';

class MenuCardWidget extends ResolvedFlowWidget {
  @override
  String get format => 'menu_card';

  @override
  Widget buildResolved(
    Map<String, dynamic> json,
    BuildContext context,
    void Function(ActionConfig) onAction,
    ResolvedWidgetContext resolved,
  ) {
    return MenuCard(
      onTap: () {
        if (json['onAction'] != null) {
          final actionsList = List<Map<String, dynamic>>.from(json['onAction']);
          final currentEvalContext = resolved.getFreshEvalContext();

          for (var actionJson in actionsList) {
            // Check if this is a conditional action block
            if (actionJson.containsKey('condition')) {
              final condition =
                  actionJson['condition'] as Map<String, dynamic>?;
              final expression = condition?['expression'] as String?;

              // Evaluate condition
              bool conditionMet = false;
              if (expression == null || expression == 'DEFAULT') {
                conditionMet = true;
              } else {
                conditionMet = ConditionalEvaluator.evaluateExpression(
                  expression,
                  currentEvalContext,
                );
              }

              if (conditionMet) {
                // Execute actions in this conditional block
                final subActions =
                    actionJson['actions'] as List<dynamic>? ?? [];
                for (var subActionJson in subActions) {
                  final action = resolved.resolveAction(
                    subActionJson as Map<String, dynamic>,
                    currentEvalContext,
                  );
                  onAction(action);
                }
                // Only execute first matching condition block
                break;
              }
            } else {
              // Legacy direct action (no condition)
              final action =
                  resolved.resolveAction(actionJson, currentEvalContext);
              onAction(action);
            }
          }
        }
      },
      heading: _localizeText(context, json['heading']) ?? "",
      description: _localizeText(context, json['description']),
      icon: DigitIconMapping.getIcon(json['icon']),
      textColor:
          json['textColor'] != null ? _parseColor(json['textColor']) : null,
      iconColor:
          json['iconColor'] != null ? _parseColor(json['iconColor']) : null,
    );
  }

  String? _localizeText(BuildContext context, String? text) {
    if (text == null) return null;
    final localization = LocalizationContext.maybeOf(context);
    return localization?.translate(text) ?? text;
  }

  Color? _parseColor(dynamic colorValue) {
    if (colorValue == null) return null;
    final colorString = colorValue.toString().toLowerCase();
    switch (colorString) {
      case 'red':
        return Colors.red;
      case 'redorange':
        return const Color.fromARGB(255, 200, 76, 14);
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return null;
    }
  }
}
