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

class LoadUniqueIdPoolExecutor extends ActionExecutor {
  /// Widget-data key that is true while the pool is being read. The
  /// REGISTRATION config disables Register / Add Member on it, so the
  /// seconds before the count arrives no longer offer the low-ID popup.
  /// A screen without the flag (older app) behaves as before.
  static const loadingKey = 'uniqueIdPoolLoading';

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

    if (compositeKey == null) return contextData;

    try {
      _mergeWidgetData(compositeKey, {loadingKey: true});

      final repository = context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();

      final userUuid = FlowBuilderSingleton().loggedInUser?.uuid;

      final searchResult = repository.search(UniqueIdPoolSearchModel(
        status: IdStatus.unAssigned.toValue(),
        userUuid: userUuid,
      ));

      List<UniqueIdPoolModel> availableIds;
      if (searchResult is Future) {
        availableIds = await (searchResult as Future<List<UniqueIdPoolModel>>);
      } else {
        availableIds = List<UniqueIdPoolModel>.from(searchResult as List);
      }

      final count = availableIds.length;
      UniqueIdPoolModel? latestIdModel;
      if (availableIds.isNotEmpty) {
        availableIds.sort((a, b) {
          final aTime = a.auditDetails?.createdTime ?? 0;
          final bTime = b.auditDetails?.createdTime ?? 0;
          return aTime.compareTo(bTime);
        });
        latestIdModel = availableIds.first;
      }

      _mergeWidgetData(compositeKey, {
        'uniqueIdPoolCount': count,
        'latestBeneficiaryIdModel': latestIdModel,
        'latestBeneficiaryId': latestIdModel?.id,
        loadingKey: false,
      });

      return {
        ...contextData,
        'uniqueIdPoolCount': count,
        'latestBeneficiaryId': latestIdModel?.id,
        'latestBeneficiaryIdModel': latestIdModel,
      };
    } catch (e, stackTrace) {
      // Without this the search screen silently shows no pool count, which
      // sends the user to the low-ID popup and a DEFAULT identifier.
      debugPrint('LOAD_UNIQUE_ID_POOL: failed to load the pool: $e\n$stackTrace');
      // Clear the flag so a failed load does not leave Register disabled.
      _mergeWidgetData(compositeKey, {loadingKey: false});
      return contextData;
    }
  }

  /// Merges [values] into the screen's widget data. Creates the state when
  /// the screen has none yet: a search screen opened without a NAVIGATION
  /// action has no state until the user types, and the count was dropped.
  void _mergeWidgetData(String compositeKey, Map<String, dynamic> values) {
    final currentState = FlowCrudStateRegistry().get(compositeKey);
    FlowCrudStateRegistry().update(
      compositeKey,
      (currentState ?? const FlowCrudState()).copyWith(
        widgetData: {...?currentState?.widgetData, ...values},
      ),
    );
  }
}
