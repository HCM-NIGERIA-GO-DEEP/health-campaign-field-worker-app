import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_flow_builder/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../utils/beneficiary_id/pool_id_assignment.dart';

/// Loads the logged-in user's free pool IDs for the registration screens.
///
/// Publishes the free count as a process-wide snapshot (read by
/// `hasMinimumBeneficiaryId`), then writes `uniqueIdPoolCount`,
/// `latestBeneficiaryId` and `latestBeneficiaryIdModel` into the screen state,
/// creating the state when none exists yet. The ID shown here is only a hint:
/// UPDATE_IDENTIFIER_STATUS gives the real pool ID at save time.
class LoadUniqueIdPoolExecutor extends ActionExecutor {
  @override
  bool canHandle(String actionType) => actionType == 'LOAD_UNIQUE_ID_POOL';

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    final crudCtx = CrudItemContext.of(context);
    final compositeKey =
        crudCtx?.compositeKey ?? getEffectiveCompositeKey(context, contextData);

    // Without a user the repository would drop the user filter and count the
    // rows of every user on the device.
    final userUuid = FlowBuilderSingleton().currentUserUuid;
    if (userUuid == null) {
      debugPrint('LOAD_UNIQUE_ID_POOL: no logged-in user, pool not loaded');
      return contextData;
    }

    try {
      final repository = context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();

      final availableIds = sortOldestFirst(await repository.search(
        UniqueIdPoolSearchModel(
          status: IdStatus.unAssigned.toValue(),
          userUuid: userUuid,
        ),
      ));

      final count = availableIds.length;
      final latestIdModel = availableIds.isEmpty ? null : availableIds.first;

      FlowBuilderSingleton()
          .setUniqueIdPoolSnapshot(userUuid: userUuid, count: count);
      debugPrint('LOAD_UNIQUE_ID_POOL: $count free pool IDs for this user');

      if (compositeKey == null) {
        debugPrint(
            'LOAD_UNIQUE_ID_POOL: no screen key; snapshot published only');
      } else {
        final currentState = FlowCrudStateRegistry().get(compositeKey);
        FlowCrudStateRegistry().update(
          compositeKey,
          (currentState ?? const FlowCrudState()).copyWith(
            widgetData: {
              ...?currentState?.widgetData,
              'uniqueIdPoolCount': count,
              'latestBeneficiaryIdModel': latestIdModel,
              'latestBeneficiaryId': latestIdModel?.id,
            },
          ),
        );
      }

      return {
        ...contextData,
        'uniqueIdPoolCount': count,
        'latestBeneficiaryId': latestIdModel?.id,
        'latestBeneficiaryIdModel': latestIdModel,
      };
    } catch (e) {
      debugPrint('LOAD_UNIQUE_ID_POOL: failed to load the pool: $e');
      return contextData;
    }
  }
}
