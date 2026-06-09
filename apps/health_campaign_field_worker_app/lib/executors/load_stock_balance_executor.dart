import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:digit_flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transit_post/data/repositories/local/user_action.dart';

import '../models/entities/roles_type.dart';
import '../utils/function_registries.dart';
import '../utils/stock_calculation_utils.dart';
import '../utils/utils.dart';

/// Executor for LOAD_STOCK_BALANCE action type.
///
/// Refreshes [StockBalanceCache] so that stock validation functions
/// (hasStockForDelivery, hasStockForRegistration) have an up-to-date
/// balance when a screen is initialised.
///
/// Logic mirrors StockBalanceCard._refreshBalances().
class LoadStockBalanceExecutor extends ActionExecutor {
  @override
  bool canHandle(String actionType) => actionType == 'LOAD_STOCK_BALANCE';

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    try {
      final projectId = FlowBuilderSingleton().projectId;
      if (projectId == null) {
        debugPrint('LOAD_STOCK_BALANCE: No projectId, skipping');
        return contextData;
      }

      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());

      // Resolve effective facility ID
      String? facilityId;
      if (isDistributor) {
        facilityId = context.loggedInUserUuid;
      } else {
        final projectFacilityRepo = context.read<
            LocalRepository<ProjectFacilityModel,
                ProjectFacilitySearchModel>>();
        final projectFacilities = await projectFacilityRepo.search(
          ProjectFacilitySearchModel(projectId: [projectId]),
        );
        final currentFacilities = projectFacilities.where((pf) {
          final facilityLevel = pf.additionalFields?.fields
              .where((f) => f.key == 'facilityLevel')
              .firstOrNull
              ?.value;
          return facilityLevel == null || facilityLevel == 'current';
        }).toList();
        facilityId = currentFacilities.isNotEmpty
            ? currentFacilities.first.facilityId
            : null;
      }

      if (facilityId == null || facilityId.isEmpty) {
        debugPrint('LOAD_STOCK_BALANCE: No facilityId resolved, skipping');
        return contextData;
      }

      // Resolve product variant IDs from project resources
      final projectResourceRepo = context.read<
          LocalRepository<ProjectResourceModel, ProjectResourceSearchModel>>();
      final projectResources = await projectResourceRepo.search(
        ProjectResourceSearchModel(projectId: [projectId]),
      );
      final productVariantIds = projectResources
          .map((pr) => pr.resource.productVariantId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (productVariantIds.isEmpty) {
        debugPrint('LOAD_STOCK_BALANCE: No product variants found, skipping');
        return contextData;
      }

      // Load balances from StockModel records (base calculation)
      final stockRepo =
          context.read<LocalRepository<StockModel, StockSearchModel>>();

      final receivedStocks = await stockRepo.search(
        StockSearchModel(receiverId: facilityId),
      );
      final sentStocks = await stockRepo.search(
        StockSearchModel(senderId: facilityId),
      );

      // Deduplicate
      final allStocksMap = <String, StockModel>{};
      for (final stock in receivedStocks) {
        allStocksMap[stock.clientReferenceId] = stock;
      }
      for (final stock in sentStocks) {
        allStocksMap[stock.clientReferenceId] = stock;
      }

      final stockBalances =
          StockCalculationUtils.calculateStockInHandForProducts(
        stockList: allStocksMap.values.toList(),
        facilityId: facilityId,
        productIds: productVariantIds,
        loggedInUserUuid: context.loggedInUserUuid,
        isDistributor: isDistributor,
      );

      // Load UserAction balances (takes precedence — includes delivery deductions)
      final userActionRepo = context.read<UserActionLocalRepository>();
      final balanceKeys = productVariantIds
          .map((id) => generateBalanceKey(facilityId!, id))
          .toList();

      final userActionBalances = <String, double>{};
      if (balanceKeys.isNotEmpty) {
        final actions = await userActionRepo.search(
          UserActionSearchModel(
            clientReferenceId: balanceKeys,
            projectId: context.selectedProject.id,
          ),
        );
        for (final userAction in actions) {
          final fields = userAction.additionalFields?.fields;
          if (fields == null) continue;
          final productVariantId = fields
              .firstWhereOrNull((f) => f.key == 'productVariantId')
              ?.value;
          final balanceStr =
              fields.firstWhereOrNull((f) => f.key == 'balance')?.value;
          if (productVariantId != null && balanceStr != null) {
            final balance = double.tryParse(balanceStr);
            if (balance != null) {
              userActionBalances[productVariantId] = balance;
            }
          }
        }
      }

      // Merge: UserAction balances take precedence
      final mergedBalances = <String, double>{
        ...stockBalances,
        ...userActionBalances,
      };

      StockBalanceCache.instance.setCache(facilityId, mergedBalances);

      debugPrint(
        'LOAD_STOCK_BALANCE: Cache refreshed for $facilityId — balances: $mergedBalances',
      );
    } catch (e, stackTrace) {
      debugPrint('LOAD_STOCK_BALANCE error: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    return contextData;
  }
}
