import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../../blocs/flow_crud_bloc.dart';
import '../../utils/utils.dart';
import '../../widget_registry.dart';
import '../localization_context.dart';
import '../resolved_flow_widget.dart';

class PanelCardWidget extends ResolvedFlowWidget {
  @override
  String get format => 'panelCard';

  @override
  Widget buildResolved(
    Map<String, dynamic> json,
    BuildContext context,
    void Function(ActionConfig) onAction,
    ResolvedWidgetContext resolved,
  ) {
    // Enrich evalContext with navigation params
    final navigationData = resolved.compositeKey != null
        ? FlowCrudStateRegistry().getNavigationParams(resolved.compositeKey!)
        : null;

    final evalContext = {
      ...resolved.evalContext,
      if (navigationData != null) 'navigation': navigationData,
    };

    final localization = LocalizationContext.maybeOf(context);

    // Label/description need navigation context, so resolve with enriched evalContext
    final label = resolveTemplate(json['label'] ?? '', evalContext,
        localization: localization,
        screenKey: resolved.screenKey,
        stateData: resolved.stateData);
    final description = resolveTemplate(json['description'] ?? '', evalContext,
        localization: localization,
        screenKey: resolved.screenKey,
        stateData: resolved.stateData);

    Map<String, dynamic>? primaryAction = json['primaryAction'];
    Map<String, dynamic>? secondaryAction = json['secondaryAction'];

    void handleAction(Map<String, dynamic>? actionJson) {
      if (actionJson == null) return;

      final actionsList = actionJson['onAction'];

      for (var actionMap in actionsList) {
        final action = resolved.resolveAction(
          actionMap,
          evalContext,
        );
        onAction(action);
      }
    }

    // Build additional widgets if provided
    final additionalWidgetsConfig = json['additionalWidgets'] as List<dynamic>?;
    List<Widget>? additionalWidgets;

    if (additionalWidgetsConfig != null && additionalWidgetsConfig.isNotEmpty) {
      final widgets = <Widget>[];
      try {
        for (var widgetJson in additionalWidgetsConfig) {
          if (widgetJson is Map<String, dynamic>) {
            final widget = WidgetRegistry.build(
              widgetJson,
              context,
              onAction,
            );
            widgets.add(widget);
          }
        }
        if (widgets.isNotEmpty) {
          additionalWidgets = widgets;
        }
      } catch (e, stackTrace) {
        debugPrint('Error building additionalWidgets: $e');
        debugPrint('StackTrace: $stackTrace');
        additionalWidgets = null;
      }
    }

    return PanelCard(
      title: label,
      type: PanelType.success,
      description: description,
      additionWidgets: additionalWidgets,
      actions: [
        if (primaryAction != null)
          DigitButton(
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
            label: _resolveActionLabel(
                primaryAction!['label'] ?? '',
                evalContext,
                localization,
                resolved.screenKey,
                resolved.stateData,
                primaryAction['useCustomLabel'] == true),
            onPressed: () => handleAction(json['primaryAction']),
          ),
        if (secondaryAction != null)
          DigitButton(
            type: DigitButtonType.secondary,
            size: DigitButtonSize.large,
            label: _resolveActionLabel(
                secondaryAction!['label'] ?? '',
                evalContext,
                localization,
                resolved.screenKey,
                resolved.stateData,
                secondaryAction['useCustomLabel'] == true),
            onPressed: () => handleAction(json['secondaryAction']),
          ),
      ],
    );
  }

  String _resolveActionLabel(
    String label,
    Map<String, dynamic> evalContext,
    dynamic localization,
    String? screenKey,
    dynamic stateData,
    bool useCustomLabel,
  ) {
    // If useCustomLabel is false, use original behavior - direct translation without resolveTemplate
    if (!useCustomLabel) {
      if (localization != null) {
        return localization.translate(label) ?? label;
      }
      return label;
    }

    // Custom handling for ternary operators with navigation
    final ternaryPattern = RegExp(r'(.+?)\s*\?\s*(.+?)\s*:\s*(.+)');
    final match = ternaryPattern.firstMatch(label);

    if (match != null) {
      final condition = match.group(1)!.trim();
      final trueValue = match.group(2)!.trim();
      final falseValue = match.group(3)!.trim();

      // Check if condition is a navigation reference
      if (condition.startsWith('navigation.')) {
        final navKey = condition.substring('navigation.'.length);
        final navigationData =
            evalContext['navigation'] as Map<String, dynamic>?;
        final navValue = navigationData?[navKey];

        if (navValue != null &&
            navValue.toString().isNotEmpty &&
            navValue.toString().toLowerCase() == 'true') {
          // Navigation value is true, check if trueValue is a navigation reference or simple string
          if (trueValue.startsWith('navigation.')) {
            final trueKey = trueValue.substring('navigation.'.length);
            return _translateWithLocalization(
                navigationData?[trueKey], localization);
          } else {
            // trueValue is a simple string, use it directly
            return _translateWithLocalization(trueValue, localization);
          }
        } else {
          if (falseValue.startsWith('navigation.')) {
            final falseKey = falseValue.substring('navigation.'.length);
            return _translateWithLocalization(
                navigationData?[falseKey], localization);
          } else {
            // falseValue is a simple string, use it directly
            return _translateWithLocalization(falseValue, localization);
          }
        }
      }
    }

    // Fallback to standard resolution
    final resolved = resolveTemplate(label, evalContext,
        localization: localization, screenKey: screenKey, stateData: stateData);
    if (localization != null) {
      return _translateWithLocalization(resolved, localization);
    }
    return resolved;
  }

  String _translateWithLocalization(String key, dynamic localization) {
    try {
      return localization.translate(key) ?? key;
    } catch (e) {
      return key;
    }
  }
}
