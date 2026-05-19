import 'package:flutter/material.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/widgets/resolved_flow_widget.dart';

class CustomMessageWidget extends ResolvedFlowWidget {
  // Fix: Removed 'const' and changed 'super.key' to a normal non-const declaration
  CustomMessageWidget();

  @override
  String get format => 'customMessageBanner';

  @override
  Widget buildResolved(
    Map<String, dynamic> json,
    BuildContext context,
    void Function(ActionConfig) onAction,
    ResolvedWidgetContext resolved,
  ) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final value = json['value']?.toString() ?? '';
    final replaceAll = properties['replaceAll'] as List?;

    var resolvedValue = resolved.resolveText(value);

    if (replaceAll != null) {
      for (var replacement in replaceAll) {
        if (replacement is Map<String, dynamic>) {
          final searchValue = replacement['searchValue']?.toString() ?? '';
          final rawReplaceValue = replacement['replaceValue']?.toString() ?? '';
          final replaceValue = resolved.resolveText(rawReplaceValue);
          resolvedValue = resolvedValue.replaceAll(searchValue, replaceValue);
        }
      }
    }

    return Container(
      width: double.infinity,
      color: const Color.fromARGB(255, 200, 76, 14),
      padding: const EdgeInsets.all(16),
      child: Text(
        resolvedValue.isEmpty 
            ? 'Ensure that Bednets are given and proper Health Talk is provided!' 
            : resolvedValue,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}