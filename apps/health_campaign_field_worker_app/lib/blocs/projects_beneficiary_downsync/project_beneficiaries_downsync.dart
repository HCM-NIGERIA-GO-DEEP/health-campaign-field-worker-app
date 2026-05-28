// GENERATED using mason_cli
import 'dart:async';
import 'dart:convert';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/hf_referral.dart';
import 'package:disk_space_update/disk_space_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:survey_form/models/entities/service.dart';
import 'package:sync_service/sync_service_lib.dart';

import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../data/local_store/secure_store/secure_store.dart';
import '../../data/repositories/remote/bandwidth_check.dart';
import '../../models/downsync/downsync.dart';
import '../../services/beneficiary_file_downsync_importer.dart';
import '../../utils/background_service.dart';
import '../../utils/environment_config.dart';
import '../../utils/utils.dart';

part 'project_beneficiaries_downsync.freezed.dart';

typedef BeneficiaryDownSyncEmitter = Emitter<BeneficiaryDownSyncState>;

class BeneficiaryDownSyncBloc
    extends Bloc<BeneficiaryDownSyncEvent, BeneficiaryDownSyncState> {
  static const int _paginatedDownsyncStorageKbPerRecord = 150;
  static const int _fileDownsyncStorageKbPerRecord = 5;
  static const int _storageSafetyMultiplier = 2;

  String currentEntityType = '';

  final LocalRepository<IndividualModel, IndividualSearchModel>
      individualLocalRepository;
  final RemoteRepository<DownsyncModel, DownsyncSearchModel>
      downSyncRemoteRepository;
  final LocalRepository<DownsyncModel, DownsyncSearchModel>
      downSyncLocalRepository;
  final BandwidthCheckRepository bandwidthCheckRepository;
  final LocalRepository<HouseholdModel, HouseholdSearchModel>
      householdLocalRepository;
  final LocalRepository<HouseholdMemberModel, HouseholdMemberSearchModel>
      householdMemberLocalRepository;
  final LocalRepository<ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>
      projectBeneficiaryLocalRepository;
  final LocalRepository<TaskModel, TaskSearchModel> taskLocalRepository;
  final LocalRepository<SideEffectModel, SideEffectSearchModel>
      sideEffectLocalRepository;
  final LocalRepository<ReferralModel, ReferralSearchModel>
      referralLocalRepository;
  final LocalRepository<HFReferralModel, HFReferralSearchModel>
      hfReferralLocalRepository;
  final LocalRepository<ServiceModel, ServiceSearchModel>
      serviceLocalRepository;

  BeneficiaryDownSyncBloc({
    required this.individualLocalRepository,
    required this.downSyncRemoteRepository,
    required this.downSyncLocalRepository,
    required this.bandwidthCheckRepository,
    required this.householdLocalRepository,
    required this.householdMemberLocalRepository,
    required this.projectBeneficiaryLocalRepository,
    required this.taskLocalRepository,
    required this.sideEffectLocalRepository,
    required this.referralLocalRepository,
    required this.hfReferralLocalRepository,
    required this.serviceLocalRepository,
  }) : super(const BeneficiaryDownSyncState._()) {
    on(_handleDownSyncOfBeneficiaries);
    on(_handleCheckTotalCount);
    on(_handleDownSyncResetState);
    on(_handleDownSyncReport);
    on(_handleCheckBandWidth);
    on(_handleCheckAllTotalCounts);
    on(_handleDownloadAllBoundaries);
  }

  FutureOr<void> _handleDownSyncResetState(
    DownSyncResetStateEvent event,
    BeneficiaryDownSyncEmitter emit,
  ) async {
    emit(const BeneficiaryDownSyncState.resetState());
  }

  FutureOr<void> _handleCheckBandWidth(
    DownSyncGetBatchSizeEvent event,
    BeneficiaryDownSyncEmitter emit,
  ) async {
    try {
      emit(const BeneficiaryDownSyncState.resetState());
      emit(const BeneficiaryDownSyncState.loading(false));
      List speedArray = [];

      final double speed = await bandwidthCheckRepository.pingBandwidthCheck(
        bandWidthCheckModel: null,
      );
      speedArray.add(speed);
      double sum = speedArray.fold(0, (p, c) => p + c);
      int configuredBatchSize = getBatchSizeToBandwidth(
        sum / speedArray.length,
        event.appConfiguration,
        isDownSync: true,
      );
      emit(BeneficiaryDownSyncState.getBatchSize(
        configuredBatchSize,
        event.projectModel,
        event.boundaries,
        event.pendingSyncCount,
      ));
    } catch (e) {
      emit(const BeneficiaryDownSyncState.resetState());
      emit(const BeneficiaryDownSyncState.totalCountCheckFailed());
    }
  }

  FutureOr<void> _handleCheckTotalCount(
    DownSyncCheckTotalCountEvent event,
    BeneficiaryDownSyncEmitter emit,
  ) async {
    if (event.pendingSyncCount > 0) {
      emit(const BeneficiaryDownSyncState.loading(true));
      emit(const BeneficiaryDownSyncState.pendingSync());
    } else {
      emit(const BeneficiaryDownSyncState.loading(true));
      await LocalSecureStore.instance.setManualSyncTrigger(true);
      final existingDownSyncData =
          await downSyncLocalRepository.search(DownsyncSearchModel(
        locality: event.boundaryCode,
      ));

      int? lastSyncedTime = existingDownSyncData.isEmpty
          ? null
          : existingDownSyncData.first.lastSyncedTime;

      //To get the server totalCount,
      final initialResults = await downSyncRemoteRepository.downSync(
        DownsyncSearchModel(
          locality: event.boundaryCode,
          offset: existingDownSyncData.firstOrNull?.offset ?? 0,
          limit: 0,
          isDeleted: true,
          lastSyncedTime: lastSyncedTime,
          tenantId: envConfig.variables.tenantId,
          projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
        ),
      );
      if (initialResults.isNotEmpty) {
        final downloadLinks = _downloadLinksFrom(initialResults);
        final serverTotalCount = downloadLinks.isNotEmpty
            ? _downloadLinksRecordCount(downloadLinks)
            : initialResults["DownsyncCriteria"]["totalCount"] as int;

        emit(BeneficiaryDownSyncState.dataFound(
          serverTotalCount,
          event.batchSize,
          {event.boundaryCode: serverTotalCount},
        ));
      } else {
        await LocalSecureStore.instance.setManualSyncTrigger(false);
        emit(const BeneficiaryDownSyncState.resetState());
        emit(const BeneficiaryDownSyncState.totalCountCheckFailed());
      }
    }
  }

  FutureOr<void> _handleDownSyncOfBeneficiaries(
    DownSyncBeneficiaryEvent event,
    BeneficiaryDownSyncEmitter emit,
  ) async {
    emit(const BeneficiaryDownSyncState.loading(true));
    try {
      final existingDownSyncDataForFileCheck =
          await downSyncLocalRepository.search(DownsyncSearchModel(
        locality: event.boundaryCode,
      ));
      final existingLastSyncedTime = existingDownSyncDataForFileCheck.isEmpty
          ? null
          : existingDownSyncDataForFileCheck.first.lastSyncedTime;

      if (existingLastSyncedTime == null) {
        final linkResults = await downSyncRemoteRepository.downSync(
          DownsyncSearchModel(
            locality: event.boundaryCode,
            offset: 0,
            limit: 0,
            totalCount: event.initialServerCount,
            tenantId: envConfig.variables.tenantId,
            projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
            isDeleted: true,
          ),
        );
        final downloadLinks = _downloadLinksFrom(linkResults);

        if (downloadLinks.isNotEmpty) {
          final totalCount = _downloadLinksRecordCount(downloadLinks);
          if (await _hasInsufficientStorage(
            totalCount,
            kbPerRecord: _fileDownsyncStorageKbPerRecord,
          )) {
            emit(const BeneficiaryDownSyncState.insufficientStorage());
            await LocalSecureStore.instance.setManualSyncTrigger(false);
            return;
          }

          await _importDownloadLinks(
            links: downloadLinks,
            projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
            boundaryCode: event.boundaryCode,
            boundaryName: event.boundaryName,
            totalCount: totalCount,
            batchSize: event.batchSize,
            emitProgress: (link, linkImported, totalImported, _, lastEntityType) {
              if (lastEntityType.isNotEmpty) {
                currentEntityType = lastEntityType;
              } else if (link.fileType.isNotEmpty) {
                currentEntityType = link.fileType;
              }
              emit(BeneficiaryDownSyncState.inProgress(
                linkImported,
                link.recordCount,
              ));
            },
          );

          final result = DownsyncModel(
            offset: totalCount,
            lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
            totalCount: totalCount,
            locality: event.boundaryCode,
            boundaryName: event.boundaryName,
          );
          await LocalSecureStore.instance.setManualSyncTrigger(false);
          emit(BeneficiaryDownSyncState.success(result));
          return;
        }
      }

      if (await _hasInsufficientStorage(
        event.initialServerCount,
        kbPerRecord: _paginatedDownsyncStorageKbPerRecord,
      )) {
        emit(const BeneficiaryDownSyncState.insufficientStorage());
        await LocalSecureStore.instance.setManualSyncTrigger(false);
        return;
      }

      while (true) {
        // Check each time, till the loop runs the offset, limit, totalCount, lastSyncTime from Local DB of DownSync Model
        final existingDownSyncData =
            await downSyncLocalRepository.search(DownsyncSearchModel(
          locality: event.boundaryCode,
        ));

        int offset = existingDownSyncData.isEmpty
            ? 0
            : existingDownSyncData.first.offset ?? 0;
        int totalCount = event.initialServerCount;
        int? lastSyncedTime = existingDownSyncData.isEmpty
            ? null
            : existingDownSyncData.first.lastSyncedTime;
        if (existingDownSyncData.isEmpty) {
          await downSyncLocalRepository.create(DownsyncModel(
            offset: offset,
            limit: event.batchSize,
            lastSyncedTime: lastSyncedTime,
            totalCount: totalCount,
            locality: event.boundaryCode,
            boundaryName: event.boundaryName,
          ));
        }

        if (offset < totalCount) {
          emit(BeneficiaryDownSyncState.inProgress(offset, totalCount));
          //Make the batch API call
          final downSyncResults = await downSyncRemoteRepository.downSync(
            DownsyncSearchModel(
              locality: event.boundaryCode,
              offset: offset,
              limit: event.batchSize,
              totalCount: totalCount,
              tenantId: envConfig.variables.tenantId,
              projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
              lastSyncedTime: lastSyncedTime,
              isDeleted: true,
            ),
          );
          emit(BeneficiaryDownSyncState.inProgress(
              offset, downSyncResults["DownsyncCriteria"]["totalCount"]));

          // check if the API response is there or it failed
          if (downSyncResults.isNotEmpty) {
            await writeToFile(event.projectModel.id, event.boundaryCode,
                event.boundaryName, downSyncResults);
            await SyncServiceSingleton()
                .entityMapper
                ?.writeToEntityDB(downSyncResults, [
              individualLocalRepository,
              householdLocalRepository,
              householdMemberLocalRepository,
              projectBeneficiaryLocalRepository,
              taskLocalRepository,
              sideEffectLocalRepository,
              referralLocalRepository,
              hfReferralLocalRepository,
              serviceLocalRepository,
            ]);
            // Update the local downSync data for the boundary with the new values
            totalCount = downSyncResults["DownsyncCriteria"]["totalCount"];

            await downSyncLocalRepository.update(DownsyncModel(
              offset: offset + event.batchSize,
              limit: event.batchSize,
              lastSyncedTime: lastSyncedTime,
              totalCount: totalCount,
              locality: event.boundaryCode,
              boundaryName: event.boundaryName,
            ));
          }
          // When API response failed
          else {
            emit(const BeneficiaryDownSyncState.failed());
            await LocalSecureStore.instance.setManualSyncTrigger(false);
            break;
          }
        } else {
          await downSyncLocalRepository.update(
            existingDownSyncData.first.copyWith(
              offset: 0,
              limit: 0,
              totalCount: totalCount,
              locality: event.boundaryCode,
              boundaryName: event.boundaryName,
              lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
            ),
          );
          final result = DownsyncModel(
            offset: totalCount,
            lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
            totalCount: totalCount,
            locality: event.boundaryCode,
            boundaryName: event.boundaryName,
          );
          await LocalSecureStore.instance.setManualSyncTrigger(false);
          emit(BeneficiaryDownSyncState.success(result));
          break; // If offset is greater than or equal to totalCount, exit the loop
        }
      }
    } catch (e) {
      await LocalSecureStore.instance.setManualSyncTrigger(false);
      emit(const BeneficiaryDownSyncState.failed());
    }
  }

  FutureOr<void> _handleCheckAllTotalCounts(
    DownSyncAllBoundariesEvent event,
    BeneficiaryDownSyncEmitter emit,
  ) async {
    if (event.pendingSyncCount > 0) {
      emit(const BeneficiaryDownSyncState.loading(true));
      emit(const BeneficiaryDownSyncState.pendingSync());
      return;
    }

    emit(const BeneficiaryDownSyncState.loading(true));
    await LocalSecureStore.instance.setManualSyncTrigger(true);

    try {
      int totalServerCount = 0;
      final Map<String, int> boundaryCounts = {};

      for (final boundary in event.boundaries) {
        final boundaryCode = boundary.code.toString();

        final existingDownSyncData =
            await downSyncLocalRepository.search(DownsyncSearchModel(
          locality: boundaryCode,
        ));

        int? lastSyncedTime = existingDownSyncData.isEmpty
            ? null
            : existingDownSyncData.first.lastSyncedTime;

        final initialResults = await downSyncRemoteRepository.downSync(
          DownsyncSearchModel(
            locality: boundaryCode,
            offset: existingDownSyncData.firstOrNull?.offset ?? 0,
            limit: 0,
            isDeleted: true,
            lastSyncedTime: lastSyncedTime,
            tenantId: envConfig.variables.tenantId,
            projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
          ),
        );

        if (initialResults.isNotEmpty) {
          final downloadLinks = _downloadLinksFrom(initialResults);
          final count = downloadLinks.isNotEmpty
              ? _downloadLinksRecordCount(downloadLinks)
              : initialResults["DownsyncCriteria"]["totalCount"] as int;
          if (count > 0) {
            boundaryCounts[boundaryCode] = count;
            totalServerCount += count;
          }
        }
      }

      emit(BeneficiaryDownSyncState.dataFound(
        totalServerCount,
        event.batchSize,
        boundaryCounts,
      ));
    } catch (e) {
      await LocalSecureStore.instance.setManualSyncTrigger(false);
      emit(const BeneficiaryDownSyncState.resetState());
      emit(const BeneficiaryDownSyncState.totalCountCheckFailed());
    }
  }

  FutureOr<void> _handleDownloadAllBoundaries(
    DownSyncDownloadAllEvent event,
    BeneficiaryDownSyncEmitter emit,
  ) async {
    emit(const BeneficiaryDownSyncState.loading(true));

    // Only process boundaries that have data (count > 0) from the initial check
    final boundaries = event.boundaries
        .where((b) => (event.boundaryCounts[b.code.toString()] ?? 0) > 0)
        .toList();
    final List<DownsyncModel> completedResults = [];

    try {
      for (int i = 0; i < boundaries.length; i++) {
        final boundaryCode = boundaries[i].code.toString();
        final boundaryName = boundaries[i].code.toString();

        // Use cached count from the initial check instead of re-fetching
        int boundaryTotalCount = event.boundaryCounts[boundaryCode] ?? 0;
        if (boundaryTotalCount == 0) continue;

        final existingDownSyncDataForFileCheck =
            await downSyncLocalRepository.search(DownsyncSearchModel(
          locality: boundaryCode,
        ));
        final existingLastSyncedTime = existingDownSyncDataForFileCheck.isEmpty
            ? null
            : existingDownSyncDataForFileCheck.first.lastSyncedTime;

        if (existingLastSyncedTime == null) {
          final linkResults = await downSyncRemoteRepository.downSync(
            DownsyncSearchModel(
              locality: boundaryCode,
              offset: 0,
              limit: 0,
              totalCount: boundaryTotalCount,
              tenantId: envConfig.variables.tenantId,
              projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
              isDeleted: true,
            ),
          );
          final downloadLinks = _downloadLinksFrom(linkResults);

          if (downloadLinks.isNotEmpty) {
            final totalCount = _downloadLinksRecordCount(downloadLinks);
            if (await _hasInsufficientStorage(
              totalCount,
              kbPerRecord: _fileDownsyncStorageKbPerRecord,
            )) {
              emit(const BeneficiaryDownSyncState.insufficientStorage());
              await LocalSecureStore.instance.setManualSyncTrigger(false);
              return;
            }

            await _importDownloadLinks(
              links: downloadLinks,
              projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
              boundaryCode: boundaryCode,
              boundaryName: boundaryName,
              totalCount: totalCount,
              batchSize: event.batchSize,
              emitProgress:
                  (link, linkImported, totalImported, _, lastEntityType) {
                if (lastEntityType.isNotEmpty) {
                  currentEntityType = lastEntityType;
                } else if (link.fileType.isNotEmpty) {
                  currentEntityType = link.fileType;
                }
                emit(BeneficiaryDownSyncState.multiBoundaryInProgress(
                  i,
                  boundaries.length,
                  boundaryName,
                  linkImported,
                  link.recordCount,
                ));
              },
            );

            completedResults.add(DownsyncModel(
              offset: totalCount,
              lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
              totalCount: totalCount,
              locality: boundaryCode,
              boundaryName: boundaryName,
            ));
            continue;
          }
        }

        if (await _hasInsufficientStorage(
          boundaryTotalCount,
          kbPerRecord: _paginatedDownsyncStorageKbPerRecord,
        )) {
          emit(const BeneficiaryDownSyncState.insufficientStorage());
          await LocalSecureStore.instance.setManualSyncTrigger(false);
          return;
        }

        while (true) {
          final loopDownSyncData =
              await downSyncLocalRepository.search(DownsyncSearchModel(
            locality: boundaryCode,
          ));

          int offset =
              loopDownSyncData.isEmpty ? 0 : loopDownSyncData.first.offset ?? 0;
          int totalCount = boundaryTotalCount;
          int? loopLastSyncedTime = loopDownSyncData.isEmpty
              ? null
              : loopDownSyncData.first.lastSyncedTime;

          if (loopDownSyncData.isEmpty) {
            await downSyncLocalRepository.create(DownsyncModel(
              offset: offset,
              limit: event.batchSize,
              lastSyncedTime: loopLastSyncedTime,
              totalCount: totalCount,
              locality: boundaryCode,
              boundaryName: boundaryName,
            ));
          }

          if (offset < totalCount) {
            emit(BeneficiaryDownSyncState.multiBoundaryInProgress(
              i,
              boundaries.length,
              boundaryName,
              offset,
              totalCount,
            ));

            final downSyncResults = await downSyncRemoteRepository.downSync(
              DownsyncSearchModel(
                locality: boundaryCode,
                offset: offset,
                limit: event.batchSize,
                totalCount: totalCount,
                tenantId: envConfig.variables.tenantId,
                projectId: event.projectModel.projectHierarchy?.split('.').first ??
              event.projectModel.id,
                lastSyncedTime: loopLastSyncedTime,
                isDeleted: true,
              ),
            );

            if (downSyncResults.isNotEmpty) {
              await writeToFile(event.projectModel.id, boundaryCode,
                  boundaryName, downSyncResults);
              await SyncServiceSingleton()
                  .entityMapper
                  ?.writeToEntityDB(downSyncResults, [
                individualLocalRepository,
                householdLocalRepository,
                householdMemberLocalRepository,
                projectBeneficiaryLocalRepository,
                taskLocalRepository,
                sideEffectLocalRepository,
                referralLocalRepository,
                hfReferralLocalRepository,
                serviceLocalRepository,
              ]);

              totalCount = downSyncResults["DownsyncCriteria"]["totalCount"];

              await downSyncLocalRepository.update(DownsyncModel(
                offset: offset + event.batchSize,
                limit: event.batchSize,
                lastSyncedTime: loopLastSyncedTime,
                totalCount: totalCount,
                locality: boundaryCode,
                boundaryName: boundaryName,
              ));
            } else {
              emit(const BeneficiaryDownSyncState.failed());
              await LocalSecureStore.instance.setManualSyncTrigger(false);
              return;
            }
          } else {
            await downSyncLocalRepository.update(
              loopDownSyncData.first.copyWith(
                offset: 0,
                limit: 0,
                totalCount: totalCount,
                locality: boundaryCode,
                boundaryName: boundaryName,
                lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
              ),
            );

            completedResults.add(DownsyncModel(
              offset: totalCount,
              lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
              totalCount: totalCount,
              locality: boundaryCode,
              boundaryName: boundaryName,
            ));
            break;
          }
        }
      }

      await LocalSecureStore.instance.setManualSyncTrigger(false);
      emit(BeneficiaryDownSyncState.multiBoundarySuccess(completedResults));
    } catch (e) {
      await LocalSecureStore.instance.setManualSyncTrigger(false);
      emit(const BeneficiaryDownSyncState.failed());
    }
  }

  List<BeneficiaryDownloadLink> _downloadLinksFrom(
    Map<String, dynamic> response,
  ) {
    final links = response['DownloadLinks'];
    if (links is! List) return [];

    return links
        .whereType<Map<String, dynamic>>()
        .map(BeneficiaryDownloadLink.fromMap)
        .where((link) => link.url.isNotEmpty && link.recordCount > 0)
        .toList();
  }

  int _downloadLinksRecordCount(List<BeneficiaryDownloadLink> links) {
    return links.fold<int>(0, (total, link) => total + link.recordCount);
  }

  Future<bool> _hasInsufficientStorage(
    int recordCount, {
    required int kbPerRecord,
  }) async {
    final diskSpaceMb = await DiskSpace.getFreeDiskSpace;
    final availableKb = (diskSpaceMb ?? 0) * 1000;
    final requiredKb = recordCount * kbPerRecord * _storageSafetyMultiplier;

    return availableKb < requiredKb;
  }

  Future<void> _importDownloadLinks({
    required List<BeneficiaryDownloadLink> links,
    required String? projectId,
    required String boundaryCode,
    required String boundaryName,
    required int totalCount,
    required int batchSize,
    required void Function(
      BeneficiaryDownloadLink link,
      int linkImported,
      int totalImported,
      int overallTotal,
      String lastEntityType,
    ) emitProgress,
  }) async {
    final existingDownSyncData =
        await downSyncLocalRepository.search(DownsyncSearchModel(
      locality: boundaryCode,
    ));

    final startFromOffset = existingDownSyncData.isEmpty
        ? 0
        : (existingDownSyncData.first.offset ?? 0);

    if (existingDownSyncData.isEmpty) {
      await downSyncLocalRepository.create(DownsyncModel(
        offset: 0,
        limit: 0,
        lastSyncedTime: null,
        totalCount: totalCount,
        locality: boundaryCode,
        boundaryName: boundaryName,
        projectId: projectId,
      ));
    }

    final importer = BeneficiaryFileDownsyncImporter(
      dio: downSyncRemoteRepository.dio,
      individualLocalRepository: individualLocalRepository,
      householdLocalRepository: householdLocalRepository,
      householdMemberLocalRepository: householdMemberLocalRepository,
      projectBeneficiaryLocalRepository: projectBeneficiaryLocalRepository,
      taskLocalRepository: taskLocalRepository,
      sideEffectLocalRepository: sideEffectLocalRepository,
      referralLocalRepository: referralLocalRepository,
      hfReferralLocalRepository: hfReferralLocalRepository,
      serviceLocalRepository: serviceLocalRepository,
      batchSize: batchSize,
    );

    await importer.importLinks(
      links,
      startFromOffset: startFromOffset,
      onProgress:
          (importedCount, _, link, linkImported, lastEntityType) async {
        emitProgress(link, linkImported, importedCount, totalCount,
            lastEntityType);
        await downSyncLocalRepository.update(DownsyncModel(
          offset: importedCount,
          limit: 0,
          totalCount: totalCount,
          locality: boundaryCode,
          boundaryName: boundaryName,
          projectId: projectId,
        ));
      },
    );

    await downSyncLocalRepository.update(DownsyncModel(
      offset: totalCount,
      limit: 0,
      lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
      totalCount: totalCount,
      locality: boundaryCode,
      boundaryName: boundaryName,
      projectId: projectId,
    ));
  }

  writeToFile(
    String projectId,
    String selectedBoundaryCode,
    String selectedBoundaryName,
    Map<String, dynamic> response,
  ) async {
    Map<String, dynamic> storedData = {};

    // Get the Downloads directory
    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory == null) {
      if (kDebugMode) {
        print("Downloads directory is not available.");
      }
      return;
    }

    final file = await getDownSyncFilePath();

    // Read existing file content if available
    if (file.existsSync()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        storedData = jsonDecode(content);
      }
    } else {
      // Create the file if it doesn't exist
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode({}));
    }
    var downSyncModel = response["DownsyncCriteria"];
    String offsetKey = '${downSyncModel["offset"]}';

    // Prepare the boundary data
    Map<String, dynamic> boundaryData = {
      "boundaryCode": selectedBoundaryCode,
      "boundaryName": selectedBoundaryName,
      "response": DataMapEncryptor().encryptWithRandomKey(response)
    };

    // Initialize the offset entry if it doesn't exist
    storedData[offsetKey] ??= {"totalCount": 0, "boundaries": []};

    // Always update totalCount to reflect latest info
    storedData[offsetKey]["totalCount"] += downSyncModel["totalCount"];

    // Fetch or initialize the list of boundaries
    List<dynamic> boundaries = storedData[offsetKey]["boundaries"];

    // Check if boundary already exists
    bool exists = boundaries
        .any((entry) => entry["boundaryCode"] == selectedBoundaryCode);

    if (!exists) {
      boundaries.add(boundaryData);
      storedData[offsetKey]["boundaries"] = boundaries;

      if (kDebugMode) {
        print(
            "Added new boundary: $selectedBoundaryCode under offset: $offsetKey");
      }
    } else {
      if (kDebugMode) {
        print(
            "Boundary '$selectedBoundaryCode' already exists under offset $offsetKey.");
      }
    }

    // Convert map to JSON string
    String storedDataString = jsonEncode(storedData);
    debugPrint("Stored data: $storedDataString");

    // Write back to file
    await file.writeAsString(storedDataString);

    if (kDebugMode) {
      print("Data successfully written to ${file.path}");
    }
  }

  FutureOr<void> _handleDownSyncReport(
    DownSyncReportEvent event,
    BeneficiaryDownSyncEmitter emit,
  ) async {
    final result = await downSyncLocalRepository.search(DownsyncSearchModel());
    emit(BeneficiaryDownSyncState.report(result));
  }
}

@freezed
class BeneficiaryDownSyncEvent with _$BeneficiaryDownSyncEvent {
  const factory BeneficiaryDownSyncEvent.downSync({
    required ProjectModel projectModel,
    required String boundaryCode,
    required int batchSize,
    required int initialServerCount,
    required String boundaryName,
  }) = DownSyncBeneficiaryEvent;

  const factory BeneficiaryDownSyncEvent.checkForData({
    required ProjectModel projectModel,
    required String boundaryCode,
    required int pendingSyncCount,
    required int batchSize,
    required String boundaryName,
  }) = DownSyncCheckTotalCountEvent;

  const factory BeneficiaryDownSyncEvent.getBatchSize({
    required List<AppConfiguration> appConfiguration,
    required ProjectModel projectModel,
    required List<BoundaryModel> boundaries,
    required int pendingSyncCount,
  }) = DownSyncGetBatchSizeEvent;

  const factory BeneficiaryDownSyncEvent.downSyncAll({
    required ProjectModel projectModel,
    required List<BoundaryModel> boundaries,
    required int batchSize,
    required int pendingSyncCount,
  }) = DownSyncAllBoundariesEvent;

  const factory BeneficiaryDownSyncEvent.downloadAll({
    required ProjectModel projectModel,
    required List<BoundaryModel> boundaries,
    required int batchSize,
    required Map<String, int> boundaryCounts,
  }) = DownSyncDownloadAllEvent;

  const factory BeneficiaryDownSyncEvent.downSyncReport() = DownSyncReportEvent;

  const factory BeneficiaryDownSyncEvent.resetState() = DownSyncResetStateEvent;
}

@freezed
class BeneficiaryDownSyncState with _$BeneficiaryDownSyncState {
  const BeneficiaryDownSyncState._();

  const factory BeneficiaryDownSyncState.inProgress(
    int syncedCount,
    int totalCount,
  ) = _DownSyncInProgressState;

  const factory BeneficiaryDownSyncState.success(
    DownsyncModel downSyncResult,
  ) = _DownSyncSuccessState;

  const factory BeneficiaryDownSyncState.getBatchSize(
    int batchSize,
    ProjectModel projectModel,
    List<BoundaryModel> boundaries,
    int pendingSyncCount,
  ) = _DownSyncGetBatchSizeState;

  const factory BeneficiaryDownSyncState.loading(bool isPop) =
      _DownSyncLoadingState;

  const factory BeneficiaryDownSyncState.insufficientStorage() =
      _DownSyncInsufficientStorageState;

  const factory BeneficiaryDownSyncState.dataFound(
    int initialServerCount,
    int batchSize,
    Map<String, int> boundaryCounts,
  ) = _DownSyncDataFoundState;

  const factory BeneficiaryDownSyncState.resetState() = _DownSyncResetState;

  const factory BeneficiaryDownSyncState.totalCountCheckFailed() =
      _DownSynnCountCheckFailedState;

  const factory BeneficiaryDownSyncState.failed() = _DownSyncFailureState;

  const factory BeneficiaryDownSyncState.report(
    List<DownsyncModel> downsyncCriteriaList,
  ) = _DownSyncReportState;

  const factory BeneficiaryDownSyncState.pendingSync() =
      _DownSyncPendingSyncState;

  const factory BeneficiaryDownSyncState.multiBoundaryInProgress(
    int currentBoundaryIndex,
    int totalBoundaries,
    String currentBoundaryName,
    int syncedCount,
    int totalCount,
  ) = _DownSyncMultiBoundaryInProgressState;

  const factory BeneficiaryDownSyncState.multiBoundarySuccess(
    List<DownsyncModel> results,
  ) = _DownSyncMultiBoundarySuccessState;
}
