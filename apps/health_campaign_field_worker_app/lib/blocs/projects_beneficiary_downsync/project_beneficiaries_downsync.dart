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

  /// Shortest time each downloaded file's progress stays on screen; small
  /// files otherwise import in milliseconds and the dialog flashes past.
  static const Duration _minFileProgressDuration = Duration(seconds: 1);

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

      final downloadLinks =
          await _probeDownloadLinks(event.boundaryCode, event.projectModel);
      if (downloadLinks.isNotEmpty) {
        final serverTotalCount = downloadLinksRecordCount(downloadLinks);
        emit(BeneficiaryDownSyncState.dataFound(
          serverTotalCount,
          event.batchSize,
          {event.boundaryCode: serverTotalCount},
        ));
        return;
      }

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
          // lastSyncedTime: lastSyncedTime,
          tenantId: envConfig.variables.tenantId,
          projectId: event.projectModel.id,
        ),
      );
      if (initialResults.isNotEmpty) {
        // Current response from server is String, Expecting it to be int
        //[TODO: Need to move the dynamic keys to constants
        int serverTotalCount = initialResults["DownsyncCriteria"]["totalCount"];

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
      final downloadLinks =
          await _probeDownloadLinks(event.boundaryCode, event.projectModel);
      if (downloadLinks.isNotEmpty) {
        if (await _hasInsufficientStorage(
          downloadLinksRecordCount(downloadLinks),
          kbPerRecord: _fileDownsyncStorageKbPerRecord,
        )) {
          emit(const BeneficiaryDownSyncState.insufficientStorage());
          await LocalSecureStore.instance.setManualSyncTrigger(false);
          return;
        }

        final result = await _importDownloadLinks(
          links: downloadLinks,
          projectModel: event.projectModel,
          boundaryCode: event.boundaryCode,
          boundaryName: event.boundaryName,
          batchSize: event.batchSize,
          emitProgress: (link, linkImported, entityType) {
            emit(BeneficiaryDownSyncState.inProgress(
              linkImported,
              link.recordCount,
              entityType,
            ));
          },
        );
        await LocalSecureStore.instance.setManualSyncTrigger(false);
        emit(BeneficiaryDownSyncState.success(result));
        return;
      }
    } catch (e) {
      await LocalSecureStore.instance.setManualSyncTrigger(false);
      emit(const BeneficiaryDownSyncState.failed());
      return;
    }

    if (await _hasInsufficientStorage(
      event.initialServerCount,
      kbPerRecord: _paginatedDownsyncStorageKbPerRecord,
    )) {
      emit(const BeneficiaryDownSyncState.insufficientStorage());
      await LocalSecureStore.instance.setManualSyncTrigger(false);
    } else {
      try {
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
              // lastSyncedTime: lastSyncedTime,
              totalCount: totalCount,
              locality: event.boundaryCode,
              boundaryName: event.boundaryName,
            ));
          }

          if (offset < totalCount) {
            emit(BeneficiaryDownSyncState.inProgress(offset, totalCount, ''));
            //Make the batch API call
            final downSyncResults = await downSyncRemoteRepository.downSync(
              DownsyncSearchModel(
                locality: event.boundaryCode,
                offset: offset,
                limit: event.batchSize,
                totalCount: totalCount,
                tenantId: envConfig.variables.tenantId,
                projectId: event.projectModel.id,
                // lastSyncedTime: lastSyncedTime,
                isDeleted: true,
              ),
            );
            emit(BeneficiaryDownSyncState.inProgress(
                offset, downSyncResults["DownsyncCriteria"]["totalCount"], ''));

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
                // lastSyncedTime: lastSyncedTime,
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
                // lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            final result = DownsyncModel(
              offset: totalCount,
              // lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
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

        final downloadLinks =
            await _probeDownloadLinks(boundaryCode, event.projectModel);
        if (downloadLinks.isNotEmpty) {
          final count = downloadLinksRecordCount(downloadLinks);
          boundaryCounts[boundaryCode] = count;
          totalServerCount += count;
          continue;
        }

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
            // lastSyncedTime: lastSyncedTime,
            tenantId: envConfig.variables.tenantId,
            projectId: event.projectModel.id,
          ),
        );

        if (initialResults.isNotEmpty) {
          final count = initialResults["DownsyncCriteria"]["totalCount"] as int;
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

        final downloadLinks =
            await _probeDownloadLinks(boundaryCode, event.projectModel);
        if (downloadLinks.isNotEmpty) {
          if (await _hasInsufficientStorage(
            downloadLinksRecordCount(downloadLinks),
            kbPerRecord: _fileDownsyncStorageKbPerRecord,
          )) {
            emit(const BeneficiaryDownSyncState.insufficientStorage());
            await LocalSecureStore.instance.setManualSyncTrigger(false);
            return;
          }

          completedResults.add(await _importDownloadLinks(
            links: downloadLinks,
            projectModel: event.projectModel,
            boundaryCode: boundaryCode,
            boundaryName: boundaryName,
            batchSize: event.batchSize,
            emitProgress: (link, linkImported, entityType) {
              emit(BeneficiaryDownSyncState.multiBoundaryInProgress(
                i,
                boundaries.length,
                boundaryName,
                linkImported,
                link.recordCount,
                entityType,
              ));
            },
          ));
          continue;
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
              // lastSyncedTime: loopLastSyncedTime,
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
              '',
            ));

            final downSyncResults = await downSyncRemoteRepository.downSync(
              DownsyncSearchModel(
                locality: boundaryCode,
                offset: offset,
                limit: event.batchSize,
                totalCount: totalCount,
                tenantId: envConfig.variables.tenantId,
                projectId: event.projectModel.id,
                // lastSyncedTime: loopLastSyncedTime,
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
                // lastSyncedTime: loopLastSyncedTime,
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
                // lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
              ),
            );

            completedResults.add(DownsyncModel(
              offset: totalCount,
              // lastSyncedTime: DateTime.now().millisecondsSinceEpoch,
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

  /// File links for [boundaryCode], or none — callers then run the paginated
  /// downsync exactly as before. A failed or unexpected response also means
  /// none, so a backend without the file API is never broken by this call.
  Future<List<BeneficiaryDownloadLink>> _probeDownloadLinks(
    String boundaryCode,
    ProjectModel projectModel,
  ) async {
    try {
      final response = await downSyncRemoteRepository.downSync(
        DownsyncSearchModel(
          locality: boundaryCode,
          offset: 0,
          limit: 0,
          isDeleted: true,
          tenantId: envConfig.variables.tenantId,
          projectId: resolveDownsyncProjectId(
            projectModel.projectHierarchy,
            projectModel.id,
          ),
        ),
      );
      return parseDownloadLinks(response);
    } catch (e) {
      if (kDebugMode) {
        print('File downsync probe failed, using paginated downsync: $e');
      }
      return [];
    }
  }

  Future<bool> _hasInsufficientStorage(
    int recordCount, {
    required int kbPerRecord,
  }) async {
    final diskSpaceMb = await DiskSpace.getFreeDiskSpace;
    return (diskSpaceMb ?? 0) * 1000 <
        recordCount * kbPerRecord * _storageSafetyMultiplier;
  }

  /// Imports [links] into the local DB and returns the completed downsync
  /// record. Progress is persisted per batch so a retry resumes; on
  /// completion the offset goes back to 0 so the next sync is a full import
  /// again (beneficiary downsync never sends a delta cursor).
  Future<DownsyncModel> _importDownloadLinks({
    required List<BeneficiaryDownloadLink> links,
    required ProjectModel projectModel,
    required String boundaryCode,
    required String boundaryName,
    required int batchSize,
    required void Function(
      BeneficiaryDownloadLink link,
      int linkImported,
      String entityType,
    ) emitProgress,
  }) async {
    final totalCount = downloadLinksRecordCount(links);
    final projectId = resolveDownsyncProjectId(
      projectModel.projectHierarchy,
      projectModel.id,
    );

    final existingDownSyncData =
        await downSyncLocalRepository.search(DownsyncSearchModel(
      locality: boundaryCode,
    ));
    final existing = existingDownSyncData.firstOrNull;
    final startFromOffset = resolveResumeOffset(
      storedOffset: existing?.offset,
      storedLimit: existing?.limit,
      storedTotalCount: existing?.totalCount,
      linksTotal: totalCount,
    );

    if (existing == null) {
      await downSyncLocalRepository.create(DownsyncModel(
        offset: 0,
        limit: 0,
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
      minLinkDuration: _minFileProgressDuration,
    );

    await importer.importLinks(
      links,
      startFromOffset: startFromOffset,
      onProgress: (importedCount, _, link, linkImported, lastEntityType) async {
        // The label travels in the state: the page reads states late
        // (Future.delayed), after the next file may already have started.
        emitProgress(
          link,
          linkImported,
          progressEntityType(link, lastEntityType),
        );
        // limit 0 marks a file-mode row; resolveResumeOffset relies on it.
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

    // lastSyncedTime is shown in the downsync report only — it is never sent
    // to the server for beneficiary downsync.
    final syncedTime = DateTime.now().millisecondsSinceEpoch;
    await downSyncLocalRepository.update(DownsyncModel(
      offset: 0,
      limit: 0,
      lastSyncedTime: syncedTime,
      totalCount: totalCount,
      locality: boundaryCode,
      boundaryName: boundaryName,
      projectId: projectId,
    ));

    return DownsyncModel(
      offset: totalCount,
      lastSyncedTime: syncedTime,
      totalCount: totalCount,
      locality: boundaryCode,
      boundaryName: boundaryName,
    );
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

  /// [entityType] names the file being imported (see [progressEntityType]);
  /// blank during a paginated download.
  const factory BeneficiaryDownSyncState.inProgress(
    int syncedCount,
    int totalCount,
    String entityType,
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
    String entityType,
  ) = _DownSyncMultiBoundaryInProgressState;

  const factory BeneficiaryDownSyncState.multiBoundarySuccess(
    List<DownsyncModel> results,
  ) = _DownSyncMultiBoundarySuccessState;
}
