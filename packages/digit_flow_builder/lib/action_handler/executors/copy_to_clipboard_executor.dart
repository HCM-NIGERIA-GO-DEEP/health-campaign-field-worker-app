import 'package:digit_ui_components/enum/app_enums.dart';
import 'package:digit_ui_components/widgets/atoms/digit_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/interpolation.dart';
import '../../widget_registry.dart';
import '../../widgets/localization_context.dart';
import '../action_config.dart';
import 'action_executor.dart';

/// Executor for COPY_TO_CLIPBOARD action.
///
/// Puts a resolved value on the clipboard so config-driven screens can offer a
/// copy affordance, e.g. an `iconButton` beside a beneficiary ID.
///
/// ```json
/// {
///   "actionType": "COPY_TO_CLIPBOARD",
///   "properties": {
///     "value": "{{item.beneficiaryId}}",
///     "successMessage": "DEDUP_SIMILAR_BENEFICIARY_COPIED"
///   }
/// }
/// ```
///
/// Resolves its own `{{...}}` template against the surrounding
/// [CrudItemContext]. It has to: `preprocessConfigWithState` deliberately
/// leaves `onAction` blocks untouched so they evaluate lazily on tap, so a
/// template like `{{item.beneficiaryId}}` is still literal by the time it
/// arrives here. A value that cannot be resolved is a no-op rather than
/// putting `{{item.beneficiaryId}}` on the user's clipboard.
class CopyToClipboardExecutor extends ActionExecutor {
  @override
  bool canHandle(String actionType) => actionType == 'COPY_TO_CLIPBOARD';

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    var value = action.properties['value']?.toString().trim() ?? '';

    if (value.contains('{{')) {
      value = _resolve(value, context).trim();
    }

    if (value.isEmpty || value.contains('{{')) {
      debugPrint('COPY_TO_CLIPBOARD: nothing to copy (value="$value")');
      return contextData;
    }

    await Clipboard.setData(ClipboardData(text: value));

    final successMessage = action.properties['successMessage'] as String?;
    if (successMessage == null || successMessage.isEmpty) return contextData;
    if (!context.mounted) return contextData;

    final localization = LocalizationContext.maybeOf(context);
    Toast.showToast(
      context,
      message: localization?.translate(successMessage) ?? successMessage,
      type: ToastType.success,
    );

    return contextData;
  }

  /// Interpolates [template] against the item and state the invoking widget
  /// sits in, e.g. the row of a `listView`.
  String _resolve(String template, BuildContext context) {
    final crudCtx = CrudItemContext.of(context);
    final stateData = crudCtx?.stateData;
    if (stateData == null) return template;

    return interpolateWithCrudStates(
      template: template,
      stateData: stateData,
      listIndex: crudCtx?.listIndex,
      item: crudCtx?.item,
    );
  }
}
