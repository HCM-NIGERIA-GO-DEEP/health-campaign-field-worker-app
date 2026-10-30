import 'dart:async';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_store/app_shared_preferences.dart';
import '../data/remote_client.dart';
import '../data/repositories/remote/boundary_beneficiary_id.dart';
import '../models/boundary_beneficiary_id.dart';
import '../utils/environment_config.dart';
import '../utils/runtime_hierarchy.dart';
import '../utils/utils.dart';

/// Server pool IDs stay raw in UniqueIdPool. The display/persisted individual
/// identifier is pinned alongside the raw row while registration is in flight.
class BeneficiaryIdService {
  static const serverSource = 'SERVER_POOL';
  final LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> pool;
  final LocalRepository<BoundaryModel, BoundarySearchModel> boundaries;
  final AppSharedPreferences cache;
  final BoundaryBeneficiaryIdRepository prefixes;
  final String scope;
  final String userUuid;
  final String tenantId;
  static Future<void> _queue = Future.value();
  static final Map<String, Future<void>> _prefixRequests = {};

  BeneficiaryIdService(
      {required this.pool,
      required this.boundaries,
      required this.cache,
      required this.prefixes,
      required this.scope,
      required this.userUuid,
      required this.tenantId});

  factory BeneficiaryIdService.forContext(BuildContext context) {
    final tenant = envConfig.variables.tenantId;
    return BeneficiaryIdService(
      pool: context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>(),
      boundaries:
          context.read<LocalRepository<BoundaryModel, BoundarySearchModel>>(),
      cache: AppSharedPreferences(),
      prefixes:
          BoundaryBeneficiaryIdRepository(DioClient().dio, tenantId: tenant),
      scope:
          '${envConfig.variables.baseUrl}|$tenant|${FlowBuilderSingleton().projectId}',
      userUuid: context.loggedInUserUuid,
      tenantId: tenant,
    );
  }

  static String? field(UniqueIdPoolModel row, String key) {
    for (final field in row.additionalFields?.fields ?? <AdditionalField>[]) {
      if (field.key == key) return field.value?.toString();
    }
    return null;
  }

  static UniqueIdPoolAdditionalFields metadata(
          UniqueIdPoolModel row, Map<String, String> updates) =>
      UniqueIdPoolAdditionalFields(fields: [
        ...?row.additionalFields?.fields
            .where((f) => !updates.containsKey(f.key)),
        ...updates.entries.map((e) => AdditionalField(e.key, e.value)),
      ]);

  bool owns(UniqueIdPoolModel row) =>
      row.userUuid == userUuid && row.tenantId == tenantId;

  Future<List<UniqueIdPoolModel>> available({String? session}) async {
    final rows = await pool.search(UniqueIdPoolSearchModel(
        userUuid: userUuid, status: IdStatus.unAssigned.toValue()));
    final eligible = rows
        .where((r) =>
            owns(r) &&
            field(r, 'beneficiaryIdSource') == serverSource &&
            (field(r, 'reservedFor') == null ||
                field(r, 'reservedFor') == session))
        .toList()
      ..sort((a, b) => (a.auditDetails?.createdTime ?? 0)
          .compareTo(b.auditDetails?.createdTime ?? 0));
    return eligible;
  }

  Future<DistributionPointReference> distributionPoint(
      BoundaryModel selected) async {
    final selectedCode = selected.code;
    if (selectedCode == null || selectedCode.isEmpty) {
      throw StateError('BENEFICIARY_DISTRIBUTION_POINT_UNAVAILABLE');
    }
    final saved = cache.getBeneficiaryDistributionPoint(scope, selectedCode);
    if (saved != null &&
        saved['code']?.isNotEmpty == true &&
        saved['name']?.isNotEmpty == true) {
      return DistributionPointReference(saved['code']!, saved['name']!);
    }
    final selectedRows =
        await boundaries.search(BoundarySearchModel(codes: selectedCode));
    final exact = selectedRows.where((r) => r.code == selectedCode);
    final current = exact.isNotEmpty ? exact.first : selected;
    final codes =
        (current.materializedPath ?? selected.materializedPath ?? selectedCode)
            .split('.')
            .reversed;
    for (final code in codes) {
      final rows = code == selectedCode
          ? [current]
          : (await boundaries.search(BoundarySearchModel(codes: code)))
              .where((r) => r.code == code)
              .toList();
      for (final row in rows) {
        final type = (row.boundaryType ?? row.label ?? '')
            .toLowerCase()
            .replaceAll(RegExp('[^a-z]'), '');
        if (type != 'distributionpoint') continue;
        final name = row.name?.trim() ?? '';
        if (name.isEmpty || name == row.code) {
          throw StateError('BENEFICIARY_DISTRIBUTION_POINT_UNAVAILABLE');
        }
        await cache.setBeneficiaryDistributionPoint(
            scope, selectedCode, {'code': code, 'name': name});
        return DistributionPointReference(code, name);
      }
    }
    throw StateError('BENEFICIARY_DISTRIBUTION_POINT_UNAVAILABLE');
  }

  Future<void> prepare(BoundaryModel selected) async {
    final dp = await distributionPoint(selected);
    final cached = cache.getBoundaryNumericId(scope, dp.code);
    if (cached != null) {
      BoundaryBeneficiaryIdRepository.debug('CACHE_HIT', {
        'boundaryCode': dp.code,
        'prefix': cached,
      });
      return;
    }
    final key = '$scope|${dp.code}';
    await (_prefixRequests[key] ??= () async {
      try {
        final response = await prefixes.fetch(
          boundaryCode: dp.code,
          hierarchyType: runtimeHierarchyType(),
        );
        for (final entry in response.boundaryToNumericId.entries) {
          await cache.setBoundaryNumericId(scope, entry.key, entry.value);
          BoundaryBeneficiaryIdRepository.debug('CACHE_SAVED', {
            'boundaryCode': entry.key,
            'prefix': entry.value,
            'saved':
                cache.getBoundaryNumericId(scope, entry.key) == entry.value,
            'cachedPrefix': cache.getBoundaryNumericId(scope, entry.key),
          });
        }
      } catch (_) {
        // Explicit product fallback: the DP's real name, never its code.
      }
    }());
  }

  Future<String> compose(BoundaryModel selected, String rawId) async {
    final dp = await distributionPoint(selected);
    final cached = cache.getBoundaryNumericId(scope, dp.code);
    final numeric = cached;
    final identifier = '${numeric?.toString() ?? dp.name}_$rawId';
    return identifier;
  }

  Future<BeneficiaryIdAllocation> allocate(
      BoundaryModel selected, String session) async {
    final prior = _queue;
    final release = Completer<void>();
    _queue = release.future;
    await prior;
    try {
      // Repeated submissions keep the same ID even after its row is assigned.
      final reservations =
          await pool.search(UniqueIdPoolSearchModel(userUuid: userUuid));
      for (final row in reservations) {
        if (owns(row) &&
            field(row, 'beneficiaryIdSource') == serverSource &&
            field(row, 'reservedFor') == session &&
            field(row, 'composedBeneficiaryId') != null) {
          return BeneficiaryIdAllocation(
              row.id, field(row, 'composedBeneficiaryId')!);
        }
      }
      final rows = await available(session: session);
      if (rows.isEmpty) throw StateError('BENEFICIARY_IDS_DOWNLOAD_REQUIRED');
      await prepare(selected);
      final dp = await distributionPoint(selected);
      final row = rows.first;
      final composed = await compose(selected, row.id);
      await pool.update(
          row.copyWith(
              additionalFields: metadata(row, {
            'reservedFor': session,
            'composedBeneficiaryId': composed,
            'distributionPointCode': dp.code,
          })),
          createOpLog: false);
      return BeneficiaryIdAllocation(row.id, composed);
    } finally {
      release.complete();
    }
  }

  /// A re-download must never reset a consumed or reserved raw ID.
  static Future<void> saveDownloaded(
      LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> pool,
      List<UniqueIdPoolModel> downloaded) async {
    final prior = _queue;
    final release = Completer<void>();
    _queue = release.future;
    await prior;
    try {
      final merged = <UniqueIdPoolModel>[];
      for (final row in downloaded) {
        final old = await pool.search(UniqueIdPoolSearchModel(id: row.id));
        if (old.isNotEmpty &&
            (old.first.status == IdStatus.assigned.toValue() ||
                field(old.first, 'reservedFor') != null)) continue;
        merged.add(row.copyWith(
            additionalFields:
                metadata(row, {'beneficiaryIdSource': serverSource})));
      }
      if (merged.isNotEmpty) await pool.bulkCreate(merged);
    } finally {
      release.complete();
    }
  }
}
