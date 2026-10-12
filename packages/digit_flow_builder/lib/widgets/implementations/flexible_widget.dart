import 'package:digit_flow_builder/layout_renderer.dart';
import 'package:digit_flow_builder/utils/flow_widget_state.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/widget_registry.dart';
import 'package:flutter/material.dart';

import '../../action_handler/action_config.dart';
import '../flow_widget_interface.dart';

/// Gives a child a flex factor without forcing it to fill the space.
///
/// The loose counterpart to `expanded`: the child takes only the width it
/// needs, up to what is available. Use this when a trailing widget should sit
/// beside its text rather than being pushed to the far edge -- `expanded`
/// stretches the text to the full width, stranding the trailing widget.
class FlexibleWidget implements FlowWidget {
  @override
  String get format => 'flexible';

  @override
  Widget build(
    Map<String, dynamic> json,
    BuildContext context,
    void Function(ActionConfig) onAction,
  ) {
    final flowState = WidgetStateContext.of(context);
    final crudCtx = CrudItemContext.of(context);
    final stateData = flowState.stateData;
    var childJson = json['child'];
    final processed = stateData != null
        ? preprocessConfigWithState(
            Map<String, dynamic>.from(childJson),
            stateData,
            listIndex: crudCtx?.listIndex,
            item: crudCtx?.item,
          )
        : Map<String, dynamic>.from(childJson);

    return Flexible(
      child: CrudItemContext(
        stateData: stateData,
        listIndex: crudCtx?.listIndex,
        item: crudCtx?.item,
        screenKey: crudCtx?.screenKey,
        compositeKey: flowState.compositeKey,
        child: LayoutMapper.map(processed, stateData, context, onAction,
            item: crudCtx?.item,
            listIndex: crudCtx?.listIndex,
            compositeKey: flowState.compositeKey),
      ),
    );
  }
}
