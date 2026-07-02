import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:digit_data_model/data/repositories/package_repository/remote/unique_id_pool.dart';
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

import '../blocs/app_initialization/app_initialization.dart';
import '../utils/environment_config.dart';
import '../utils/extensions/extensions.dart';

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

    if (compositeKey == null) return contextData;

    try {
      final repository = context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();
      final remoteRepository = context.read<UniqueIdPoolRemoteRepository>();
      final userUuid = context.loggedInUserUuid;

      Future<List<UniqueIdPoolModel>> getAvailableIds() async {
        final searchResult = repository.search(UniqueIdPoolSearchModel(
          status: IdStatus.unAssigned.toValue(),
          userUuid: userUuid,
        ));

        if (searchResult is Future) {
          return await (searchResult as Future<List<UniqueIdPoolModel>>);
        } else {
          return List<UniqueIdPoolModel>.from(searchResult as List);
        }
      }

      List<UniqueIdPoolModel> availableIds = await getAvailableIds();
      var count = availableIds.length;

      if (count == 0) {
        try {
          final connectivityResult = await Connectivity().checkConnectivity();
          if (!context.mounted) return contextData;
          if (!connectivityResult.contains(ConnectivityResult.none)) {
            final appInitializationState =
                context.read<AppInitializationBloc>().state;
            int batchSize = 10;
            if (appInitializationState is AppInitialized) {
              batchSize = appInitializationState
                      .appConfiguration.beneficiaryIdConfig?.first.batchSize
                      .toInt() ??
                  10;
            }

            final tenantId = envConfig.variables.tenantId;
            final deviceInfo = DeviceInfoPlugin();
            final androidInfo = await deviceInfo.androidInfo;
            final deviceUuid = androidInfo.id;

            final searchModel = UniqueIdPoolSearchModel(
              deviceInfo: androidInfo.toString(),
              userUuid: userUuid,
              deviceUuid: deviceUuid,
              tenantId: tenantId,
              count: batchSize,
              fetchAllocatedIds: false,
            );

            final response = await remoteRepository.searchWithMetadata(
              searchModel,
              limit: batchSize,
              offSet: 0,
            );

            final List<UniqueIdPoolModel> batch = response.models;
            if (batch.isNotEmpty) {
              await repository.bulkCreate(batch);
              availableIds = await getAvailableIds();
              count = availableIds.length;
            }
          }
        } catch (e) {
          debugPrint('Silent beneficiary ID downsync failed: $e');
        }
      }

      UniqueIdPoolModel? latestIdModel;
      if (availableIds.isNotEmpty) {
        availableIds.sort((a, b) {
          final aTime = a.auditDetails?.createdTime ?? 0;
          final bTime = b.auditDetails?.createdTime ?? 0;
          return aTime.compareTo(bTime);
        });
        latestIdModel = availableIds.first;
      }

      final currentState = FlowCrudStateRegistry().get(compositeKey);
      final currentWidgetData =
          Map<String, dynamic>.from(currentState?.widgetData ?? {});

      currentWidgetData['uniqueIdPoolCount'] = count;
      currentWidgetData['latestBeneficiaryIdModel'] = latestIdModel;
      currentWidgetData['latestBeneficiaryId'] = latestIdModel?.id;

      final updatedState =
          currentState?.copyWith(widgetData: currentWidgetData);
      if (updatedState != null) {
        FlowCrudStateRegistry().update(compositeKey, updatedState);
      }

      return {
        ...contextData,
        'uniqueIdPoolCount': count,
        'latestBeneficiaryId': latestIdModel?.id,
        'latestBeneficiaryIdModel': latestIdModel,
      };
    } catch (e) {
      return contextData;
    }
  }
}
