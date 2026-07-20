import 'dart:async';

import 'package:digit_data_model/data/repositories/package_repository/remote/stock.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:disk_space_update/disk_space_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart';
import 'package:transit_post/data/repositories/local/user_action.dart';
import 'package:transit_post/data/repositories/remote/user_action.dart';

import '../../data/local_store/app_shared_preferences.dart';
import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../data/local_store/secure_store/secure_store.dart';
import '../../data/repositories/remote/bandwidth_check.dart';
import '../../utils/stock_calculation_utils.dart';
import '../../utils/stock_downsync_cursor.dart';
import '../../models/downsync/downsync.dart';
import '../../models/entities/roles_type.dart';
import '../../utils/background_service.dart';
import '../../utils/utils.dart';

part 'stock_downsync.freezed.dart';

typedef StockDownSyncEmitter = Emitter<StockDownSyncState>;

class StockDownSyncBloc extends Bloc<StockDownSyncEvent, StockDownSyncState> {
  final LocalSecureStore localSecureStore;

  final LocalRepository<ProjectFacilityModel, ProjectFacilitySearchModel>
      projectFacilityLocalRepository;

  final LocalRepository<FacilityModel, FacilitySearchModel>
      facilityLocalRepository;

  final RemoteRepository<StockModel, StockSearchModel> stockRemoteRepository;

  final LocalRepository<StockModel, StockSearchModel> stockLocalRepository;

  final LocalRepository<ProjectResourceModel, ProjectResourceSearchModel>
      projectResourceLocalRepository;

  final BandwidthCheckRepository bandwidthCheckRepository;

  final LocalRepository<DownsyncModel, DownsyncSearchModel>
      downSyncLocalRepository;

  final UserActionRemoteRepository userActionRemoteRepository;

  final UserActionLocalRepository userActionLocalRepository;

  final BuildContext context;

  static const String _rejectedStatus = 'REJECTED';
  static const String _dispatchedTransaction = 'DISPATCHED';

  StockDownSyncBloc({
    required this.context,
    required this.localSecureStore,
    required this.projectFacilityLocalRepository,
    required this.facilityLocalRepository,
    required this.stockRemoteRepository,
    required this.stockLocalRepository,
    required this.projectResourceLocalRepository,
    required this.bandwidthCheckRepository,
    required this.downSyncLocalRepository,
    required this.userActionRemoteRepository,
    required this.userActionLocalRepository,
  }) : super(const StockDownSyncState._()) {
    on(_handleGetBatchSize);
    on(_handleCheckTotalCount);
    on(_handleDownSyncStock);
    on(_handleResetState);
  }

  /// Build the StockSearchModel based on user role
  Future<StockSearchModel?> _buildStockSearchModel(ProjectModel project) async {
    final userObject = await localSecureStore.userRequestModel;
    final userRoles = userObject!.roles.map((e) => e.code);

    final projectFacilities = await projectFacilityLocalRepository.search(
      ProjectFacilitySearchModel(projectId: [project.id]),
    );

    // Filter to only include facilities where facilityLevel is 'current'
    final currentFacilities = projectFacilities.where((pf) {
      final facilityLevel = pf.additionalFields?.fields
          .where((f) => f.key == 'facilityLevel')
          .firstOrNull
          ?.value;
      return facilityLevel == null || facilityLevel == 'current';
    }).toList();

    final projectResources = await projectResourceLocalRepository.search(
      ProjectResourceSearchModel(projectId: [project.id]),
    );
    final productVariantIds = projectResources
        .map((pr) => pr.resource.productVariantId)
        .whereType<String>()
        .toSet()
        .toList();

    List<String> receiverIds = [];

    if (userRoles.contains(RolesType.healthFacilitySupervisor.toValue())) {
      receiverIds = currentFacilities.map((e) => e.facilityId).toList();
    } else if (userRoles.contains(RolesType.warehouseManager.toValue())) {
      receiverIds = currentFacilities.map((e) => e.facilityId).toList();
    } else if (userRoles.contains(RolesType.communityDistributor.toValue()) ||
        userRoles.contains(RolesType.distributor.toValue())) {
      receiverIds = [userObject.uuid];
    }

    if (receiverIds.isEmpty) return null;

    return StockSearchModel(
      receiverId: receiverIds.first,
      senderId: receiverIds.first,
      campaignNumber: project.referenceID,
    );
  }

  FutureOr<void> _handleResetState(
    StockDownSyncResetStateEvent event,
    StockDownSyncEmitter emit,
  ) async {
    emit(const StockDownSyncState.resetState());
  }

  FutureOr<void> _handleGetBatchSize(
    StockDownSyncGetBatchSizeEvent event,
    StockDownSyncEmitter emit,
  ) async {
    try {
      emit(const StockDownSyncState.resetState());
      emit(const StockDownSyncState.loading(false));

      final double speed = await bandwidthCheckRepository.pingBandwidthCheck(
        bandWidthCheckModel: null,
      );
      int configuredBatchSize = getBatchSizeToBandwidth(
        speed,
        event.appConfiguration,
        isDownSync: true,
      );
      emit(StockDownSyncState.getBatchSize(
        configuredBatchSize,
        event.projectModel,
      ));
    } catch (e) {
      emit(const StockDownSyncState.resetState());
      emit(const StockDownSyncState.totalCountCheckFailed());
    }
  }

  String _getLocalityKey(String projectId) => 'stock_$projectId';

  /// Resolves the start date (in millis) of the currently active cycle for the
  /// given [project], falling back to the project's embedded project type when
  /// the selected project type has no matching cycle.
  ///
  /// Used to scope stock downsync via `lastChangedSince` so only records changed
  /// since the current cycle started are pulled. Both the count check and the
  /// actual download must use this so the download does not fetch pre-cycle data.
  Future<int?> _getCurrentCycleStartDate(ProjectModel project) async {
    final selectedProjectType = await localSecureStore.selectedProjectType;
    final now = DateTime.now().millisecondsSinceEpoch;

    return selectedProjectType?.cycles
            ?.where(
              (cycle) =>
                  (cycle.startDate ?? 0) <= now && (cycle.endDate ?? 0) >= now,
            )
            .firstOrNull
            ?.startDate ??
        project.additionalDetails?.projectType?.cycles
            ?.where(
              (cycle) => cycle.startDate <= now && cycle.endDate >= now,
            )
            .firstOrNull
            ?.startDate;
  }

  /// Resolves the current cycle's startDate and index (id) from the stored
  /// project type, falling back to the project model's cycles. Both may be
  /// absent (date outside campaign, fresh config) — returns nulls/0 then.
  Future<MapEntry<int?, int>> _getCurrentCycleInfo(
      ProjectModel projectModel) async {
    final selectedProjectType = await localSecureStore.selectedProjectType;
    final now = DateTime.now().millisecondsSinceEpoch;

    final storedCycle = selectedProjectType?.cycles
        ?.where(
          (cycle) =>
              (cycle.startDate ?? 0) <= now && (cycle.endDate ?? 0) >= now,
        )
        .firstOrNull;
    if (storedCycle != null) {
      return MapEntry(storedCycle.startDate, storedCycle.id);
    }

    final projectCycle = projectModel.additionalDetails?.projectType?.cycles
        ?.where(
          (cycle) => cycle.startDate <= now && cycle.endDate >= now,
        )
        .firstOrNull;

    return MapEntry(projectCycle?.startDate, projectCycle?.id ?? 0);
  }

  FutureOr<void> _handleCheckTotalCount(
    StockDownSyncCheckTotalCountEvent event,
    StockDownSyncEmitter emit,
  ) async {
    emit(const StockDownSyncState.loading(true));
    try {
      final cycleInfo = await _getCurrentCycleInfo(event.projectModel);

      final stockSearchModel = await _buildStockSearchModel(event.projectModel);

      if (stockSearchModel == null) {
        emit(const StockDownSyncState.dataFound(0, 0, 0, null));
        return;
      }

      // Cursor is per user + cycle so a second user on the same device
      // still downloads their own stock from cycle start.
      final userObject = await localSecureStore.userRequestModel;
      final cursorKey = StockDownsyncCursor.key(
        event.projectModel.id,
        userObject?.uuid ?? '',
        cycleInfo.value,
      );

      int? lastSyncedTime = StockDownsyncCursor.resolveCutoff(
        storedTime: AppSharedPreferences().getStockDownsyncTime(cursorKey),
        cycleStartDate: cycleInfo.key,
      );

      // Always start from offset 0 for total count check since
      // lastChangedSince already scopes the query to new/modified records
      final totalCount = await (stockRemoteRepository as StockRemoteRepository)
          .fetchTotalCount(
        stockSearchModel,
        offSet: 0,
        lastSyncedTime: lastSyncedTime,
        includeOnlyUpdatedByOthers: true,
      );

      emit(StockDownSyncState.dataFound(
        totalCount,
        event.batchSize,
        0,
        lastSyncedTime,
      ));
    } catch (e) {
      emit(const StockDownSyncState.resetState());
      emit(const StockDownSyncState.totalCountCheckFailed());
    }
  }

  FutureOr<void> _handleDownSyncStock(
    StockDownSyncDownloadEvent event,
    StockDownSyncEmitter emit,
  ) async {
    emit(const StockDownSyncState.loading(true));
    double? diskSpace = 0;
    diskSpace = await DiskSpace.getFreeDiskSpace;

    if ((diskSpace ?? 0) * 1000 < (event.initialServerCount * 150 * 2)) {
      emit(const StockDownSyncState.insufficientStorage());
    } else {
      try {
        final stockSearchModel =
            await _buildStockSearchModel(event.projectModel);

        if (stockSearchModel == null) {
          emit(const StockDownSyncState.failed());
          return;
        }

        final localityKey = _getLocalityKey(event.projectModel.id);

        // Per-user + per-cycle cursor; falls back to the current cycle's
        // startDate for a user who has never downsynced on this device.
        final cycleInfo = await _getCurrentCycleInfo(event.projectModel);
        final userObject = await localSecureStore.userRequestModel;
        final cursorKey = StockDownsyncCursor.key(
          event.projectModel.id,
          userObject?.uuid ?? '',
          cycleInfo.value,
        );

        int? lastSyncedTime = StockDownsyncCursor.resolveCutoff(
          storedTime: AppSharedPreferences().getStockDownsyncTime(cursorKey),
          cycleStartDate: cycleInfo.key,
        );

        // Check existing downsync data for stock
        final existingDownSyncData =
            await downSyncLocalRepository.search(DownsyncSearchModel(
          locality: localityKey,
        ));

        // On the first download (no existing downsync record) scope the query
        // to the current cycle start so pre-cycle stock is not pulled. Must
        // match _handleCheckTotalCount, otherwise the count preview and the
        // actual download disagree and older records get downloaded.

        // Create initial downsync record if not exists
        if (existingDownSyncData.isEmpty) {
          await downSyncLocalRepository.create(DownsyncModel(
            offset: 0,
            limit: event.batchSize,
            lastSyncedTime: lastSyncedTime,
            totalCount: 0,
            locality: localityKey,
          ));
        }

        int totalCount = event.initialServerCount;
        int syncedCount = 0;
        final downsyncedStocks = <String, StockModel>{};
        final syncStartTime = DateTime.now().millisecondsSinceEpoch;

        emit(StockDownSyncState.inProgress(syncedCount, totalCount));

        // Fetch stock entries in batches to allow progress updates
        while (syncedCount < totalCount) {
          final stockEntries = await stockRemoteRepository.search(
            stockSearchModel,
            offSet: 0,
            limit: event.batchSize,
            lastSyncedTime: lastSyncedTime,
            includeOnlyUpdatedByOthers: true,
          );

          if (stockEntries.isEmpty) break;

          await stockLocalRepository.bulkCreate(stockEntries);
          for (final stock in stockEntries) {
            downsyncedStocks[stock.clientReferenceId] = stock;
          }

          syncedCount += stockEntries.length;

          // Update downsync record, keep offset 0, update lastSyncedTime
          await downSyncLocalRepository.update(DownsyncModel(
            offset: 0,
            limit: event.batchSize,
            lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
            totalCount: totalCount,
            locality: localityKey,
          ));

          emit(StockDownSyncState.inProgress(syncedCount, totalCount));
        }

        // Advance the per-user cursor only after all pages downloaded, using
        // the time captured before the first fetch so records modified during
        // the download are picked up next time.
        await AppSharedPreferences()
            .setStockDownsyncTime(cursorKey, syncStartTime);

        // After stock download, downsync stock balance user actions
        await downSyncStockBalances(event.projectModel.id);
        await _reconcileRejectedOutgoingStocks(
          projectId: event.projectModel.id,
          stockEntries: downsyncedStocks.values.toList(),
        );

        emit(StockDownSyncState.success(syncedCount, totalCount));
      } catch (e) {
        emit(const StockDownSyncState.failed());
      }
    }
  }

  /// Fetches stock balance UserAction records from the server
  /// using balance keys (stock_balance_{facilityId}_{productVariantId})
  /// and creates or updates them locally.
  Future<void> downSyncStockBalances(String projectId) async {
    try {
      final userObject = await localSecureStore.userRequestModel;
      final userRoles = userObject?.roles.map((e) => e.code) ?? [];
      final isDistributor =
          userRoles.contains(RolesType.distributor.toValue()) ||
              userRoles.contains(RolesType.communityDistributor.toValue());

      final projectFacilities = await projectFacilityLocalRepository.search(
        ProjectFacilitySearchModel(projectId: [projectId]),
      );

      final projectResources = await projectResourceLocalRepository.search(
        ProjectResourceSearchModel(projectId: [projectId]),
      );

      final currentFacilities = projectFacilities.where((pf) {
        final facilityLevel = pf.additionalFields?.fields
            .where((f) => f.key == 'facilityLevel')
            .firstOrNull
            ?.value;
        return facilityLevel == null || facilityLevel == 'current';
      }).toList();

      List<String> facilityIds;
      if (isDistributor) {
        facilityIds = [userObject?.uuid ?? ''];
      } else {
        facilityIds = currentFacilities
            .map((e) => e.facilityId)
            .whereType<String>()
            .toSet()
            .toList();
      }

      final productVariantIds = projectResources
          .map((pr) => pr.resource.productVariantId)
          .whereType<String>()
          .toSet()
          .toList();

      if (facilityIds.isEmpty ||
          productVariantIds.isEmpty ||
          facilityIds.first.isEmpty) return;

      // Build balance keys for all facility × product variant combinations
      final balanceKeys = <String>[];
      for (final facilityId in facilityIds) {
        for (final productVariantId in productVariantIds) {
          balanceKeys.add(generateBalanceKey(facilityId, productVariantId,
              context.selectedProject.referenceID, userObject?.id));
        }
      }

      // Fetch from server
      final remoteBalances = await userActionRemoteRepository.search(
        UserActionSearchModel(
            clientReferenceId: balanceKeys, projectId: projectId),
      );

      if (remoteBalances.isEmpty) return;

      // For each fetched balance, create or update locally
      for (final remoteBalance in remoteBalances) {
        final existing = await userActionLocalRepository.search(
          UserActionSearchModel(
            clientReferenceId: [remoteBalance.clientReferenceId],
          ),
        );

        if (existing.isNotEmpty) {
          await userActionLocalRepository.update(
            remoteBalance,
            createOpLog: false,
          );
        } else {
          await userActionLocalRepository.create(
            remoteBalance,
            createOpLog: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Stock balance downsync error: $e');
    }
  }

  Future<void> _reconcileRejectedOutgoingStocks({
    required String projectId,
    required List<StockModel> stockEntries,
  }) async {
    if (stockEntries.isEmpty) return;

    try {
      final userObject = await localSecureStore.userRequestModel;
      final userRoles = userObject?.roles.map((e) => e.code) ?? [];
      final isDistributor =
          userRoles.contains(RolesType.distributor.toValue()) ||
              userRoles.contains(RolesType.communityDistributor.toValue());

      final projectFacilities = await projectFacilityLocalRepository.search(
        ProjectFacilitySearchModel(projectId: [projectId]),
      );

      final currentFacilities = projectFacilities.where((pf) {
        final facilityLevel = pf.additionalFields?.fields
            .where((f) => f.key == 'facilityLevel')
            .firstOrNull
            ?.value;
        return facilityLevel == null || facilityLevel == 'current';
      }).toList();

      final facilityIds = isDistributor
          ? {userObject?.uuid ?? ''}
          : currentFacilities
              .map((e) => e.facilityId)
              .whereType<String>()
              .toSet();

      facilityIds.removeWhere((element) => element.isEmpty);
      if (facilityIds.isEmpty) return;

      final rejectedDeltas = <String, double>{};

      for (final stock in stockEntries) {
        final senderId = stock.senderId;
        final productVariantId = stock.productVariantId;
        final status = _getAdditionalFieldValue(stock, 'status');
        final transactionType = stock.transactionType?.toUpperCase() ?? '';

        if (senderId == null ||
            productVariantId == null ||
            !facilityIds.contains(senderId) ||
            transactionType != _dispatchedTransaction ||
            status != _rejectedStatus) {
          continue;
        }

        final quantity = double.tryParse(stock.quantity ?? '0') ?? 0;
        if (quantity <= 0) continue;

        final balanceKey = generateBalanceKey(senderId, productVariantId,
            context.selectedProject.referenceID, userObject?.id);
        rejectedDeltas[balanceKey] =
            (rejectedDeltas[balanceKey] ?? 0) + quantity;
      }

      for (final entry in rejectedDeltas.entries) {
        await _increaseBalance(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('Rejected stock balance reconciliation error: $e');
    }
  }

  Future<void> _increaseBalance(String balanceKey, double quantity) async {
    if (quantity <= 0) return;

    final existing = await userActionLocalRepository.search(
      UserActionSearchModel(clientReferenceId: [balanceKey]),
    );

    if (existing.isEmpty) return;

    final balanceAction = existing.first;
    final balanceFieldIndex = balanceAction.additionalFields?.fields
            ?.indexWhere((field) => field.key == 'balance') ??
        -1;

    if (balanceFieldIndex < 0) return;

    final currentBalance = double.tryParse(
          balanceAction.additionalFields?.fields?[balanceFieldIndex].value ??
              '0',
        ) ??
        0;

    final updatedFields = List<AdditionalField>.from(
        balanceAction.additionalFields?.fields ?? []);
    updatedFields[balanceFieldIndex] = AdditionalField(
      'balance',
      (currentBalance + quantity).toString(),
    );

    await userActionLocalRepository.update(
      balanceAction.copyWith(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        additionalFields: UserActionAdditionalFields(
          version: balanceAction.additionalFields?.version ?? 1,
          fields: updatedFields,
        ),
      ),
      createOpLog: false,
    );
  }

  String _getAdditionalFieldValue(StockModel stock, String key) {
    final fields = stock.additionalFields?.fields;
    if (fields == null) return '';
    for (final field in fields) {
      if (field.key == key) {
        return field.value?.toString().toUpperCase() ?? '';
      }
    }
    return '';
  }
}

@freezed
class StockDownSyncEvent with _$StockDownSyncEvent {
  const factory StockDownSyncEvent.getBatchSize({
    required List<AppConfiguration> appConfiguration,
    required ProjectModel projectModel,
  }) = StockDownSyncGetBatchSizeEvent;

  const factory StockDownSyncEvent.checkTotalCount({
    required ProjectModel projectModel,
    required int batchSize,
  }) = StockDownSyncCheckTotalCountEvent;

  const factory StockDownSyncEvent.downloadStock({
    required ProjectModel projectModel,
    required int batchSize,
    required int initialServerCount,
  }) = StockDownSyncDownloadEvent;

  const factory StockDownSyncEvent.resetState() = StockDownSyncResetStateEvent;
}

@freezed
class StockDownSyncState with _$StockDownSyncState {
  const StockDownSyncState._();

  const factory StockDownSyncState.loading(bool isPop) =
      _StockDownSyncLoadingState;

  const factory StockDownSyncState.getBatchSize(
    int batchSize,
    ProjectModel projectModel,
  ) = _StockDownSyncGetBatchSizeState;

  const factory StockDownSyncState.dataFound(
    int initialServerCount,
    int batchSize,
    int offset,
    int? lastSyncedTime,
  ) = _StockDownSyncDataFoundState;

  const factory StockDownSyncState.inProgress(
    int syncedCount,
    int totalCount,
  ) = _StockDownSyncInProgressState;

  const factory StockDownSyncState.success(
    int syncedCount,
    int totalCount,
  ) = _StockDownSyncSuccessState;

  const factory StockDownSyncState.failed() = _StockDownSyncFailureState;

  const factory StockDownSyncState.insufficientStorage() =
      _StockDownSyncInsufficientStorageState;

  const factory StockDownSyncState.totalCountCheckFailed() =
      _StockDownSyncCountCheckFailedState;

  const factory StockDownSyncState.resetState() = _StockDownSyncResetState;
}
