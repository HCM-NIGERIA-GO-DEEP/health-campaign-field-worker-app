import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/hf_referral.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:survey_form/models/entities/service.dart';

class BeneficiaryDownloadLink {
  final String fileType;
  final String url;
  final int recordCount;
  final int? expiresAt;

  const BeneficiaryDownloadLink({
    required this.fileType,
    required this.url,
    required this.recordCount,
    this.expiresAt,
  });

  factory BeneficiaryDownloadLink.fromMap(Map<String, dynamic> map) {
    return BeneficiaryDownloadLink(
      fileType: map['fileType']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      recordCount: _readInt(map['recordCount']) ?? 0,
      expiresAt: _readInt(map['expiresAt']),
    );
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class BeneficiaryFileDownsyncResult {
  final int importedCount;
  final Map<String, int> importedByType;

  const BeneficiaryFileDownsyncResult({
    required this.importedCount,
    required this.importedByType,
  });
}

typedef BeneficiaryFileProgress = FutureOr<void> Function(
  int importedCount,
  Map<String, int> importedByType,
  BeneficiaryDownloadLink currentLink,
  int currentLinkImported,
  String lastEntityType,
);

class BeneficiaryFileDownsyncImporter {
  static const int _defaultBatchSize = 500;
  static const int _maxDownloadRetries = 3;
  static const Duration _downloadRetryDelay = Duration(seconds: 2);
  static const Duration _receiveTimeout = Duration(minutes: 30);
  static const Duration _connectTimeout = Duration(seconds: 30);

  final int batchSize;

  final Dio dio;
  final LocalRepository<IndividualModel, IndividualSearchModel>
      individualLocalRepository;
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

  BeneficiaryFileDownsyncImporter({
    required this.dio,
    required this.individualLocalRepository,
    required this.householdLocalRepository,
    required this.householdMemberLocalRepository,
    required this.projectBeneficiaryLocalRepository,
    required this.taskLocalRepository,
    required this.sideEffectLocalRepository,
    required this.referralLocalRepository,
    required this.hfReferralLocalRepository,
    required this.serviceLocalRepository,
    int? batchSize,
  }) : batchSize = (batchSize ?? 0) > 0 ? batchSize! : _defaultBatchSize;

  Future<BeneficiaryFileDownsyncResult> importLinks(
    List<BeneficiaryDownloadLink> links, {
    BeneficiaryFileProgress? onProgress,
    int startFromOffset = 0,
  }) async {
    final counters = <String, int>{};
    var totalImported = 0;
    var skipRemaining = startFromOffset;
    var lastEntityType = '';

    for (final link in links) {
      if (link.url.isEmpty) continue;

      // Fast-skip entire links that the persisted offset has already covered.
      if (skipRemaining >= link.recordCount && link.recordCount > 0) {
        skipRemaining -= link.recordCount;
        totalImported += link.recordCount;
        continue;
      }

      var linkImported = 0;
      await onProgress?.call(totalImported, Map.of(counters), link, linkImported,
          lastEntityType);

      await for (final rawLine in _readNdjsonLines(link)) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        if (skipRemaining > 0) {
          // Already imported on a prior attempt; skip without parsing/inserting.
          skipRemaining -= 1;
          totalImported += 1;
          linkImported += 1;
          continue;
        }

        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;

        await _addDecodedLine(decoded);

        totalImported += 1;
        linkImported += 1;
        final type = decoded['_t']?.toString() ?? link.fileType;
        if (type.isNotEmpty) lastEntityType = type;
        counters[type] = (counters[type] ?? 0) + 1;

        if (totalImported % batchSize == 0) {
          await _flush();
          await onProgress?.call(totalImported, Map.of(counters), link,
              linkImported, lastEntityType);
        }
      }
      await _flush();
      await onProgress?.call(totalImported, Map.of(counters), link, linkImported,
          lastEntityType);
    }

    return BeneficiaryFileDownsyncResult(
      importedCount: totalImported,
      importedByType: counters,
    );
  }

  final List<HouseholdModel> _households = [];
  final List<IndividualModel> _individuals = [];
  final List<HouseholdMemberModel> _householdMembers = [];
  final List<ProjectBeneficiaryModel> _projectBeneficiaries = [];
  final List<TaskModel> _tasks = [];
  final List<SideEffectModel> _sideEffects = [];
  final List<ReferralModel> _referrals = [];
  final List<HFReferralModel> _hfReferrals = [];
  final List<ServiceModel> _services = [];

  Stream<String> _readNdjsonLines(BeneficiaryDownloadLink link) async* {
    var attempt = 0;
    var totalYielded = 0;

    while (true) {
      attempt += 1;
      var readInThisAttempt = 0;
      try {
        await for (final line in _streamLinkOnce(link)) {
          readInThisAttempt += 1;
          if (readInThisAttempt <= totalYielded) continue;
          yield line;
          totalYielded += 1;
        }
        return;
      } on DioException catch (e) {
        if (attempt >= _maxDownloadRetries || !_isRetryableDioError(e)) {
          rethrow;
        }
        await Future.delayed(_downloadRetryDelay);
      }
    }
  }

  Stream<String> _streamLinkOnce(BeneficiaryDownloadLink link) async* {
    final response = await dio.get<ResponseBody>(
      link.url,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _connectTimeout,
      ),
    );

    final body = response.data;
    if (body == null) return;

    final source = body.stream.map<List<int>>((chunk) => chunk);
    final iterator = StreamIterator<List<int>>(source);

    try {
      if (!await iterator.moveNext()) return;

      final first = iterator.current;
      final isGzip = first.length >= 2 && first[0] == 0x1f && first[1] == 0x8b;

      final bytes = _pullBytes(iterator, first);
      final decodedStream = isGzip
          ? bytes.transform(gzip.decoder).transform(utf8.decoder)
          : bytes.transform(utf8.decoder);

      yield* decodedStream.transform(const LineSplitter());
    } finally {
      await iterator.cancel();
    }
  }

  bool _isRetryableDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      case DioExceptionType.unknown:
        return e.error is SocketException || e.error is HttpException;
      default:
        return false;
    }
  }

  Stream<List<int>> _pullBytes(
    StreamIterator<List<int>> iterator,
    List<int> first,
  ) async* {
    yield first;
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }
  Future<void> _addDecodedLine(Map<String, dynamic> raw) async {
    final entityType = raw['_t']?.toString();

    switch (entityType) {
      case 'HOUSEHOLD':
        _households.add(HouseholdModelMapper.fromMap(raw));
      case 'HOUSEHOLD_MEMBER':
        _householdMembers.add(HouseholdMemberModelMapper.fromMap(raw));
      case 'INDIVIDUAL':
        _individuals.add(IndividualModelMapper.fromMap(raw));
      case 'PROJECT_BENEFICIARY':
        _projectBeneficiaries.add(ProjectBeneficiaryModelMapper.fromMap(raw));
      case 'TASK':
      case 'PROJECT_TASK':
        _tasks.add(TaskModelMapper.fromMap(raw));
      case 'SIDE_EFFECT':
        _sideEffects.add(SideEffectModelMapper.fromMap(raw));
      case 'REFERRAL':
        _referrals.add(ReferralModelMapper.fromMap(raw));
      case 'HF_REFERRAL':
        _hfReferrals.add(HFReferralModelMapper.fromMap(raw));
      case 'SERVICE':
        _services.add(ServiceModelMapper.fromMap(raw));
      default:
        if (kDebugMode) {
          print('Downsync: skipping unknown entity type "$entityType"');
        }
        return;
    }

    if (_bufferedCount >= batchSize) {
      await _flush();
    }
  }

  int get _bufferedCount =>
      _households.length +
      _individuals.length +
      _householdMembers.length +
      _projectBeneficiaries.length +
      _tasks.length +
      _sideEffects.length +
      _referrals.length +
      _hfReferrals.length +
      _services.length;

  Future<void> _flush() async {
    if (_households.isNotEmpty) {
      await householdLocalRepository.bulkCreate(List.of(_households));
      _households.clear();
    }
    if (_individuals.isNotEmpty) {
      await individualLocalRepository.bulkCreate(List.of(_individuals));
      _individuals.clear();
    }
    if (_householdMembers.isNotEmpty) {
      await householdMemberLocalRepository
          .bulkCreate(List.of(_householdMembers));
      _householdMembers.clear();
    }
    if (_projectBeneficiaries.isNotEmpty) {
      await projectBeneficiaryLocalRepository
          .bulkCreate(List.of(_projectBeneficiaries));
      _projectBeneficiaries.clear();
    }
    if (_tasks.isNotEmpty) {
      await taskLocalRepository.bulkCreate(List.of(_tasks));
      _tasks.clear();
    }
    if (_sideEffects.isNotEmpty) {
      await sideEffectLocalRepository.bulkCreate(List.of(_sideEffects));
      _sideEffects.clear();
    }
    if (_referrals.isNotEmpty) {
      await referralLocalRepository.bulkCreate(List.of(_referrals));
      _referrals.clear();
    }
    if (_hfReferrals.isNotEmpty) {
      await hfReferralLocalRepository.bulkCreate(List.of(_hfReferrals));
      _hfReferrals.clear();
    }
    if (_services.isNotEmpty) {
      await serviceLocalRepository.bulkCreate(List.of(_services));
      _services.clear();
    }
  }

}
