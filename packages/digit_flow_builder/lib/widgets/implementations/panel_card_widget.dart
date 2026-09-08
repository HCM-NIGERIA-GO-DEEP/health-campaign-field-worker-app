import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../../blocs/flow_crud_bloc.dart';
import '../../utils/semantics_identifier.dart';
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
        ? FlowCrudStateRegistry()
            .getNavigationParams(resolved.compositeKey!)
        : null;

    final evalContext = {
      ...resolved.evalContext,
      if (navigationData != null) 'navigation': navigationData,
    };

    final localization = LocalizationContext.maybeOf(context);

    // Label/description need navigation context, so resolve with enriched evalContext
    final label = resolveTemplate(json['label'] ?? '', evalContext,
        localization: localization, screenKey: resolved.screenKey,
        stateData: resolved.stateData);
    final description = resolveTemplate(json['description'] ?? '', evalContext,
        localization: localization, screenKey: resolved.screenKey,
        stateData: resolved.stateData);

    Map<String, dynamic>? primaryAction = json['primaryAction'];
    Map<String, dynamic>? secondaryAction = json['secondaryAction'];

    // Stable identifiers for the two action buttons, same derivation as
    // FlowWidgetFactory.build() uses for top-level widgets - but these are
    // nested inside primaryAction/secondaryAction sub-configs and built
    // directly below (not routed back through the factory), so they were
    // never getting one at all (viewHouseholdButton stayed resource-id-less
    // no matter how long a UI test waited - run -2244).
    final stateKey = resolved.compositeKey ?? resolved.screenKey;
    final primaryActionId = primaryAction != null
        ? semanticsIdentifierFor(primaryAction, stateKey)
        : null;
    final secondaryActionId = secondaryAction != null
        ? semanticsIdentifierFor(secondaryAction, stateKey)
        : null;

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
    final additionalWidgetsConfig =
        json['additionalWidgets'] as List<dynamic>?;
    List<Widget>? additionalWidgets;

    if (additionalWidgetsConfig != null &&
        additionalWidgetsConfig.isNotEmpty) {
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
            label: localization?.translate(primaryAction['label'] ?? '') ??
                (primaryAction['label'] ?? ''),
            onPressed: () => handleAction(json['primaryAction']),
            semanticsIdentifier: primaryActionId,
          ),
        if (secondaryAction != null)
          DigitButton(
            type: DigitButtonType.secondary,
            size: DigitButtonSize.large,
            label:
                localization?.translate(secondaryAction['label'] ?? '') ??
                    (secondaryAction['label'] ?? ''),
            onPressed: () => handleAction(json['secondaryAction']),
            semanticsIdentifier: secondaryActionId,
          ),
      ],
    );
  }
}
